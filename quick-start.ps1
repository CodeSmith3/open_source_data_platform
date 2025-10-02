# ===================================
# GEMEENTE DATA PLATFORM - QUICK START
# All-in-One Setup Script for Localhost
# Generates all files and starts services
# ===================================

param(
    [switch]$SkipTests,
    [switch]$Force
)

$ErrorActionPreference = "Continue"

function Write-Header {
    param($Text)
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param($StepNumber, $Total, $Message)
    Write-Host ""
    Write-Host "[$StepNumber/$Total] $Message" -ForegroundColor Blue
    Write-Host "================================================================"
}

function Write-Success {
    param($Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Info {
    param($Message)
    Write-Host "  [INFO] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param($Message)
    Write-Host "  [ERROR] $Message" -ForegroundColor Red
}

Clear-Host
Write-Header "GEMEENTE DATA PLATFORM - QUICK START"
Write-Host "All-in-One Setup for Localhost" -ForegroundColor White
Write-Host ""

$currentFolder = Split-Path -Leaf (Get-Location)
Write-Host "Current folder: $currentFolder" -ForegroundColor Cyan
Write-Host "Project will use consistent naming regardless of folder name" -ForegroundColor Gray
Write-Host ""

$TOTAL_STEPS = 14  # Changed from 15 to 14
$CURRENT_STEP = 0

# ===================================
# STAP 1: Prerequisites Check
# ===================================
$CURRENT_STEP++
Write-Step $CURRENT_STEP $TOTAL_STEPS "Checking prerequisites..."

try {
    $dockerVersion = docker --version
    Write-Success "Docker installed: $dockerVersion"
}
catch {
    Write-Error "Docker is not installed!"
    Write-Host "  Install Docker Desktop from: https://www.docker.com/products/docker-desktop"
    exit 1
}

try {
    docker ps | Out-Null
    Write-Success "Docker is running"
}
catch {
    Write-Error "Docker is not running!"
    Write-Host "  Start Docker Desktop and try again"
    exit 1
}

try {
    $composeVersion = docker-compose --version
    Write-Success "Docker Compose installed: $composeVersion"
}
catch {
    Write-Error "Docker Compose not found!"
    exit 1
}

# ===================================
# STAP 2: Stop existing services
# ===================================
$CURRENT_STEP++
Write-Step $CURRENT_STEP $TOTAL_STEPS "Stopping existing services..."

if (-not $Force) {
    $existing = docker ps -a --filter "name=gemeente" --format "{{.Names}}" 2>$null
    if ($existing) {
        Write-Info "Found existing containers. Stopping (this may take a minute)..."
        $null = docker-compose down 2>&1
        Start-Sleep -Seconds 5
        Write-Success "Existing services stopped"
    }
    else {
        Write-Success "No existing services found"
    }
}
else {
    Write-Info "Force mode: Cleaning everything (including volumes)..."
    $null = docker-compose down -v 2>&1
    
    # Remove network if it exists
    $networkName = "gemeente_data_platform_dev_backend"
    $networkExists = docker network ls --format "{{.Name}}" | Select-String $networkName
    if ($networkExists) {
        $null = docker network rm $networkName 2>&1
        Write-Success "Network removed"
    }
    
    Start-Sleep -Seconds 5
    Write-Success "Force cleanup complete"
}

Write-Info "Project folder: open-source-data-platform-main"
Write-Info "Container prefix will be: gemeente_data_platform_dev"

# ===================================
# STAP 3: Create directories
# ===================================
$CURRENT_STEP++
Write-Step $CURRENT_STEP $TOTAL_STEPS "Creating directories..."

$directories = @(
    "dags", "logs", "plugins", "config",
    "apisix_conf", "dashboard_conf",
    "grafana\provisioning\dashboards",
    "grafana\provisioning\datasources",
    "scripts"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

Write-Success "All directories created"

# ===================================
# STAP 4: Generate init-db.sh
# ===================================
$CURRENT_STEP++
Write-Step $CURRENT_STEP $TOTAL_STEPS "Generating database init script..."

$initDbScript = @'
#!/bin/bash
set -e
set -u

function create_user_and_database() {
    local database=$1
    local user=$2
    local password=$3
    
    echo "Creating user and database: $database"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$user') THEN
                CREATE USER $user WITH PASSWORD '$password';
            END IF;
        END
        \$\$;
        
        SELECT 'CREATE DATABASE $database OWNER $user'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$database')\gexec
        
        GRANT ALL PRIVILEGES ON DATABASE $database TO $user;
EOSQL
}

if [ -n "${POSTGRES_MULTIPLE_DATABASES:-}" ]; then
    echo "Creating multiple databases..."
    
    for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
        case $db in
            gemeente)
                create_user_and_database "gemeente" "gemeente" "${POSTGRES_PASSWORD:-gemeente123}"
                ;;
            superset)
                create_user_and_database "superset" "superset" "superset123"
                ;;
            airflow)
                create_user_and_database "airflow" "airflow" "airflow123"
                ;;
            keycloak)
                create_user_and_database "keycloak" "keycloak" "keycloak123"
                ;;
        esac
    done
