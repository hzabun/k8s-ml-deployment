# k8s-ml-deployment

Lightweight, local Kubernetes stack for model training, tracking, storage, serving, and observability on Minikube.

Components:

- MLflow: experiment tracking
- MinIO: S3-compatible object storage
- KServe: model serving
- Prometheus + Grafana: metrics and dashboards

Note: This is intended for local exploration and iteration on Kubernetes ML workflows.

## What this deploys

- A training job that logs an sklearn model to MLflow (artifacts in MinIO)
- KServe InferenceService pointing to the latest trained model
- Prometheus scraping and Grafana for visualization

## Prerequisites (macOS)

- Docker
- Minikube
- kubectl
- Helm
- yq (`brew install yq`)

## Quick start

1. Start a fresh Minikube cluster:

```bash
minikube start --memory=8192 --cpus=4
```

2. Deploy the stack:

```bash
chmod +x setup.sh
./setup.sh
```

3. Access services (in separate terminals):

```bash
# MinIO Console
kubectl port-forward -n minio svc/minio 9001:9001

# MLflow UI
minikube service mlflow-server-nodeport

# Grafana
kubectl port-forward -n prometheus svc/prometheus-grafana 3000:80

# Prometheus
kubectl port-forward -n prometheus svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Default creds:

- MinIO: minioadmin/minioadmin
- Grafana: admin/admin

### Cleanup

```bash
minikube delete
```

## Manual setup (if setup.sh doesn’t work)

Follow these steps in order. Run each block in your terminal.

1. Start/target Minikube and build images inside its Docker

```bash
minikube start --memory=8192 --cpus=4
eval "$(minikube docker-env)"  # use Minikube’s Docker daemon

# Build local images
docker build -t ml-training:latest ./training
docker build -t mlflow-server:latest ./mlflow-server
```

2. Install MinIO via Helm

```bash
helm repo add minio https://charts.min.io
helm repo update

helm install minio minio/minio \
  --namespace minio --create-namespace \
  --set rootUser=minioadmin \
  --set rootPassword=minioadmin \
  --set persistence.size=5Gi \
  --set replicas=1 \
  --set mode=standalone \
  --set resources.requests.memory=512Mi
```

3. Create MinIO buckets

   - Run the commands below to forward MinIO port to access the UI
   - Open `http://localhost:9001`
   - Creat buckets `mlflow` and `training`
   - Create path `vgm-datasets` in training bucket

```bash
# Find MinIO pod and port-forward S3 API (9000)
MINIO_POD=$(kubectl get pods --namespace minio -l "release=minio" -o jsonpath="{.items[0].metadata.name}")

kubectl port-forward -n minio "$MINIO_POD" 9001:9001
```

4. Apply MinIO config and MLflow server

```bash
kubectl apply -f ./kubernetes/minio-configuration.yaml
kubectl apply -f ./kubernetes/mlflow-setup.yaml
```

5. Run the training job and capture the model ID

> [!NOTE]  
> If the automatic model ID extraction doesn't work, check the training pod logs for the line `Model URI: `

```bash
kubectl apply -f ./kubernetes/train-job.yaml

TRAINING_POD=$(kubectl get pods -l job-name=train-job -o jsonpath="{.items[0].metadata.name}")

MODEL_ID=$(kubectl logs "$TRAINING_POD" | grep -o 'm-[a-zA-Z0-9]*' | tail -1)

echo "MODEL_ID = $MODEL_ID"
```

6. Install KServe and deploy the InferenceService

> [!NOTE]
> In the `kserve-inference.yaml` file, replace the storageUri placeholder `<model-ID>` with the model ID from the last step

```bash
# Install KServe
curl -s "https://raw.githubusercontent.com/kserve/kserve/release-0.15/hack/quick_install.sh" | bash -r

# Apply KServe resources
kubectl apply -f ./kubernetes/kserve-setup.yaml
kubectl apply -f ./kubernetes/kserve-inference.yaml
```

7. Install Prometheus and Grafana

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace prometheus --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin

kubectl apply -f ./kubernetes/prometheus-scraping-setup.yaml
```

8. Access services (in separate terminals)

```bash
# MinIO Console (already done when creating buckets)
kubectl port-forward -n minio svc/minio 9001:9001

# MLflow UI
minikube service mlflow-server-nodeport

# Grafana
kubectl port-forward -n prometheus svc/prometheus-grafana 3000:80

# Prometheus
kubectl port-forward -n prometheus svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Default creds:

- MinIO: minioadmin/minioadmin
- Grafana: admin/admin
