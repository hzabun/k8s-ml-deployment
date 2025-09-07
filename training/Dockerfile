FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy training script
RUN mkdir -p data
COPY train.py .
COPY data/video_game_sales.csv data/video_game_sales.csv

CMD ["python", "train.py"]
