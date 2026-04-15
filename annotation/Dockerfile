FROM python:3.13-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY server.py .
ENV CSV_PATH=/data/claims.csv
EXPOSE 8888
CMD ["python", "server.py"]