fi

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "gemeente" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS postgis_topology;
EOSQL

echo "Database initialization complete!"
'@

Set-Content -Path "init-db.sh" -Value $initDbScript -Encoding UTF8
Write-Success "Database init script created"

# ===================================
# STAP 5: Generate Dashboard HTML
# ===================================
$CURRENT_STEP++
Write-Step $CURRENT_STEP $TOTAL_STEPS "Generating dashboard..."

$dashboardHtml = @'
<!DOCTYPE html>
<html lang="nl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gemeente Data Platform</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        :root {
            --bg-primary: #0a0e27;
            --bg-card: #1e2139;
            --text-primary: #ffffff;
            --text-secondary: #8b92b8;
            --accent-blue: #3b82f6;
            --accent-green: #10b981;
            --accent-red: #ef4444;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, var(--bg-primary) 0%, #151934 100%);
            color: var(--text-primary);
            min-height: 100vh;
            padding: 20px;
        }
        .container { max-width: 1400px; margin: 0 auto; }
        .header {
            text-align: center;
            margin-bottom: 40px;
            padding: 30px;
            background: var(--bg-card);
            border-radius: 20px;
        }
        .header h1 {
            font-size: 42px;
            background: linear-gradient(135deg, #3b82f6 0%, #8b5cf6 100%);
            background-clip: text;
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }
        .stat-card {
            background: var(--bg-card);
            padding: 25px;
            border-radius: 15px;
            text-align: center;
        }
        .stat-value {
            font-size: 36px;
            font-weight: 700;
            margin-bottom: 8px;
        }
        .stat-value.online { color: var(--accent-green); }
        .stat-label {
            font-size: 14px;
            color: var(--text-secondary);
            text-transform: uppercase;
        }
        .section { margin-bottom: 50px; }
        .section-title {
            font-size: 24px;
            font-weight: 700;
            margin-bottom: 25px;
        }
        .services-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
            gap: 20px;
        }
        .service-card {
            background: var(--bg-card);
            border-radius: 15px;
            padding: 25px;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        .service-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 40px rgba(59, 130, 246, 0.2);
        }
        .service-header {
            display: flex;
            align-items: center;
            gap: 15px;
            margin-bottom: 15px;
        }
        .service-icon { font-size: 48px; }
        .service-name {
            font-size: 20px;
            font-weight: 700;
        }
        .service-desc {
            font-size: 14px;
            color: var(--text-secondary);
            margin-bottom: 15px;
        }
        .service-status {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 8px 12px;
            border-radius: 8px;
            font-size: 12px;
            font-weight: 600;
        }
        .status-dot {
            width: 10px;
            height: 10px;
            border-radius: 50%;
            animation: pulse 2s infinite;
        }
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        .service-status.online {
            background: rgba(16, 185, 129, 0.1);
            color: var(--accent-green);
        }
        .service-status.online .status-dot { background: var(--accent-green); }
        .service-status.offline {
            background: rgba(239, 68, 68, 0.1);
            color: var(--accent-red);
        }
        .service-status.offline .status-dot { background: var(--accent-red); }
        .service-url {
            font-size: 12px;
            color: var(--text-secondary);
            font-family: 'Courier New', monospace;
            margin-top: 10px;
        }
        .quick-actions {
            position: fixed;
            bottom: 30px;
            right: 30px;
        }
        .action-btn {
            width: 60px;
            height: 60px;
            border-radius: 50%;
            background: linear-gradient(135deg, var(--accent-blue), var(--accent-green));
            border: none;
            color: white;
            font-size: 24px;
            cursor: pointer;
            box-shadow: 0 8px 24px rgba(59, 130, 246, 0.3);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Gemeente Data Platform</h1>
            <div style="color: var(--text-secondary); margin-top: 10px;">Centrale toegang tot alle data services</div>
        </div>

        <div class="stats">
            <div class="stat-card">
                <div class="stat-value online" id="statOnline">0</div>
                <div class="stat-label">Online</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="statOffline">0</div>
                <div class="stat-label">Offline</div>
            </div>
            <div class="stat-card">
                <div class="stat-value" id="statUptime">0%</div>
                <div class="stat-label">Uptime</div>
            </div>
        </div>

        <div class="section">
            <h2 class="section-title">Business Intelligence</h2>
            <div class="services-grid" id="biServices"></div>
        </div>

        <div class="section">
            <h2 class="section-title">Data Management</h2>
            <div class="services-grid" id="dataServices"></div>
        </div>

        <div class="section">
            <h2 class="section-title">Security & Identity</h2>
            <div class="services-grid" id="securityServices"></div>
        </div>

        <div class="section">
            <h2 class="section-title">Monitoring</h2>
            <div class="services-grid" id="monitoringServices"></div>
        </div>
    </div>

    <div class="quick-actions">
        <button class="action-btn" onclick="refreshStatus()" title="Refresh Status">&#8635;</button>
    </div>

    <script>
        const services = {
            bi: [
                { id: 'superset', name: 'Apache Superset', icon: '&#128202;', desc: 'BI & Visualisatie', port: 8088, health: '/health' },
                { id: 'airflow', name: 'Apache Airflow', icon: '&#127754;', desc: 'Data Pipelines', port: 8082, health: '/health' }
            ],
            data: [
                { id: 'pgadmin', name: 'pgAdmin', icon: '&#128024;', desc: 'Database Admin', port: 8081, health: '/misc/ping' },
                { id: 'minio', name: 'MinIO Console', icon: '&#129683;', desc: 'Object Storage', port: 9001, health: '/minio/health/live' }
            ],
            security: [
                { id: 'keycloak', name: 'Keycloak', icon: '&#128273;', desc: 'SSO & Identity', port: 8085, health: '/health/ready' },
                { id: 'vault', name: 'Vault', icon: '&#128274;', desc: 'Secrets Management', port: 8200, health: '/v1/sys/health' },
                { id: 'apisix', name: 'APISIX Dashboard', icon: '&#127760;', desc: 'API Gateway', port: 9000, health: '/' }
            ],
            monitoring: [
                { id: 'grafana', name: 'Grafana', icon: '&#128200;', desc: 'Monitoring', port: 13000, health: '/api/health' },
                { id: 'prometheus', name: 'Prometheus', icon: '&#128293;', desc: 'Metrics', port: 9090, health: '/-/healthy' },
                { id: 'dashboard', name: 'Dashboard', icon: '&#127968;', desc: 'Platform Overview', port: 8888, health: '/' }
            ]
        };

        let onlineCount = 0;
        let totalCount = 0;

        Object.values(services).forEach(cat => totalCount += cat.length);

        function createServiceCard(service) {
            const url = `http://localhost:${service.port}`;
            return `
                <div class="service-card" onclick="openService('${url}')" data-service="${service.id}">
                    <div class="service-header">
                        <div class="service-icon">${service.icon}</div>
                        <div>
                            <div class="service-name">${service.name}</div>
                        </div>
                    </div>
                    <div class="service-desc">${service.desc}</div>
                    <div class="service-status checking" id="status-${service.id}">
                        <div class="status-dot"></div>
                        <span>Checking...</span>
                    </div>
                    <div class="service-url">${url}</div>
                </div>
            `;
        }

        function renderServices() {
            document.getElementById('biServices').innerHTML = services.bi.map(createServiceCard).join('');
            document.getElementById('dataServices').innerHTML = services.data.map(createServiceCard).join('');
            document.getElementById('securityServices').innerHTML = services.security.map(createServiceCard).join('');
            document.getElementById('monitoringServices').innerHTML = services.monitoring.map(createServiceCard).join('');
        }

        async function checkService(service) {
            const statusEl = document.getElementById(`status-${service.id}`);
            const url = `http://localhost:${service.port}${service.health}`;
            
            try {
                const response = await fetch(url, { method: 'GET', mode: 'no-cors', cache: 'no-cache' });
                statusEl.className = 'service-status online';
                statusEl.innerHTML = '<div class="status-dot"></div><span>Online</span>';
                return true;
            } catch (error) {
                statusEl.className = 'service-status offline';
                statusEl.innerHTML = '<div class="status-dot"></div><span>Offline</span>';
                return false;
            }
        }

        async function checkAllServices() {
            onlineCount = 0;
            const allServices = [...services.bi, ...services.data, ...services.security, ...services.monitoring];
            
            const results = await Promise.all(allServices.map(async service => {
                const isOnline = await checkService(service);
                if (isOnline) onlineCount++;
                return isOnline;
            }));
            
            document.getElementById('statOnline').textContent = onlineCount;
            document.getElementById('statOffline').textContent = totalCount - onlineCount;
            
            const uptime = Math.round((onlineCount / totalCount) * 100);
            document.getElementById('statUptime').textContent = uptime + '%';
        }

        function openService(url) {
            window.open(url, '_blank');
        }

        function refreshStatus() {
            checkAllServices();
        }

        document.addEventListener('DOMContentLoaded', function() {
            renderServices();
            checkAllServices();
            setInterval(checkAllServices, 30000);
        });
    </script>
</body>
</html>
'@

Set-Content -Path "dashboard.html" -Value $dashboardHtml -Encoding UTF8
Write-Success "Dashboard HTML created"

# ===================================
# STAP 6: Generate NGINX config
# ===================================
$CURRENT_STEP++
Write-Step $CURRENT_STEP $TOTAL_STEPS "Generating nginx config..."

$nginxConfig = @'
server {
    listen 80;
    server_name _;
    
    add_header 'Access-Control-Allow-Origin' '*' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
    
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ /index.html;
    }
    
    location /api/health {
        return 200 '{"status":"ok"}';
        add_header Content-Type application/json;
    }
}
'@

