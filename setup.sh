#!/bin/bash

set -e  # Exit on any error

echo "🚀 Starting MLflow + MinIO + KServe + Prometheus deployment on minikube..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
print_step "Checking prerequisites..."
if ! command -v yq &> /dev/null; then
    print_error "yq is required but not installed. Please install it with: brew install yq"
    exit 1
fi
print_success "Prerequisites check passed"

# Step 1: Set minikube docker environment
print_step "Setting minikube docker environment..."
eval $(minikube docker-env)
print_success "Minikube docker environment set"

# Step 2: Build docker images
print_step "Building Docker images..."
docker build -t ml-training:latest ./training
docker build -t mlflow-server:latest ./mlflow-server
print_success "Docker images built"

# Step 3: Install MinIO via Helm
print_step "Installing MinIO via Helm..."
helm install minio minio/minio \
  --namespace minio --create-namespace \
  --set rootUser=minioadmin \
  --set rootPassword=minioadmin \
  --set persistence.size=5Gi \
  --set replicas=1 \
  --set mode=standalone \
  --set resources.requests.memory=512Mi

kubectl wait --for=condition=ready pod -l app=minio -n minio --timeout=300s
print_success "MinIO installed and ready"

# Step 4: Create MinIO buckets
print_step "Creating MinIO buckets..."
MINIO_POD=$(kubectl get pods --namespace minio -l "release=minio" -o jsonpath="{.items[0].metadata.name}")

# Port-forward MinIO in background
kubectl port-forward $MINIO_POD 9000:9000 --namespace minio &
MINIO_PF_PID=$!
sleep 5

brew install minio/stable/mc

# Configure MinIO client and create buckets
mc alias set myminio http://localhost:9000 minioadmin minioadmin
mc mb myminio/mlflow 2>/dev/null || true
mc mb myminio/training 2>/dev/null || true
mc mkdir myminio/training/vgm-datasets || true

kill $MINIO_PF_PID 2>/dev/null || true
print_success "MinIO buckets created"

# Step 5: Apply MinIO configuration and MLflow server
print_step "Applying MinIO configuration and MLflow server..."
kubectl apply -f ./kubernetes/minio-configuration.yaml
kubectl apply -f ./kubernetes/mlflow-setup.yaml

kubectl wait --for=condition=ready pod -l app=mlflow-server --timeout=300s
print_success "MLflow server ready"

# Step 6: Run training job and extract model ID
print_step "Running training job..."
kubectl apply -f ./kubernetes/train-job.yaml
kubectl wait --for=condition=complete job/train-job --timeout=600s

TRAINING_POD=$(kubectl get pods -l job-name=train-job -o jsonpath="{.items[0].metadata.name}")
MODEL_ID=$(kubectl logs $TRAINING_POD | grep -o 'm-[a-zA-Z0-9]*' | tail -1)

if [ -z "$MODEL_ID" ]; then
    print_error "Could not extract model ID from training logs"
    exit 1
fi

print_success "Training complete. Model ID: $MODEL_ID"

# Step 7: Install KServe and deploy inference service
print_step "Installing KServe..."
curl -s "https://raw.githubusercontent.com/kserve/kserve/release-0.15/hack/quick_install.sh" | bash

print_step "Deploying inference service..."
cp ./kubernetes/kserve-inference.yaml ./kubernetes/kserve-inference.yaml.backup

yq eval ".spec.predictor.model.storageUri = \"s3://mlflow/1/$MODEL_ID/artifacts/model\"" -i ./kubernetes/kserve-inference.yaml

kubectl apply -f ./kubernetes/kserve-setup.yaml
kubectl apply -f ./kubernetes/kserve-inference.yaml
print_success "KServe deployed"

# Step 8: Install Prometheus and Grafana
print_step "Installing Prometheus and Grafana..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace prometheus --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin

kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n prometheus --timeout=300s
kubectl apply -f ./kubernetes/prometheus-scraping-setup.yaml
print_success "Prometheus and Grafana installed"

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "📊 Access services with:"
echo "  MinIO Console:  kubectl port-forward -n minio svc/minio 9001:9001"
echo "  MLflow UI:      minikube service mlflow-server-nodeport"
echo "  Grafana:        kubectl port-forward -n prometheus svc/prometheus-grafana 3000:80"
echo "  Prometheus:     kubectl port-forward -n prometheus svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo ""
echo "🔑 Credentials:"
echo "  MinIO: minioadmin/minioadmin"
echo "  Grafana: admin/prom-operator"
echo ""
echo "🤖 Model ID: $MODEL_ID"
echo "   Storage: s3://mlflow/1/$MODEL_ID/artifacts/model"