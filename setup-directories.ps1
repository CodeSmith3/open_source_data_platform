# ===================================
# SETUP DIRECTORIES & CONFIG FILES
# Run this before starting docker-compose
# ===================================

Write-Host "Creating directories and config files..." -ForegroundColor Cyan
Write-Host ""

# Create directories
$directories = @(
    "apisix_conf",
    "dashboard_conf",
    "dags",
    "logs",
    "plugins",
    "config",
    "scripts",
    "grafana/provisioning/dashboards",
    "grafana/provisioning/datasources"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "OK Created: $dir" -ForegroundColor Green
    } else {
        Write-Host "  Already exists: $dir" -ForegroundColor Yellow
    }
}

Write-Host ""

# Create APISIX config if not exists
if (-not (Test-Path "apisix_conf/config.yaml")) {
    $apisixConfig = @'
apisix:
  node_listen: 9080
  enable_ipv6: false
  
  enable_control: true
  control:
    ip: "0.0.0.0"
    port: 9092

deployment:
  role: traditional
  role_traditional:
    config_provider: etcd
  
  admin:
    admin_key:
      - name: "admin"
        key: admin123
        role: admin
    enable_admin_cors: true
    allow_admin:
      - 0.0.0.0/0
  
  etcd:
    host:
      - "http://gemeente_etcd:2379"
    prefix: "/apisix"
    timeout: 30

plugin_attr:
  prometheus:
    export_addr:
      ip: "0.0.0.0"
      port: 9091
'@
    Set-Content -Path "apisix_conf/config.yaml" -Value $apisixConfig
    Write-Host "OK Created: apisix_conf/config.yaml" -ForegroundColor Green
}

# Create APISIX Dashboard config if not exists
if (-not (Test-Path "dashboard_conf/conf.yaml")) {
    $dashboardConfig = @'
conf:
  listen:
    host: 0.0.0.0
    port: 9000
  
  etcd:
    endpoints:
      - gemeente_etcd:2379
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
    Set-Content -Path "dashboard_conf/conf.yaml" -Value $dashboardConfig
    Write-Host "OK Created: dashboard_conf/conf.yaml" -ForegroundColor Green
}

# Create simple prometheus config if not exists
if (-not (Test-Path "prometheus.yml")) {
    $prometheusConfig = @'
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
    Set-Content -Path "prometheus.yml" -Value $prometheusConfig
    Write-Host "OK Created: prometheus.yml" -ForegroundColor Green
}

# Create simple loki config if not exists
if (-not (Test-Path "loki-config.yml")) {
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
    Set-Content -Path "loki-config.yml" -Value $lokiConfig
    Write-Host "OK Created: loki-config.yml" -ForegroundColor Green
}

# Create simple promtail config if not exists
if (-not (Test-Path "promtail-config.yml")) {
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
    Set-Content -Path "promtail-config.yml" -Value $promtailConfig
    Write-Host "OK Created: promtail-config.yml" -ForegroundColor Green
}

# Create docker network if not exists
Write-Host ""
Write-Host "Checking Docker network..." -ForegroundColor Cyan
$network = docker network ls --filter name=gemeente_data_platform_dev_backend --format "{{.Name}}" 2>$null
if (-not $network) {
    docker network create gemeente_data_platform_dev_backend
    Write-Host "OK Created: gemeente_data_platform_dev_backend network" -ForegroundColor Green
} else {
    Write-Host "  Network already exists" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Start services: docker-compose up -d"
Write-Host "2. Wait 2-3 minutes for initialization"
Write-Host "3. Test services: .\test-all-services.ps1"
Write-Host ""