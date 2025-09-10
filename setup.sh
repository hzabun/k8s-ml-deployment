#!/bin/bash

set -e  # Exit on any error

echo "🚀 Starting MLflow + MinIO deployment on minikube..."

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

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Step 1: Set minikube docker environment
print_step "Setting minikube docker environment..."
eval $(minikube docker-env)
print_success "Minikube docker environment set"

# Step 2: Build docker images
print_step "Building ml-training Docker image..."
docker build -t ml-training:latest ./training
print_success "ml-training image built"

print_step "Building mlflow-server Docker image..."
docker build -t mlflow-server:latest ./mlflow-server
print_success "mlflow-server image built"

# Step 3: Install MinIO via Helm
print_step "Installing MinIO via Helm..."
if helm list -n minio | grep -q minio; then
    print_warning "MinIO already installed, skipping..."
else
    helm install minio minio/minio \
      --namespace minio --create-namespace \
      --set rootUser=minioadmin \
      --set rootPassword=minioadmin \
      --set persistence.size=5Gi \
      --set replicas=1 \
      --set mode=standalone \
      --set resources.requests.memory=512Mi
    print_success "MinIO installed"
fi

# Wait for MinIO to be ready
print_step "Waiting for MinIO to be ready..."
kubectl wait --for=condition=ready pod -l app=minio -n minio --timeout=300s
print_success "MinIO is ready"

# Step 4: Apply MinIO configuration
print_step "Applying MinIO configuration manifest..."
kubectl apply -f ./kubernetes/minio-configuration.yaml
print_success "MinIO configuration applied"

# Step 5: Apply MLflow server manifest
print_step "Applying MLflow server manifest..."
kubectl apply -f ./kubernetes/mlflow-setup.yaml
print_success "MLflow server manifest applied"

# Wait for MLflow server to be ready
print_step "Waiting for MLflow server to be ready..."
kubectl wait --for=condition=ready pod -l app=mlflow-server --timeout=300s
print_success "MLflow server is ready"

# Step 6: Apply training job manifest
print_step "Applying training job manifest..."
kubectl apply -f ./kubernetes/train-job.yaml
print_success "Training job manifest applied"


MINIO_POD=$(kubectl get pods --namespace minio -l "release=minio" -o jsonpath="{.items[0].metadata.name}")

print_warning "To view MLflow and MinIO UI locally, run the following commands:"
echo "  Terminal 1: kubectl port-forward $MINIO_POD 9001:9001 --namespace minio"
echo "  Terminal 2: minikube service mlflow-server-nodeport"

echo "📊 Access points:"
echo "  - MinIO Console: http://localhost:9001 (admin/minioadmin)"
echo "  - MLflow UI: Check the MLflow service terminal for the URL"

print_success "🎉 Deployment complete!"