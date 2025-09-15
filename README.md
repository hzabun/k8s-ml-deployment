# k8s-ml-deployment

Lightweight, local Kubernetes stack for model training, tracking, storage, serving, and observability on Minikube.

Components:

- MLflow: experiment tracking
- MinIO: S3-compatible object storage
- KServe: model serving
- Prometheus + Grafana: metrics and dashboards

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

## Cleanup

```bash
minikube delete
```

Note: This is intended for local exploration and iteration on Kubernetes ML workflows.
