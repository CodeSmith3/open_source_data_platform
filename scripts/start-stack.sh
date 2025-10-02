# Start de stack
chmod +x scripts/init-db.sh
./scripts/init-db.sh
# ...start docker-compose services...
#!/bin/bash
# Start de stack
chmod +x scripts/init-db.sh
./scripts/init-db.sh
# ...start docker-compose services...
#!/bin/bash

# Maak directories aan
echo "Creating directories..."
mkdir -p airflow/{dags,logs,plugins}
mkdir -p apisix_conf dashboard_conf
mkdir -p grafana/provisioning/{dashboards,datasources}

# Set permissions voor Airflow
echo "Setting Airflow permissions..."
echo -e "AIRFLOW_UID=50000" > .env
sudo chown -R 50000:0 airflow/

# Maak init-db.sh executable
chmod +x scripts/init-db.sh

# Start de services in de juiste volgorde
echo "Starting infrastructure services..."
docker-compose up -d postgres redis etcd zookeeper

echo "Waiting for infrastructure to be ready..."
sleep 30

echo "Starting storage and security services..."
docker-compose up -d minio vault keycloak

echo "Waiting for storage services..."
sleep 20

echo "Starting data processing services..."
docker-compose up -d kafka neo4j elasticsearch

echo "Waiting for supporting services..."
sleep 30

echo "Starting main application services..."
docker-compose up -d nifi airflow-webserver airflow-scheduler airflow-worker
docker-compose up -d spark-master spark-worker
docker-compose up -d superset
docker-compose up -d datahub-gms datahub-frontend

echo "Starting API gateway and monitoring..."
docker-compose up -d apisix apisix-dashboard
docker-compose up -d prometheus grafana loki promtail

echo "Starting remaining services..."
docker-compose up -d pgadmin httpbin minio-init

echo "Stack is starting up. This may take a few minutes..."
echo ""
echo "Services will be available at:"
echo "- Superset (BI): http://localhost:8088 (admin/admin)"
echo "- Airflow: http://localhost:8082 (admin/admin)" 
echo "- NiFi: http://localhost:8090 (admin/adminadmin)"
echo "- Grafana: http://localhost:3000 (admin/admin)"
echo "- MinIO Console: http://localhost:9001 (minioadmin/minioadmin123)"
echo "- Keycloak: http://localhost:8085 (admin/admin)"
echo "- Vault: http://localhost:8200 (token: myroot)"
echo "- APISIX Dashboard: http://localhost:9000 (admin/admin)"
echo "- DataHub: http://localhost:9001"
echo "- Spark UI: http://localhost:8083"
echo "- Prometheus: http://localhost:9090"
echo "- pgAdmin: http://localhost:8081 (admin@gemeente.nl/admin)"
echo ""
echo "Run 'docker-compose logs -f [service-name]' to check specific service logs"