Set-Content -Path "nginx.conf" -Value $nginxConfig -Encoding UTF8
Write-Success "Nginx config created"

# ===================================
# STAP 7: Generate .env file
# ===================================
$CURRENT_STEP++
Write-Step $CURRENT_STEP $TOTAL_STEPS "Generating environment file..."

$envContent = @'
# Gemeente Data Platform - Development Environment

# Docker Compose Project Name (keeps container names consistent)
COMPOSE_PROJECT_NAME=gemeente_data_platform_dev

# Airflow
AIRFLOW_UID=50000
AIRFLOW_ADMIN_PASSWORD=admin123
AIRFLOW_FERNET_KEY=Zv8-bGq6UQ_B0K8eQf7WEjPfzKXyUJrSCxP9vXzjZIs=
AIRFLOW_DB_PASSWORD=airflow123

# Database
POSTGRES_PASSWORD=gemeente123
POSTGRES_USER=gemeente

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=minioadmin123

# Keycloak
KEYCLOAK_ADMIN_PASSWORD=admin123

# Superset
SUPERSET_SECRET_KEY=DevKey2024SecureForGemeente
SUPERSET_ADMIN_PASSWORD=admin123

# Grafana
GRAFANA_ADMIN_PASSWORD=admin123

# pgAdmin
PGADMIN_DEFAULT_EMAIL=admin@gemeente.nl
PGADMIN_DEFAULT_PASSWORD=admin123

