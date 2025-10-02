#!/bin/bash

echo "=== Data Stack Health Check ==="
echo ""

services=(
    "postgres:5432"
    "redis:6379" 
    "minio:9000"
    "superset:8088"
    "airflow-webserver:8080"
    "grafana:3000"
    "prometheus:9090"
    "keycloak:8080"
    "vault:8200"
    "nifi:8080"
    "spark-master:8080"
    "apisix:9080"
    "datahub-gms:8080"
    "kafka:9092"
    "elasticsearch:9200"
)

for service in "${services[@]}"; do
    IFS=':' read -r host port <<< "$service"
    if docker exec $(docker ps -qf "name=$host") nc -z localhost $port 2>/dev/null; then
        echo "✅ $host:$port - OK"
    else
        echo "❌ $host:$port - NOT RESPONDING"
    fi
done

echo ""
echo "=== Docker Container Status ==="
docker-compose ps