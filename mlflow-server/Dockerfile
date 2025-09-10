FROM python:3.10-slim

WORKDIR /mlflow

COPY requirements.txt .
RUN pip install -r requirements.txt

RUN mkdir -p /mlflow/artifacts && \
    chmod -R 777 /mlflow

EXPOSE 5000

CMD ["mlflow", "server", \
    "--host", "0.0.0.0", \
    "--port", "5000", \
    "--backend-store-uri", "sqlite:////mlflow/mlflow.db", \
    "--default-artifact-root", "s3://mlflow/"]