# Vault
VAULT_ROOT_TOKEN=myroot

# Redis
REDIS_PASSWORD=redis123

# OAuth2 Proxy
OAUTH2_PROXY_COOKIE_SECRET=0123456789abcdef0123456789abcdef
'@

Set-Content -Path ".env" -Value $envContent -Encoding UTF8
Write-Success "Environment file created"

# ===================================
# STAP 8: Generate prometheus.yml
# ===================================
$CURRENT_STEP++
Write-Step $CURRENT_STEP $TOTAL_STEPS "Generating prometheus config..."

$prometheusYml = @'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'apisix'
    static_configs:
      - targets: ['gemeente_apisix:9091']
'@

Set-Content -Path "prometheus.yml" -Value $prometheusYml -Encoding UTF8
Write-Success "Prometheus config created"

# ===================================
# STAP 9: Generate promtail-config.yml
# ===================================
$CURRENT_STEP++
Write-Step $CURRENT_STEP $TOTAL_STEPS "Generating promtail config..."

$promtailConfig = @'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://gemeente_loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log
'@

Set-Content -Path "promtail-config.yml" -Value $promtailConfig -Encoding UTF8
Write-Success "Promtail config created"

# ===================================
# STAP 10: Generate loki-config.yml
# ===================================
$CURRENT_STEP++
Write-Step $CURRENT_STEP $TOTAL_STEPS "Generating loki config..."

$lokiConfig = @'
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2020-05-15
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 168h

storage_config:
  boltdb:
    directory: /loki/index
  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
'@

Set-Content -Path "loki-config.yml" -Value $lokiConfig -Encoding UTF8
Write-Success "Loki config created"

# ===================================
# STAP 11: Generate APISIX configs
# ===================================
$CURRENT_STEP++
Write-Step $CURRENT_STEP $TOTAL_STEPS "Generating APISIX configs..."

$apisixConfig = @'
apisix:
  node_listen: 9080
  enable_admin: true
  enable_admin_cors: true
  enable_dev_mode: false
  enable_reuseport: true
  
  allow_admin:
    - 0.0.0.0/0

deployment:
  role: traditional
  role_traditional:
    config_provider: etcd
  
  admin:
    admin_key:
      - name: "admin"
        key: admin-key-dev
        role: admin

  etcd:
    host:
      - "http://gemeente_etcd:2379"
    prefix: "/apisix"
    timeout: 30
    
nginx_config:
  error_log_level: warn
'@

Set-Content -Path "apisix_conf/config.yaml" -Value $apisixConfig -Encoding UTF8

$dashboardConf = @'
conf:
  listen:
    host: 0.0.0.0
    port: 9000
  
  etcd:
    endpoints:
      - "gemeente_etcd:2379"
    prefix: /apisix
    
  log:
    error_log:
      level: warn
      file_path: /dev/stderr
    
    access_log:
      file_path: /dev/stdout

authentication:
  secret: secret
  expire_time: 3600
  users:
    - username: admin
      password: admin123
'@

Set-Content -Path "dashboard_conf/conf.yaml" -Value $dashboardConf -Encoding UTF8
Write-Success "APISIX configs created"

# ===================================
# STAP 12: Generate docker-compose.yml
# ===================================
$CURRENT_STEP++
Write-Step $CURRENT_STEP $TOTAL_STEPS "Generating docker-compose.yml (with localhost URLs)..."

Write-Info "This may take a moment - large file..."

$dockerComposeContent = @'
# Gemeente Data Platform - Docker Compose (Localhost Version)
# Auto-generated by quick-start.ps1

x-airflow-common:
  &airflow-common
  image: apache/airflow:2.8.1-python3.11
  environment:
    &airflow-common-env
    AIRFLOW__CORE__EXECUTOR: LocalExecutor
    AIRFLOW__CORE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:${AIRFLOW_DB_PASSWORD:-airflow123}@gemeente_postgres:5432/airflow
    AIRFLOW__CORE__FERNET_KEY: ${AIRFLOW_FERNET_KEY:-Zv8-bGq6UQ_B0K8eQf7WEjPfzKXyUJrSCxP9vXzjZIs=}
    AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION: 'true'
    AIRFLOW__CORE__LOAD_EXAMPLES: 'false'
    AIRFLOW__CORE__DEFAULT_TIMEZONE: Europe/Amsterdam
    AIRFLOW__WEBSERVER__EXPOSE_CONFIG: 'true'
    AIRFLOW__WEBSERVER__RBAC: 'true'
    AIRFLOW__WEBSERVER__BASE_URL: http://localhost:8082
    AIRFLOW__API__AUTH_BACKENDS: 'airflow.api.auth.backend.basic_auth,airflow.api.auth.backend.session'
    AIRFLOW__SCHEDULER__ENABLE_HEALTH_CHECK: 'true'
    AIRFLOW_OIDC_CLIENT_ID: ${AIRFLOW_OIDC_CLIENT_ID:-airflow}
    AIRFLOW_OIDC_CLIENT_SECRET: ${AIRFLOW_OIDC_CLIENT_SECRET:-airflow-client-secret}
    AIRFLOW_OIDC_TOKEN_URL: http://gemeente_keycloak:8080/realms/gemeente/protocol/openid-connect/token
    AIRFLOW_OIDC_AUTHORIZE_URL: http://localhost:8085/realms/gemeente/protocol/openid-connect/auth
    AIRFLOW_OIDC_JWKS_URL: http://gemeente_keycloak:8080/realms/gemeente/protocol/openid-connect/certs
    AIRFLOW_CONN_POSTGRES_DEFAULT: postgresql://gemeente:${POSTGRES_PASSWORD:-gemeente123}@gemeente_postgres:5432/gemeente
    AIRFLOW_CONN_MINIO_DEFAULT: aws://minioadmin:${MINIO_ROOT_PASSWORD:-minioadmin123}@?host=http://gemeente_minio:9000&region_name=us-east-1
    PYTHONPATH: /opt/airflow
  volumes:
    - ./dags:/opt/airflow/dags
    - ./logs:/opt/airflow/logs
    - ./plugins:/opt/airflow/plugins
    - ./config:/opt/airflow/config
  user: "${AIRFLOW_UID:-50000}:0"
  depends_on:
    &airflow-common-depends-on
    postgres:
      condition: service_healthy

services:
  postgres:
    image: postgis/postgis:15-3.3-alpine
    container_name: gemeente_postgres
    restart: always
    environment:
      POSTGRES_USER: ${POSTGRES_USER:-gemeente}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-gemeente123}
      POSTGRES_MULTIPLE_DATABASES: gemeente,superset,airflow,keycloak
    ports:
      - "20432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-db.sh:/docker-entrypoint-initdb.d/init-db.sh:ro
    networks:
      - backend
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U gemeente"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: gemeente_redis
    restart: always
    command: redis-server --requirepass ${REDIS_PASSWORD:-redis123}
    ports:
      - "20379:6379"
    volumes:
      - redis_data:/data
    networks:
      - backend
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "incr", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  minio:
    image: minio/minio:latest
    container_name: gemeente_minio
    restart: always
    environment:
      MINIO_ROOT_USER: ${MINIO_ROOT_USER:-minioadmin}
      MINIO_ROOT_PASSWORD: ${MINIO_ROOT_PASSWORD:-minioadmin123}
    command: server /data --console-address ":9001"
    ports:
      - "9002:9000"
      - "9001:9001"
    volumes:
      - minio_data:/data
    networks:
      - backend
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 10s
      retries: 3

  minio-init:
    image: minio/mc:latest
    container_name: gemeente_minio_init
    depends_on:
      - minio
    entrypoint: >
      /bin/sh -c "
      sleep 10;
      /usr/bin/mc config host add myminio http://gemeente_minio:9000 minioadmin minioadmin123;
      /usr/bin/mc mb myminio/airflow-logs --ignore-existing;
      /usr/bin/mc mb myminio/data-lake --ignore-existing;
      /usr/bin/mc mb myminio/backups --ignore-existing;
      exit 0;
      "
    networks:
      - backend

  keycloak:
    image: quay.io/keycloak/keycloak:23.0
    container_name: gemeente_keycloak
    restart: always
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://gemeente_postgres:5432/keycloak
      KC_DB_USERNAME: ${POSTGRES_USER:-gemeente}
      KC_DB_PASSWORD: ${POSTGRES_PASSWORD:-gemeente123}
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_ADMIN_PASSWORD:-admin123}
      KC_HOSTNAME_STRICT: 'false'
      KC_HTTP_ENABLED: 'true'
      KC_PROXY: edge
    command: start-dev
    ports:
      - "8085:8080"
    volumes:
      - keycloak_data:/opt/keycloak/data
    networks:
      - backend
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health/ready"]
      interval: 30s
      timeout: 10s
      retries: 5

  vault:
    image: hashicorp/vault:latest
    container_name: gemeente_vault
    restart: always
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: ${VAULT_ROOT_TOKEN:-myroot}
      VAULT_DEV_LISTEN_ADDRESS: 0.0.0.0:8200
    cap_add:
      - IPC_LOCK
    ports:
      - "8200:8200"
    volumes:
      - vault_data:/vault/data
    networks:
      - backend
    command: server -dev

  oauth2-proxy:
    image: quay.io/oauth2-proxy/oauth2-proxy:v7.5.1
    container_name: gemeente_oauth2_proxy
    restart: always
    depends_on:
      keycloak:
        condition: service_healthy
    environment:
      OAUTH2_PROXY_PROVIDER: keycloak-oidc
      OAUTH2_PROXY_CLIENT_ID: ${OAUTH2_PROXY_CLIENT_ID:-gemeente-platform}
      OAUTH2_PROXY_CLIENT_SECRET: ${OAUTH2_PROXY_CLIENT_SECRET:-gemeente-client-secret-change-me}
      OAUTH2_PROXY_REDIRECT_URL: http://localhost:4180/oauth2/callback
      OAUTH2_PROXY_OIDC_ISSUER_URL: http://localhost:8085/realms/gemeente
      OAUTH2_PROXY_COOKIE_SECRET: ${OAUTH2_PROXY_COOKIE_SECRET:-0123456789abcdef0123456789abcdef}
      OAUTH2_PROXY_COOKIE_SECURE: 'false'
      OAUTH2_PROXY_EMAIL_DOMAINS: '*'
      OAUTH2_PROXY_HTTP_ADDRESS: 0.0.0.0:4180
      OAUTH2_PROXY_UPSTREAMS: static://202
    ports:
      - "4180:4180"
    networks:
      - backend

  etcd:
    image: quay.io/coreos/etcd:v3.5.9
    container_name: gemeente_etcd
    restart: always
    environment:
      ETCD_ENABLE_V2: "true"
      ALLOW_NONE_AUTHENTICATION: "yes"
      ETCD_ADVERTISE_CLIENT_URLS: "http://gemeente_etcd:2379"
      ETCD_LISTEN_CLIENT_URLS: "http://0.0.0.0:2379"
    ports:
      - "2379:2379"
      - "2380:2380"
    volumes:
      - etcd_data:/etcd-data
    networks:
      - backend
    command: 
      - /usr/local/bin/etcd
      - --data-dir=/etcd-data
      - --name=node1
      - --initial-advertise-peer-urls=http://gemeente_etcd:2380
      - --listen-peer-urls=http://0.0.0.0:2380
      - --advertise-client-urls=http://gemeente_etcd:2379
      - --listen-client-urls=http://0.0.0.0:2379
      - --initial-cluster=node1=http://gemeente_etcd:2380

  apisix:
    image: apache/apisix:3.7.0-debian
    container_name: gemeente_apisix
    restart: always
    volumes:
      - ./apisix_conf/config.yaml:/usr/local/apisix/conf/config.yaml:ro
    ports:
      - "9080:9080"
      - "9443:9443"
    networks:
      - backend
    depends_on:
      - etcd

  apisix-dashboard:
    image: apache/apisix-dashboard:3.0.1-alpine
    container_name: gemeente_apisix_dashboard
    restart: always
    volumes:
      - ./dashboard_conf/conf.yaml:/usr/local/apisix-dashboard/conf/conf.yaml:ro
    ports:
      - "9000:9000"
    networks:
      - backend
    depends_on:
      - etcd

  superset:
    image: apache/superset:latest
    container_name: gemeente_superset
    restart: always
    environment:
      SUPERSET_SECRET_KEY: ${SUPERSET_SECRET_KEY:-DevKey2024SecureForGemeente}
      SUPERSET_LOAD_EXAMPLES: 'no'
      POSTGRES_DB: superset
      POSTGRES_USER: ${POSTGRES_USER:-gemeente}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-gemeente123}
      POSTGRES_HOST: gemeente_postgres
      POSTGRES_PORT: 5432
    ports:
      - "8088:8088"
    volumes:
      - superset_home:/app/superset_home
      - ./superset_config.py:/app/pythonpath/superset_config.py:ro
    networks:
      - backend
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8088/health"]
      interval: 30s
      timeout: 10s
      retries: 5

  superset-init:
    image: apache/superset:latest
    container_name: gemeente_superset_init
    command: >
      bash -c "
      superset db upgrade &&
      superset fab create-admin --username admin --firstname Admin --lastname User --email admin@gemeente.nl --password ${SUPERSET_ADMIN_PASSWORD:-admin123} || true &&
      superset init
      "
    environment:
      SUPERSET_SECRET_KEY: ${SUPERSET_SECRET_KEY:-DevKey2024SecureForGemeente}
      POSTGRES_DB: superset
      POSTGRES_USER: ${POSTGRES_USER:-gemeente}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-gemeente123}
      POSTGRES_HOST: gemeente_postgres
      POSTGRES_PORT: 5432
    volumes:
      - superset_home:/app/superset_home
      - ./superset_config.py:/app/pythonpath/superset_config.py:ro
    networks:
      - backend
    depends_on:
      postgres:
        condition: service_healthy

  airflow-init:
    <<: *airflow-common
    container_name: gemeente_airflow_init
    entrypoint: /bin/bash
    command:
      - -c
      - |
        pip install --no-cache-dir apache-airflow-providers-postgres apache-airflow-providers-amazon authlib flask-openid
        airflow db migrate
        airflow users create --username admin --password ${AIRFLOW_ADMIN_PASSWORD:-admin123} --firstname Admin --lastname User --role Admin --email admin@gemeente.nl || true
        echo "Airflow initialization complete!"
    environment:
      <<: *airflow-common-env
      _AIRFLOW_DB_MIGRATE: 'true'
      _AIRFLOW_WWW_USER_CREATE: 'true'
    networks:
      - backend

  airflow-webserver:
    <<: *airflow-common
    container_name: gemeente_airflow_webserver
    command: webserver
    ports:
      - "8082:8080"
    healthcheck:
      test: ["CMD", "curl", "--fail", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
    restart: always
    depends_on:
      <<: *airflow-common-depends-on
      airflow-init:
        condition: service_completed_successfully
    networks:
      - backend

  airflow-scheduler:
    <<: *airflow-common
    container_name: gemeente_airflow_scheduler
    command: scheduler
    healthcheck:
      test: ["CMD", "curl", "--fail", "http://localhost:8974/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
    restart: always
    depends_on:
      <<: *airflow-common-depends-on
      airflow-init:
        condition: service_completed_successfully
    networks:
      - backend

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: gemeente_pgadmin
    restart: always
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_DEFAULT_EMAIL:-admin@gemeente.nl}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_DEFAULT_PASSWORD:-admin123}
      PGADMIN_CONFIG_SERVER_MODE: 'False'
      PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED: 'False'
    ports:
      - "8081:80"
    volumes:
      - pgadmin_data:/var/lib/pgadmin
    networks:
      - backend
    depends_on:
      - postgres

  prometheus:
    image: prom/prometheus:latest
    container_name: gemeente_prometheus
    restart: always
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    networks:
      - backend
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3

  grafana:
    image: grafana/grafana:latest
    container_name: gemeente_grafana
    restart: always
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD:-admin123}
      GF_USERS_ALLOW_SIGN_UP: 'false'
      GF_INSTALL_PLUGINS: grafana-piechart-panel,redis-datasource
      GF_SERVER_ROOT_URL: http://localhost:13000
    ports:
      - "13000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
    networks:
      - backend
    depends_on:
      - prometheus
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  loki:
    image: grafana/loki:latest
    container_name: gemeente_loki
    restart: always
    ports:
      - "3100:3100"
    volumes:
      - ./loki-config.yml:/etc/loki/local-config.yaml:ro
      - loki_data:/loki
    networks:
      - backend
    command: -config.file=/etc/loki/local-config.yaml

  promtail:
    image: grafana/promtail:latest
    container_name: gemeente_promtail
    restart: always
    volumes:
      - ./promtail-config.yml:/etc/promtail/config.yml:ro
      - /var/log:/var/log:ro
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
    networks:
      - backend
    depends_on:
      - loki

  dashboard:
    image: nginx:alpine
    container_name: gemeente_dashboard
    restart: always
    ports:
      - "8888:80"
    volumes:
      - ./dashboard.html:/usr/share/nginx/html/index.html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    networks:
      - backend
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  postgres_data:
  pgadmin_data:
  superset_home:
  minio_data:
  keycloak_data:
  vault_data:
  redis_data:
  etcd_data:
  prometheus_data:
  grafana_data:
  loki_data:
  airflow_logs:
  airflow_plugins:

networks:
  backend:
    name: gemeente_data_platform_dev_backend
    driver: bridge
'@

Set-Content -Path "docker-compose.yml" -Value $dockerComposeContent -Encoding UTF8
Write-Success "docker-compose.yml created (with localhost URLs)"

# ===================================
# STAP 13: Generate superset_config.py
# ===================================
$CURRENT_STEP++
Write-Step $CURRENT_STEP $TOTAL_STEPS "Generating Superset config..."

$supersetConfig = @'
# Superset Configuration - Localhost
import os

SECRET_KEY = os.environ.get('SUPERSET_SECRET_KEY', 'DevKey2024SecureForGemeente')
SQLALCHEMY_DATABASE_URI = 'postgresql+psycopg2://superset:superset123@gemeente_postgres:5432/superset'
SQLALCHEMY_TRACK_MODIFICATIONS = False

# Disable CSRF for development
WTF_CSRF_ENABLED = False
WTF_CSRF_CHECK_DEFAULT = False
TALISMAN_ENABLED = False

# Session configuration
SESSION_COOKIE_HTTPONLY = False
SESSION_COOKIE_SECURE = False
SESSION_COOKIE_SAMESITE = None
SESSION_COOKIE_DOMAIN = None
PERMANENT_SESSION_LIFETIME = 86400
SESSION_PROTECTION = None
SESSION_TYPE = 'sqlalchemy'

# Application settings
SUPERSET_WEBSERVER_TIMEOUT = 300
ROW_LIMIT = 5000
ENABLE_PROXY_FIX = True
HTTP_HEADERS = {}

# Logging
import logging
LOG_LEVEL = logging.DEBUG
'@

Set-Content -Path "superset_config.py" -Value $supersetConfig -Encoding UTF8
Write-Success "Superset config created"

# ===================================
# STAP 14: Start all services
# ===================================
$CURRENT_STEP++
Write-Step $CURRENT_STEP $TOTAL_STEPS "Starting all services..."

Write-Host "  Starting infrastructure (postgres, redis, etcd)..."
docker-compose up -d postgres redis etcd
Write-Host "  Waiting 30 seconds..."
Start-Sleep -Seconds 30

Write-Host "  Starting storage & security (minio, keycloak, vault)..."
docker-compose up -d minio keycloak vault
Write-Host "  Waiting 20 seconds..."
Start-Sleep -Seconds 20

Write-Host "  Initializing MinIO buckets..."
docker-compose up -d minio-init

Write-Host "  Starting API gateway (apisix)..."
docker-compose up -d apisix apisix-dashboard
Start-Sleep -Seconds 10

Write-Host "  Starting Airflow init..."
docker-compose up -d airflow-init
Write-Host "  Waiting 45 seconds for Airflow init..."
Start-Sleep -Seconds 45

Write-Host "  Starting Airflow services..."
docker-compose up -d airflow-webserver airflow-scheduler

Write-Host "  Starting Superset init..."
docker-compose up -d superset-init
Write-Host "  Waiting 30 seconds for Superset init..."
Start-Sleep -Seconds 30

Write-Host "  Starting Superset..."
docker-compose up -d superset

Write-Host "  Starting other services..."
docker-compose up -d pgadmin oauth2-proxy
Start-Sleep -Seconds 20

Write-Host "  Starting monitoring & dashboard..."
docker-compose up -d prometheus grafana loki promtail dashboard
Start-Sleep -Seconds 20

Write-Success "All services started"

# ===================================
# Test services (optional)
# ===================================
if (-not $SkipTests) {
    Write-Host ""
    Write-Host "Service Status:" -ForegroundColor Yellow
    Write-Host ""
    
    $testServices = @(
        @{Name="Dashboard"; URL="http://localhost:8888"},
        @{Name="Superset"; URL="http://localhost:8088/health"},
        @{Name="Airflow"; URL="http://localhost:8082/health"},
        @{Name="pgAdmin"; URL="http://localhost:8081/misc/ping"},
        @{Name="MinIO"; URL="http://localhost:9001/minio/health/live"},
        @{Name="Keycloak"; URL="http://localhost:8085/health/ready"},
        @{Name="Grafana"; URL="http://localhost:13000/api/health"}
    )
    
    $onlineServices = 0
    
    foreach ($svc in $testServices) {
        Write-Host -NoNewline "  Testing $($svc.Name)... "
        try {
            $response = Invoke-WebRequest -Uri $svc.URL -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
            Write-Host "[ONLINE]" -ForegroundColor Green
            $onlineServices++
        }
        catch {
            Write-Host "[OFFLINE]" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Results: $onlineServices / $($testServices.Count) services online" -ForegroundColor Cyan
}

# ===================================
# FINAL: Show summary
# ===================================
Write-Host ""
Write-Header "DEPLOYMENT COMPLETE!"

Write-Host "Container Status:" -ForegroundColor Blue
docker-compose ps

Write-Host ""
Write-Host "Quick Access URLs:" -ForegroundColor Green
Write-Host ""
Write-Host "  Dashboard:    http://localhost:8888" -ForegroundColor White
Write-Host ""
Write-Host "  Superset:     http://localhost:8088  (admin/admin123)"
Write-Host "  Airflow:      http://localhost:8082  (admin/admin123)"
Write-Host "  pgAdmin:      http://localhost:8081  (admin@gemeente.nl/admin123)"
Write-Host "  MinIO:        http://localhost:9001  (minioadmin/minioadmin123)"
Write-Host "  Keycloak:     http://localhost:8085  (admin/admin123)"
Write-Host "  Grafana:      http://localhost:13000 (admin/admin123)"
Write-Host ""

Write-Host "Useful Commands:" -ForegroundColor Yellow
Write-Host "  Check logs:      docker-compose logs -f [service]"
Write-Host "  Restart service: docker-compose restart [service]"
Write-Host "  Stop all:        docker-compose down"
Write-Host ""

Write-Host "IMPORTANT - Superset:" -ForegroundColor Yellow
Write-Host "  If login issues occur, use INCOGNITO/PRIVATE browser window!"
Write-Host ""

Write-Host "All files generated and services started!" -ForegroundColor Green
Write-Host "Open Dashboard: http://localhost:8888" -ForegroundColor Cyan
Write-Host ""