# 🔧 Gemeente Data Platform - Beheerhandleiding

**Versie:** 2.0 (Development)  
**Laatst bijgewerkt:** September 2025  
**Voor:** IT Beheerders, Platform Administrators, DevOps

---

## 📋 Inhoudsopgave

1. [Platform Overzicht](#platform-overzicht)
2. [Gebruikersbeheer](#gebruikersbeheer)
3. [Docker & Container Beheer](#docker--container-beheer)
4. [Monitoring & Logging](#monitoring--logging)
5. [Backup & Recovery](#backup--recovery)
6. [Security & Compliance](#security--compliance)
7. [Troubleshooting & Diagnostics](#troubleshooting--diagnostics)
8. [Onderhoud & Updates](#onderhoud--updates)
9. [Email Configuratie](#email-configuratie)
10. [Production Deployment](#production-deployment)

---

## 🏗️ Platform Overzicht

### Architectuur

```
┌─────────────────────────────────────────────────────────┐
│                    Client Browser                        │
└─────────────────────┬───────────────────────────────────┘
                      │ HTTP
                      ▼
┌─────────────────────────────────────────────────────────┐
│              Network: gemeente_data_platform_dev_backend │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Keycloak   │  │  OAuth2-Proxy│  │    APISIX    │ │
│  │  (SSO Auth)  │  │  (Protected) │  │ (API Gateway)│ │
│  │   :8085      │  │    :4180     │  │    :9080     │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Airflow    │  │   Superset   │  │   Grafana    │ │
│  │  (Workflows) │  │     (BI)     │  │ (Monitoring) │ │
│  │   :8082      │  │    :8088     │  │   :13000     │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │  PostgreSQL  │  │    MinIO     │  │    Redis     │ │
│  │  (Database)  │  │  (Storage)   │  │   (Cache)    │ │
│  │   :20432     │  │  :9001/:9002 │  │   :20379     │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Prometheus   │  │     Loki     │  │     Spark    │ │
│  │  (Metrics)   │  │    (Logs)    │  │ (Processing) │ │
│  │   :9090      │  │    :3100     │  │   :28080     │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Server Specificaties

**Testserver:**
- OS: Rocky Linux 9.5
- IP: 192.168.1.25
- Access: Netwerkkabel verbinding
- Docker version: 24.x+
- Docker Compose version: 2.x+

**Development VM (Oracle VirtualBox):**
- OS: Rocky Linux 10
- Gebruikt voor lokale development en testing

### Componenten Status

| Service | Container Naam | Port(s) | Status | SSO |
|---------|---------------|---------|--------|-----|
| PostgreSQL | gemeente_postgres | 20432 | ✅ Running | - |
| pgAdmin | gemeente_pgadmin | 8081 | ✅ Running | ❌ |
| MinIO | gemeente_minio | 9001, 9002 | ✅ Running | ✅ |
| Keycloak | gemeente_keycloak | 8085 | ✅ Running | - |
| OAuth2-Proxy | gemeente_oauth2_proxy | 4180 | ✅ Running | ✅ |
| Vault | gemeente_vault | 8200 | ✅ Running | ✅ |
| Redis | gemeente_redis | 20379 | ✅ Running | - |
| Spark Master | gemeente_spark-master | 28080, 27077 | ✅ Running | - |
| Spark Worker | gemeente_spark-worker | - | ✅ Running | - |
| APISIX | gemeente_apisix | 9080, 29443 | ✅ Running | - |
| APISIX Dashboard | gemeente_apisix-dashboard | 9000 | ✅ Running | ✅ |
| Dashboard | gemeente_dashboard | 8888 | ✅ Running | - |
| Superset | gemeente_superset | 8088 | ✅ Running | ❌ |
| Prometheus | gemeente_prometheus | 9090 | ✅ Running | via Proxy |
| Grafana | gemeente_grafana | 13000 | ✅ Running | ✅ |
| Loki | gemeente_loki | 3100 | ✅ Running | via Proxy |
| Promtail | gemeente_promtail | - | ✅ Running | - |
| Neo4j | gemeente_neo4j | 7474, 7687 | ✅ Running | ❌ |
| Elasticsearch | gemeente_elasticsearch | 9200 | ✅ Running | via Proxy |
| Airflow Webserver | gemeente_airflow_webserver | 8082 | ✅ Running | ✅ |
| Airflow Scheduler | gemeente_airflow_scheduler | - | ✅ Running | - |

### Directory Structuur

```
/opt/gemeente-data-platform/
├── .env                          # Environment variabelen (passwords!)
├── docker-compose.yml            # Main compose file
├── docker-compose.airflow.yml    # Airflow services
├── docker-compose.sso.yml        # SSO overrides (optioneel)
├── superset_config.py            # Superset configuratie
├── dashboard.html                # Platform dashboard
├── CREDENTIALS.md                # Credentials overzicht
├── GEBRUIKERSHANDLEIDING.md      # Gebruikers documentatie
├── BEHEERHANDLEIDING.md          # Deze handleiding
│
├── scripts/                      # Utility scripts
│   ├── verify-sso-status.sh     # Check SSO status
│   ├── switch-environment.sh    # Switch dev/prod
│   ├── setup-complete-sso.sh    # SSO setup
│   └── cleanup-and-fix.sh       # Platform cleanup
│
├── dags/                         # Airflow DAGs
│   └── topdesk_departments_sync.py
│
├── config/                       # Service configs
│   ├── prometheus.yml
│   ├── loki-config.yml
│   ├── promtail-config.yml
│   ├── oauth2-proxy-config.yaml
│   └── pgadmin-servers.json
│
├── logs/                         # Application logs
├── backups/                      # Database backups
└── archived-scripts-*/           # Gearchiveerde scripts
```

---

## 👥 Gebruikersbeheer

### Keycloak - Centrale Identity Management

**Admin Console:** `http://192.168.1.25:8085/admin`  
**Login:** `admin` / `admin123`

#### Nieuwe gebruiker aanmaken

**Stap 1: Login in Keycloak Admin**
1. Ga naar `http://192.168.1.25:8085/admin`
2. Login met admin credentials
3. Selecteer realm **"gemeente"** (dropdown linksboven)

**Stap 2: User aanmaken**
1. Klik **Users** in linker menu
2. Klik **"Add user"** rechtsboven
3. Vul in:
   ```
   Username: jan.jansen
   Email: jan.jansen@gemeente.nl
   First name: Jan
   Last name: Jansen
   Email Verified: ON (aanvinken)
   Enabled: ON (aanvinken)
   ```
4. Klik **"Create"**

**Stap 3: Wachtwoord instellen**
1. Klik op **"Credentials"** tab
2. Klik **"Set password"**
3. Vul in:
   ```
   Password: Welkom2025!
   Password confirmation: Welkom2025!
   Temporary: ON (gebruiker moet wijzigen bij eerste login)
   ```
4. Klik **"Set password"** → Bevestig

**Stap 4: Rol toewijzen**
1. Klik op **"Role mappings"** tab
2. Klik **"Assign role"**
3. Filter op "gemeente" realm roles
4. Selecteer rol(len):
   - `data-admin` - Full access
   - `data-analyst` - BI/dashboards
   - `data-engineer` - Pipelines
   - `developer` - API/development
   - `viewer` - Read-only
   - `power-user` - Extended access
5. Klik **"Assign"**

**Stap 5: Test de gebruiker**
1. Open incognito venster
2. Ga naar `http://192.168.1.25:8082` (Airflow)
3. Klik "Sign in with keycloak"
4. Login met nieuwe credentials
5. Check of toegang werkt

#### Rollen en Permissions

**Standaard rollen:**

| Rol | Beschrijving | Toegang |
|-----|-------------|---------|
| **data-admin** | Platform beheerder | Alle services, full access |
| **data-analyst** | BI analist | Superset (edit), Grafana (editor), pgAdmin (read) |
| **data-engineer** | Data pipeline developer | Airflow (admin), pgAdmin (write), MinIO (write) |
| **developer** | Application developer | API access, development tools |
| **viewer** | Rapportage gebruiker | Superset (view), Grafana (view) |
| **power-user** | Advanced user | Extended access |

**Custom rol aanmaken:**
1. Keycloak Admin → Realm roles
2. Klik **"Create role"**
3. Naam: `custom_role`
4. Description: Beschrijving van de rol
5. Klik **"Save"**
6. Assign aan gebruikers via Role mappings

#### Gebruiker wijzigen/verwijderen

**Wachtwoord reset:**
1. Users → Selecteer gebruiker
2. Credentials tab → **"Reset password"**
3. Set new password (Temporary: ON)
4. Gebruiker krijgt email (als SMTP geconfigureerd) OF
5. Communiceer wachtwoord via veilig kanaal

**Gebruiker disablen (zonder verwijderen):**
1. Users → Selecteer gebruiker
2. Details tab
3. **Enabled:** Zet op OFF
4. Save
5. Gebruiker kan niet meer inloggen

**Gebruiker verwijderen:**
1. Users → Selecteer gebruiker
2. **Actions** dropdown → **"Delete"**
3. Bevestig
⚠️ **Let op:** Dit is permanent!

**Rol wijzigen:**
1. Users → Selecteer gebruiker
2. Role mappings tab
3. **Unassign** oude rollen
4. **Assign** nieuwe rollen

#### SSO Clients beheren

**Client overzicht:**
1. Keycloak Admin → Clients
2. Zie alle configured clients

**Belangrijke clients:**

| Client ID | Service | Redirect URIs |
|-----------|---------|---------------|
| gemeente-platform | OAuth2-Proxy | http://192.168.1.25:4180/oauth2/callback |
| grafana | Grafana | http://192.168.1.25:13000/* |
| superset | Superset (future) | http://192.168.1.25:8088/* |
| airflow | Airflow | http://192.168.1.25:8082/* |
| minio | MinIO | http://192.168.1.25:9001/oauth_callback |
| vault | Vault | http://192.168.1.25:8200/* |

**Client configuratie checken:**
1. Clients → Selecteer client
2. Check **Settings** tab:
   - Client authentication: ON (voor confidential clients)
   - Standard flow: ON
   - Valid redirect URIs: Correct ingevuld
3. Check **Credentials** tab:
   - Client secret matches .env file

**Client secret regenereren:**
1. Clients → Selecteer client
2. Credentials tab
3. Klik **"Regenerate"**
4. Kopieer nieuwe secret
5. Update in `.env` file
6. Restart affected services

#### Sessions beheren

**Actieve sessies bekijken:**
1. Keycloak Admin → Sessions
2. Zie alle active user sessions
3. Per client breakdown

**Session forcefully beëindigen:**
1. Users → Selecteer gebruiker
2. Sessions tab
3. Klik **"Sign out"** voor specifieke session
4. Of **"Sign out all sessions"**

**Session timeouts configureren:**
1. Realm settings → Sessions tab
2. Configureer:
   ```
   SSO Session Idle: 30 minutes (inactivity)
   SSO Session Max: 10 hours (absolute)
   Client Session Idle: 30 minutes
   Client Session Max: 10 hours
   ```
3. Save

#### User self-registration (optioneel)

⚠️ **Let op:** Momenteel DISABLED. Alleen admins maken accounts aan.

**Om self-registration te enablen:**
1. Realm settings → Login tab
2. **User registration:** ON
3. **Email verification:** ON (aanbevolen)
4. **Forgot password:** ON
5. Save

**⚠️ Vereist:** Email/SMTP moet geconfigureerd zijn!

### Superset - Local User Management

⚠️ **Let op:** Superset gebruikt **GEEN SSO** (voorlopig). Eigen user database.

**Admin interface:** Niet beschikbaar via UI voor user management.

**User aanmaken via CLI:**
```bash
# SSH naar server
ssh admin@192.168.1.25

# Exec into Superset container
docker exec -it gemeente_superset bash

# Create user
superset fab create-user \
  --username jan.jansen \
  --firstname Jan \
  --lastname Jansen \
  --email jan.jansen@gemeente.nl \
  --role Alpha \
  --password 'Welkom2025!'

# Exit container
exit
```

**Beschikbare rollen in Superset:**
- **Admin** - Full access
- **Alpha** - Create/edit dashboards + queries
- **Gamma** - View dashboards + limited query
- **Public** - View public dashboards only

**Wachtwoord reset (Superset):**
```bash
docker exec gemeente_superset superset fab reset-password \
  --username jan.jansen \
  --password 'NieuwWachtwoord123!'
```

**User verwijderen (Superset):**
```bash
docker exec gemeente_superset superset fab delete-user \
  --username jan.jansen
```

### pgAdmin - Local User Management

**Admin email:** `admin@gemeente.nl`  
**Access:** `http://192.168.1.25:8081`

**Nieuwe user aanmaken:**
⚠️ pgAdmin heeft geen multi-user setup in deze configuratie.
- Gebruik shared admin account voor development
- Of configureer OAuth2 voor pgAdmin (zie production deployment)

### MinIO - User Management

**Admin Console:** `http://192.168.1.25:9001`  
**Login:** `minioadmin` / `minioadmin123`

**IAM User aanmaken:**
1. Login in MinIO Console
2. **Identity** → **Users** (linker menu)
3. Klik **"Create User"**
4. Vul in:
   ```
   Access Key: jan.jansen
   Secret Key: VeiligWachtwoord123!
   ```
5. Klik **"Save"**

**Policy toewijzen:**
1. Users → Selecteer user
2. **Policies** tab
3. Attach policy:
   - `readonly` - Read-only access
   - `writeonly` - Write-only
   - `readwrite` - Full access to buckets
   - `consoleAdmin` - Admin access
4. Save

**Service Account aanmaken (voor applications):**
1. Identity → Service Accounts
2. Create Service Account
3. Select policy
4. Copy Access Key & Secret Key
5. Gebruik in applicatie config

---

## 🐳 Docker & Container Beheer

### Docker Compose Overzicht

**Main compose files:**
- `docker-compose.yml` - Core services
- `docker-compose.airflow.yml` - Airflow services
- `docker-compose.sso.yml` - SSO overrides (optioneel)

**Environment files:**
- `.env` - Development passwords
- `.env.production` - Production passwords (via switch script)

### Basis Container Commands

**Alle services starten:**
```bash
cd /opt/gemeente-data-platform

# Core services
docker-compose up -d

# Airflow services
docker-compose -f docker-compose.airflow.yml up -d
```

**Services stoppen:**
```bash
# Graceful stop
docker-compose stop

# Force stop
docker-compose kill

# Stop en verwijder containers
docker-compose down

# Stop en verwijder inclusief volumes (DATA LOSS!)
docker-compose down -v
```

**Specifieke service beheren:**
```bash
# Start
docker-compose up -d superset

# Stop
docker-compose stop superset

# Restart
docker-compose restart superset

# Logs bekijken
docker-compose logs -f superset

# Laatste 100 regels
docker-compose logs --tail=100 superset

# Container status
docker-compose ps superset
```

**Alle services status:**
```bash
# Via compose
docker-compose ps

# Detailed via docker
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Check health
docker ps --filter "name=gemeente" --format "table {{.Names}}\t{{.Status}}"
```

### Container Logs & Debugging

**Logs bekijken:**
```bash
# Real-time logs (alle services)
docker-compose logs -f

# Specifieke service
docker-compose logs -f keycloak

# Laatste 500 regels
docker-compose logs --tail=500 superset

# Logs sinds timestamp
docker-compose logs --since "2025-09-30T12:00:00" airflow-webserver

# Logs naar file
docker-compose logs superset > /tmp/superset-logs.txt
```

**Container inspecteren:**
```bash
# Container details
docker inspect gemeente_superset

# Volumes
docker inspect gemeente_superset | grep -A 10 Mounts

# Network
docker inspect gemeente_superset | grep -A 10 Networks

# Environment variables
docker inspect gemeente_superset | grep -A 50 Env
```

**In container shell:**
```bash
# Bash shell
docker exec -it gemeente_superset bash

# Als root
docker exec -u root -it gemeente_superset bash

# Eenmalig command
docker exec gemeente_superset ls -la /app

# Python shell (Superset)
docker exec -it gemeente_superset superset shell
```

**Container resource usage:**
```bash
# Real-time stats
docker stats

# Specifieke container
docker stats gemeente_superset

# Disk usage
docker system df

# Container sizes
docker ps -s
```

### Volume Management

**Volumes overzicht:**
```bash
# Alle volumes
docker volume ls

# Gemeente volumes only
docker volume ls | grep gemeente

# Volume inspect
docker volume inspect gemeente_data_platform_dev_postgres_data

# Volume size
docker system df -v
```

**Volume backup:**
```bash
# PostgreSQL data
docker run --rm \
  -v gemeente_data_platform_dev_postgres_data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/postgres-data-$(date +%Y%m%d).tar.gz /data

# Superset data
docker run --rm \
  -v gemeente_data_platform_dev_superset_home:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/superset-data-$(date +%Y%m%d).tar.gz /data

# MinIO data
docker run --rm \
  -v gemeente_data_platform_dev_minio_data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/minio-data-$(date +%Y%m%d).tar.gz /data
```

**Volume restore:**
```bash
# Stop services eerst
docker-compose stop postgres

# Restore
docker run --rm \
  -v gemeente_data_platform_dev_postgres_data:/data \
  -v $(pwd)/backups:/backup \
  alpine sh -c "cd / && tar xzf /backup/postgres-data-20250930.tar.gz"

# Start services
docker-compose start postgres
```

**Volume cleanup:**
```bash
# Verwijder unused volumes
docker volume prune

# Force remove specifiek volume (DANGER!)
docker volume rm gemeente_data_platform_dev_old_volume

# Cleanup all (DANGER!)
docker system prune -a --volumes
```

### Network Management

**Network overzicht:**
```bash
# Networks
docker network ls

# Inspect gemeente network
docker network inspect gemeente_data_platform_dev_backend

# Containers in network
docker network inspect gemeente_data_platform_dev_backend \
  | grep -A 3 Containers
```

**Network troubleshooting:**
```bash
# Test connectivity tussen containers
docker exec gemeente_superset ping gemeente_postgres

# DNS resolution test
docker exec gemeente_superset nslookup gemeente_postgres

# Port check
docker exec gemeente_superset nc -zv gemeente_postgres 5432

# Curl test
docker exec gemeente_superset curl -I http://gemeente_keycloak:8080/health
```

### Container Health Checks

**Health status:**
```bash
# Check all health
docker ps --format "table {{.Names}}\t{{.Status}}"

# Only unhealthy
docker ps --filter "health=unhealthy"

# Health check logs
docker inspect --format='{{json .State.Health}}' gemeente_keycloak | jq
```

**Custom health check:**
```bash
# Test PostgreSQL health
docker exec gemeente_postgres pg_isready -U gemeente

# Test Keycloak health
curl -f http://192.168.1.25:8085/health/ready

# Test Superset health
curl -f http://192.168.1.25:8088/health
```

### Docker Cleanup & Maintenance

**Scheduled cleanup (cron):**
```bash
# Edit crontab
crontab -e

# Add line (cleanup every Sunday 3 AM)
0 3 * * 0 docker system prune -f --volumes >> /var/log/docker-cleanup.log 2>&1
```

**Manual cleanup:**
```bash
# Remove stopped containers
docker container prune -f

# Remove unused images
docker image prune -a -f

# Remove unused volumes
docker volume prune -f

# Remove unused networks
docker network prune -f

# Complete cleanup (CAREFUL!)
docker system prune -a --volumes -f
```

**Disk space check:**
```bash
# Docker disk usage
docker system df -v

# Host disk usage
df -h

# Specific volume size
docker volume inspect gemeente_data_platform_dev_postgres_data \
  | grep Mountpoint | awk '{print $2}' | xargs du -sh
```

---

## 📊 Monitoring & Logging

### Prometheus - Metrics Collection

**Access:** `http://192.168.1.25:4180/prometheus/` (via OAuth2-proxy)  
**Direct:** Internal only (`gemeente_prometheus:9090`)

**Belangrijke metrics:**

**System metrics:**
```promql
# CPU usage per container
rate(container_cpu_usage_seconds_total[5m])

# Memory usage
container_memory_usage_bytes

# Network IO
rate(container_network_receive_bytes_total[5m])
rate(container_network_transmit_bytes_total[5m])

# Disk IO
rate(container_fs_reads_bytes_total[5m])
rate(container_fs_writes_bytes_total[5m])
```

**Application metrics:**
```promql
# Airflow task success rate
airflow_task_success_total / airflow_task_total

# Superset query duration
histogram_quantile(0.95, rate(superset_query_duration_seconds_bucket[5m]))

# PostgreSQL connections
pg_stat_database_numbackends

# Redis memory usage
redis_memory_used_bytes
```

**Prometheus configuratie aanpassen:**
```bash
# Edit config
nano prometheus.yml

# Test config
docker exec gemeente_prometheus promtool check config /etc/prometheus/prometheus.yml

# Reload config (zonder restart)
curl -X POST http://localhost:9090/-/reload

# Of restart
docker-compose restart prometheus
```

### Grafana - Dashboards

**Access:** `http://192.168.1.25:13000`  
**Login:** SSO (keycloak) of `admin` / `admin123`

**Dashboard importeren:**
1. **+ icon** (sidebar) → Import
2. Upload JSON of enter Grafana.com ID
3. Selecteer data source
4. Import

**Aanbevolen dashboards:**
- **Docker Container Metrics** (ID: 14282)
- **PostgreSQL Overview** (ID: 9628)
- **Redis Overview** (ID: 11835)
- **Node Exporter Full** (ID: 1860)

**Datasource configureren:**
1. Configuration (⚙️) → Data sources
2. Add data source
3. Prometheus:
   ```
   Name: Prometheus
   URL: http://gemeente_prometheus:9090
   ```
4. Loki:
   ```
   Name: Loki
   URL: http://gemeente_loki:3100
   ```
5. Save & test

**Alert instellen:**
1. Dashboard → Panel → Edit
2. Alert tab
3. Create Alert:
   ```
   Name: High CPU Usage
   Condition: avg() of query(A, 5m) > 80
   Evaluate: Every 1m for 5m
   Notifications: Email (admin@gemeente.nl)
   Message: CPU usage above 80% for 5 minutes
   ```
4. Save

### Loki - Log Aggregation

**Access:** `http://192.168.1.25:4180/loki/` (via OAuth2-proxy)

**Logs bekijken in Grafana:**
1. Explore (🔍 icon)
2. Selecteer **Loki** datasource
3. Query logs:
   ```logql
   # All logs from Superset
   {container="gemeente_superset"}
   
   # Error logs only
   {container="gemeente_superset"} |= "ERROR"
   
   # Logs last 5 minutes
   {container="gemeente_superset"} |= "ERROR" [5m]
   
   # Filter by level
   {container="gemeente_airflow_webserver"} | json | level="ERROR"
   ```

**Veelgebruikte queries:**
```logql
# Failed Airflow tasks
{container="gemeente_airflow_scheduler"} |= "Task failed"

# Superset login failures
{container="gemeente_superset"} |= "login" |= "failed"

# Database connection errors
{container=~"gemeente_.*"} |= "connection" |= "refused"

# Slow queries
{container="gemeente_postgres"} |= "duration" | regexp "duration: (?P<duration>\\d+)" | duration > 1000
```

### Promtail - Log Shipping

**Config:** `promtail-config.yml`

**Configuratie aanpassen:**
```yaml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://gemeente_loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        regex: '/(.*)$'
        target_label: 'container'
```

**Reload config:**
```bash
docker-compose restart promtail
```

### Monitoring Script

**Automated health check script:**

```bash
#!/bin/bash
# monitoring-check.sh

ALERT_EMAIL="admin@gemeente.nl"
LOGFILE="/var/log/gemeente-platform-health.log"

check_service() {
    local service=$1
    local url=$2
    
    if curl -sf "$url" > /dev/null; then
        echo "$(date) - OK: $service" >> "$LOGFILE"
        return 0
    else
        echo "$(date) - FAIL: $service" >> "$LOGFILE"
        echo "Service $service is down!" | mail -s "Alert: $service DOWN" "$ALERT_EMAIL"
        return 1
    fi
}

# Check all services
check_service "Keycloak" "http://192.168.1.25:8085/health/ready"
check_service "Superset" "http://192.168.1.25:8088/health"
check_service "Grafana" "http://192.168.1.25:13000/api/health"
check_service "Airflow" "http://192.168.1.25:8082/health"
check_service "MinIO" "http://192.168.1.25:9001/minio/health/live"

# Check PostgreSQL
if docker exec gemeente_postgres pg_isready -U gemeente > /dev/null; then
    echo "$(date) - OK: PostgreSQL" >> "$LOGFILE"
else
    echo "$(date) - FAIL: PostgreSQL" >> "$LOGFILE"
    echo "PostgreSQL is down!" | mail -s "Alert: PostgreSQL DOWN" "$ALERT_EMAIL"
fi

# Check disk space
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "$(date) - WARNING: Disk usage at ${DISK_USAGE}%" >> "$LOGFILE"
    echo "Disk usage is at ${DISK_USAGE}%!" | mail -s "Warning: High Disk Usage" "$ALERT_EMAIL"
fi
```

**Cron instellen:**
```bash
crontab -e

# Run every 5 minutes
*/5 * * * * /opt/gemeente-data-platform/scripts/monitoring-check.sh
```

### Platform Health Dashboard

**Gebruik verify-sso-status.sh:**
```bash
cd /opt/gemeente-data-platform

# Full check
./scripts/verify-sso-status.sh

# Specific checks
./scripts/verify-sso-status.sh --keycloak
./scripts/verify-sso-status.sh --docker
./scripts/verify-sso-status.sh --services
```

**Output voorbeeld:**
```
════════════════════════════════════════
           TEST SUMMARY                 
════════════════════════════════════════

Tests Passed: 18
Tests Failed: 0

✅ All tests passed! SSO is fully functional.
```

---

## 💾 Backup & Recovery

### Backup Strategy

**Aanbevolen schema:**
- **Daily:** Incremental database backups (PostgreSQL)
- **Weekly:** Full database backups + volumes
- **Monthly:** Complete system snapshot
- **Retention:** 7 dagelijkse, 4 wekelijkse, 12 maandelijkse

### PostgreSQL Database Backup

**Manual backup (binnen container):**
```bash
# Full database dump
docker exec gemeente_postgres pg_dumpall -U gemeente > /backups/full-backup-$(date +%Y%m%d).sql

# Specific database
docker exec gemeente_postgres pg_dump -U gemeente gemeente > /backups/gemeente-$(date +%Y%m%d).sql

# Compressed
docker exec gemeente_postgres pg_dump -U gemeente -F c gemeente > /backups/gemeente-$(date +%Y%m%d).dump
```

**Automated backup script:**

```bash
#!/bin/bash
# postgres-backup.sh

BACKUP_DIR="/opt/gemeente-data-platform/backups/postgres"
RETENTION_DAYS=7

mkdir -p "$BACKUP_DIR"

# Create backup
BACKUP_FILE="$BACKUP_DIR/full-backup-$(date +%Y%m%d-%H%M%S).sql"
docker exec gemeente_postgres pg_dumpall -U gemeente > "$BACKUP_FILE"

# Compress
gzip "$BACKUP_FILE"

# Clean old backups
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +$RETENTION_DAYS -delete

echo "Backup completed: ${BACKUP_FILE}.gz"
```

**Cron job:**
```bash
# Daily backup at 2 AM
0 2 * * * /opt/gemeente-data-platform/scripts/postgres-backup.sh >> /var/log/postgres-backup.log 2>&1
```

**Backup restore:**
```bash
# Stop services using database
docker-compose stop superset airflow-webserver airflow-scheduler

# Restore full dump
docker exec -i gemeente_postgres psql -U gemeente < /backups/full-backup-20250930.sql

# Restore specific database
docker exec -i gemeente_postgres psql -U gemeente -d gemeente < /backups/gemeente-20250930.sql

# Restore compressed custom format
docker exec gemeente_postgres pg_restore -U gemeente -d gemeente /backups/gemeente-20250930.dump

# Start services
docker-compose start superset airflow-webserver airflow-scheduler
```

### Volume Backups

**Backup all volumes:**
```bash
#!/bin/bash
# volume-backup.sh

BACKUP_DIR="/opt/gemeente-data-platform/backups/volumes"
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p "$BACKUP_DIR"

# Function to backup volume
backup_volume() {
    local volume=$1
    local name=$2
    
    echo "Backing up $name..."
    docker run --rm \
      -v $volume:/data \
      -v $BACKUP_DIR:/backup \
      alpine tar czf /backup/${name}-${DATE}.tar.gz /data
}

# Backup important volumes
backup_volume "gemeente_data_platform_dev_postgres_data" "postgres"
backup_volume "gemeente_data_platform_dev_superset_home" "superset"
backup_volume "gemeente_data_platform_dev_minio_data" "minio"
backup_volume "gemeente_data_platform_dev_keycloak_data" "keycloak"
backup_volume "gemeente_data_platform_dev_grafana_data" "grafana"
backup_volume "gemeente_data_platform_dev_airflow_logs" "airflow-logs"

# Cleanup old backups (keep 7 days)
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete

echo "Volume backup completed"
```

### Configuration Backup

**Backup configs:**
```bash
#!/bin/bash
# config-backup.sh

BACKUP_DIR="/opt/gemeente-data-platform/backups/configs"
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p "$BACKUP_DIR"

# Create backup archive
tar czf "$BACKUP_DIR/configs-${DATE}.tar.gz" \
  .env \
  docker-compose.yml \
  docker-compose.airflow.yml \
  superset_config.py \
  prometheus.yml \
  loki-config.yml \
  pgadmin-servers.json \
  dags/ \
  scripts/

# Keep last 30 backups
ls -t "$BACKUP_DIR"/configs-*.tar.gz | tail -n +31 | xargs -r rm

echo "Config backup completed: configs-${DATE}.tar.gz"
```

### Disaster Recovery Plan

**Complete system restore procedure:**

**Stap 1: Fresh install Docker**
```bash
# Install Docker & Docker Compose
# See installation guide

# Create network
docker network create gemeente_data_platform_dev_backend
```

**Stap 2: Restore configuratie**
```bash
cd /opt/gemeente-data-platform

# Extract configs
tar xzf backups/configs/configs-20250930-020000.tar.gz

# Verify .env file
cat .env
```

**Stap 3: Create volumes**
```bash
# Docker compose will create volumes automatically
docker-compose up -d postgres --no-start
```

**Stap 4: Restore volume data**
```bash
# Restore PostgreSQL data
docker run --rm \
  -v gemeente_data_platform_dev_postgres_data:/data \
  -v $(pwd)/backups/volumes:/backup \
  alpine sh -c "cd / && tar xzf /backup/postgres-20250930-020000.tar.gz"

# Restore MinIO data
docker run --rm \
  -v gemeente_data_platform_dev_minio_data:/data \
  -v $(pwd)/backups/volumes:/backup \
  alpine sh -c "cd / && tar xzf /backup/minio-20250930-020000.tar.gz"

# Repeat for other volumes...
```

**Stap 5: Start services**
```bash
# Start all services
docker-compose up -d
docker-compose -f docker-compose.airflow.yml up -d

# Check logs
docker-compose logs -f

# Verify health
./scripts/verify-sso-status.sh
```

**Stap 6: Verify & test**
```bash
# Test database
docker exec gemeente_postgres psql -U gemeente -c "SELECT count(*) FROM topdesk_departments;"

# Test Superset login
curl -X POST http://192.168.1.25:8088/api/v1/security/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123","provider":"db"}'

# Test Airflow
curl http://192.168.1.25:8082/health
```

### Backup to Remote Location

**Rsync to backup server:**
```bash
#!/bin/bash
# backup-to-remote.sh

LOCAL_BACKUP="/opt/gemeente-data-platform/backups"
REMOTE_USER="backup"
REMOTE_HOST="backup.gemeente.nl"
REMOTE_PATH="/backups/data-platform"

# Sync backups to remote
rsync -avz --delete \
  "$LOCAL_BACKUP/" \
  "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_PATH}/"

echo "Remote sync completed"
```

**S3/MinIO backup:**
```bash
# Install MinIO client
wget https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x mc
mv mc /usr/local/bin/

# Configure
mc alias set backup-minio https://backup.gemeente.nl minioadmin password

# Upload backups
mc mirror /opt/gemeente-data-platform/backups backup-minio/gemeente-platform-backups
```

---

## 🔒 Security & Compliance

### Password Management

**Development vs Production:**

**Current (Development):**
- Simple passwords: `admin123`, `gemeente123`, etc.
- Stored in `.env` file
- NOT for production use!

**Switch to production:**
```bash
cd /opt/gemeente-data-platform

# Generate production passwords
./scripts/switch-environment.sh prod

# Verify
cat .env | grep PASSWORD

# Restart all services
docker-compose down
docker-compose up -d
docker-compose -f docker-compose.airflow.yml up -d
```

**Password complexity requirements:**
```bash
# .env.production format
POSTGRES_PASSWORD=Gemeente@DB2024!Secure
KEYCLOAK_ADMIN_PASSWORD=Keycloak@Admin2024!
SUPERSET_SECRET_KEY=<64-character-random-string>
VAULT_ROOT_TOKEN=<32-character-random-string>
```

**Secret rotation schedule:**
- **Quarterly:** Database passwords, API keys
- **Annually:** Service account passwords, tokens
- **Immediately:** After suspected breach or staff departure

### Access Control

**Principle of Least Privilege:**
- Users krijgen ALLEEN de access die ze nodig hebben
- Review permissions quarterly
- Disable accounts bij vertrek medewerker

**Role-based access example:**

| Rol | Airflow | Superset | pgAdmin | MinIO | Keycloak |
|-----|---------|----------|---------|-------|----------|
| Data Analyst | ❌ | ✅ Edit | ✅ Read | ❌ | ❌ |
| Data Engineer | ✅ Admin | ✅ View | ✅ Write | ✅ Write | ❌ |
| DB Admin | ❌ | ❌ | ✅ Admin | ✅ Read | ❌ |
| Platform Admin | ✅ Admin | ✅ Admin | ✅ Admin | ✅ Admin | ✅ Admin |

**SSH access:**
```bash
# Disable root login
sudo nano /etc/ssh/sshd_config
# Set: PermitRootLogin no

# Require key authentication
# Set: PasswordAuthentication no
# Set: PubkeyAuthentication yes

# Restart SSH
sudo systemctl restart sshd

# Firewall rules
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.0.0.0/8" port port="22" protocol="tcp" accept'
sudo firewall-cmd --reload
```

### Network Security

**Firewall configuratie:**
```bash
# Allow only from internal network
sudo firewall-cmd --permanent --zone=internal --add-source=192.168.1.0/24

# Open platform ports (internal only)
sudo firewall-cmd --permanent --zone=internal --add-port=8085/tcp  # Keycloak
sudo firewall-cmd --permanent --zone=internal --add-port=8088/tcp  # Superset
sudo firewall-cmd --permanent --zone=internal --add-port=8082/tcp  # Airflow
sudo firewall-cmd --permanent --zone=internal --add-port=13000/tcp # Grafana
sudo firewall-cmd --permanent --zone=internal --add-port=9001/tcp  # MinIO
sudo firewall-cmd --permanent --zone=internal --add-port=8081/tcp  # pgAdmin

# Block from public
sudo firewall-cmd --permanent --zone=public --remove-port=8085/tcp

# Reload
sudo firewall-cmd --reload

# Check rules
sudo firewall-cmd --list-all
```

**Docker network isolation:**
```yaml
# docker-compose.yml
networks:
  backend:
    external: false
    internal: true  # No internet access
  frontend:
    external: false
    internal: false  # Internet access
```

### SSL/TLS (Production)

**Generate certificates:**
```bash
# Self-signed (development/testing)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /opt/certs/platform.key \
  -out /opt/certs/platform.crt \
  -subj "/CN=192.168.1.25"

# Let's Encrypt (production with domain)
sudo certbot certonly --standalone -d data.gemeente.nl
```

**Configure Nginx reverse proxy:**
```nginx
# /etc/nginx/conf.d/gemeente-platform.conf

upstream keycloak {
    server 192.168.1.25:8085;
}

upstream superset {
    server 192.168.1.25:8088;
}

server {
    listen 443 ssl http2;
    server_name data.gemeente.nl;

    ssl_certificate /etc/letsencrypt/live/data.gemeente.nl/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/data.gemeente.nl/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    # Keycloak
    location /auth/ {
        proxy_pass http://keycloak/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Superset
    location /superset/ {
        proxy_pass http://superset/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}

server {
    listen 80;
    server_name data.gemeente.nl;
    return 301 https://$server_name$request_uri;
}
```

### Audit Logging

**Enable audit logs:**

**Keycloak:**
1. Admin Console → Events
2. **Config** tab
3. Enable:
   - ✅ Save Events
   - ✅ Login Events
   - ✅ Admin Events
4. Expiration: 365 days
5. Save

**PostgreSQL:**
```sql
-- Enable query logging
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';
SELECT pg_reload_conf();

-- View logs
SELECT * FROM pg_stat_activity;

-- Audit specific table
CREATE EXTENSION IF NOT EXISTS pgaudit;
ALTER SYSTEM SET pgaudit.log = 'write, ddl';
```

**Docker audit:**
```bash
# Enable audit logging
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3",
    "labels": "production_status,environment"
  }
}
EOF

sudo systemctl restart docker
```

**Centralized audit log collection:**
```bash
# Send logs to Loki
docker run -d \
  --name audit-promtail \
  -v /var/log/audit:/var/log/audit:ro \
  -v ./promtail-audit.yml:/etc/promtail/config.yml \
  grafana/promtail
```

### Vulnerability Scanning

**Scan containers:**
```bash
# Install Trivy
sudo rpm -ivh https://github.com/aquasecurity/trivy/releases/download/v0.45.0/trivy_0.45.0_Linux-64bit.rpm

# Scan all images
docker images --format "{{.Repository}}:{{.Tag}}" | \
  xargs -I {} trivy image --severity HIGH,CRITICAL {}

# Scan specific image
trivy image apache/superset:3.0.0

# Generate report
trivy image --format json --output report.json apache/superset:3.0.0
```

**Automated scanning (weekly):**
```bash
#!/bin/bash
# security-scan.sh

REPORT_DIR="/opt/security-reports"
DATE=$(date +%Y%m%d)

mkdir -p "$REPORT_DIR"

# Scan all running containers
for container in $(docker ps --format "{{.Names}}"); do
    image=$(docker inspect --format='{{.Config.Image}}' "$container")
    echo "Scanning $container ($image)..."
    
    trivy image --severity HIGH,CRITICAL \
      --format json \
      --output "$REPORT_DIR/${container}-${DATE}.json" \
      "$image"
done

# Email report
cat "$REPORT_DIR"/*-${DATE}.json | \
  mail -s "Security Scan Report - $DATE" admin@gemeente.nl
```

### Compliance Checklist

**GDPR Compliance:**
- [ ] Data encryption at rest (volumes)
- [ ] Data encryption in transit (SSL/TLS)
- [ ] Access logging enabled
- [ ] User consent management (if applicable)
- [ ] Right to erasure procedure documented
- [ ] Data retention policy defined
- [ ] Privacy impact assessment completed
- [ ] Data Processing Agreement signed

**BIO (Baseline Informatiebeveiliging Overheid):**
- [ ] Access control implemented (least privilege)
- [ ] Multi-factor authentication for admins
- [ ] Regular security updates
- [ ] Incident response plan
- [ ] Backup and recovery tested
- [ ] Audit trails enabled
- [ ] Network segmentation
- [ ] Security awareness training

---

## 🔍 Troubleshooting & Diagnostics

### Common Issues & Solutions

#### Issue: Container won't start

**Symptoms:**
```bash
docker-compose up -d superset
# Returns: Error starting userland proxy: listen tcp4 0.0.0.0:8088: bind: address already in use
```

**Diagnose:**
```bash
# Check what's using the port
sudo lsof -i :8088

# Or
sudo netstat -tulpn | grep 8088

# Check docker logs
docker-compose logs superset
```

**Solution:**
```bash
# Stop conflicting service
sudo systemctl stop conflicting-service

# Or use different port in docker-compose.yml
ports:
  - "8089:8088"  # Changed from 8088:8088

# Restart
docker-compose up -d superset
```

#### Issue: Container keeps restarting

**Symptoms:**
```bash
docker ps
# Status shows: Restarting (1) 10 seconds ago
```

**Diagnose:**
```bash
# Check logs
docker logs gemeente_superset --tail 100

# Check exit code
docker inspect gemeente_superset | grep -A 5 State

# Check health
docker inspect gemeente_superset | grep -A 10 Health
```

**Common causes:**
1. **Configuration error:** Check logs for config syntax errors
2. **Missing dependency:** Service tries to connect to unavailable database
3. **Resource limits:** Container OOM killed
4. **Permission issues:** Cannot write to volume

**Solution:**
```bash
# Fix depends_on
docker-compose.yml:
depends_on:
  postgres:
    condition: service_healthy  # Wait for healthy, not just started

# Fix resource limits
deploy:
  resources:
    limits:
      memory: 2G  # Increase limit

# Fix permissions
docker exec -u root gemeente_superset chown -R superset:superset /app
```

#### Issue: Cannot connect to database

**Symptoms:**
```
psycopg2.OperationalError: could not connect to server: Connection refused
```

**Diagnose:**
```bash
# Check if PostgreSQL is running
docker ps | grep postgres

# Test connection from host
docker exec gemeente_postgres psql -U gemeente -c "SELECT 1;"

# Test connection from container
docker exec gemeente_superset psql -h gemeente_postgres -U gemeente -c "SELECT 1;"

# Check network
docker network inspect gemeente_data_platform_dev_backend | grep postgres
```

**Solution:**
```bash
# Wrong hostname (localhost vs gemeente_postgres)
# Use container name: gemeente_postgres

# Check credentials
docker exec gemeente_postgres psql -U gemeente -c "\du"

# Reset password
docker exec gemeente_postgres psql -U postgres -c "ALTER USER gemeente PASSWORD 'gemeente123';"

# Check PostgreSQL is accepting connections
docker exec gemeente_postgres cat /var/lib/postgresql/data/pg_hba.conf
# Should have: host all all all md5
```

#### Issue: SSO login fails

**Symptoms:**
- Redirect loop
- "Invalid redirect URI"
- "Client authentication failed"

**Diagnose:**
```bash
# Check Keycloak is running
curl http://192.168.1.25:8085/health/ready

# Test token endpoint
curl -X POST http://192.168.1.25:8085/realms/gemeente/protocol/openid-connect/token \
  -d "client_id=gemeente-platform" \
  -d "client_secret=gemeente-client-secret-change-me" \
  -d "grant_type=password" \
  -d "username=admin" \
  -d "password=admin123"

# Check redirect URIs in Keycloak
# Admin Console → Clients → gemeente-platform → Valid Redirect URIs

# Check browser cookies
# Open DevTools → Application → Cookies → Check for duplicate/old cookies
```

**Solution:**
```bash
# Fix redirect URI
# In Keycloak client config, add:
http://192.168.1.25:4180/oauth2/callback
http://192.168.1.25:4180/oauth2/callback/*

# Clear browser cache
# Incognito mode: Ctrl+Shift+N

# Restart OAuth2-proxy with correct config
docker-compose restart oauth2-proxy

# Check OAuth2-proxy logs
docker logs gemeente_oauth2_proxy -f
```

#### Issue: Slow query performance

**Symptoms:**
- Dashboards take >30 seconds to load
- Queries timeout
- High CPU usage

**Diagnose:**
```bash
# Check active queries
docker exec gemeente_postgres psql -U gemeente -c "
SELECT 
    pid, 
    now() - query_start AS duration,
    query
FROM pg_stat_activity
WHERE state = 'active'
ORDER BY duration DESC;
"

# Check table bloat
docker exec gemeente_postgres psql -U gemeente -c "
SELECT 
    schemaname,
    tablename,
    n_dead_tup AS dead_rows,
    n_live_tup AS live_rows
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000
ORDER BY n_dead_tup DESC;
"

# Check missing indexes
docker exec gemeente_postgres psql -U gemeente -c "
SELECT 
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation
FROM pg_stats
WHERE schemaname = 'public'
AND n_distinct > 100
ORDER BY n_distinct DESC;
"
```

**Solution:**
```bash
# Add missing indexes
docker exec gemeente_postgres psql -U gemeente -c "
CREATE INDEX idx_topdesk_dept_id ON topdesk_departments(dept_id);
CREATE INDEX idx_topdesk_archived ON topdesk_departments(archived) WHERE archived = false;
"

# Vacuum tables
docker exec gemeente_postgres psql -U gemeente -c "
VACUUM ANALYZE topdesk_departments;
"

# Increase work_mem (temporary)
docker exec gemeente_postgres psql -U gemeente -c "
ALTER SYSTEM SET work_mem = '256MB';
SELECT pg_reload_conf();
"

# Kill slow query
docker exec gemeente_postgres psql -U gemeente -c "
SELECT pg_terminate_backend(12345);  -- Replace with PID
"
```

#### Issue: Out of disk space

**Symptoms:**
```
Error: No space left on device
```

**Diagnose:**
```bash
# Check disk usage
df -h

# Check Docker usage
docker system df -v

# Check largest volumes
du -sh /var/lib/docker/volumes/* | sort -h | tail -20

# Check logs
du -sh /var/lib/docker/containers/*/
```

**Solution:**
```bash
# Clean Docker
docker system prune -a --volumes -f

# Rotate logs
find /var/lib/docker/containers/ -name "*.log" -mtime +7 -delete

# Remove old backups
find /opt/gemeente-data-platform/backups -mtime +30 -delete

# Vacuum PostgreSQL
docker exec gemeente_postgres psql -U gemeente -c "VACUUM FULL;"

# Expand disk (if VM)
# 1. Expand disk in hypervisor
# 2. Extend partition
sudo growpart /dev/sda 2
sudo xfs_growfs /
```

### Diagnostic Scripts

**Complete health check:**
```bash
#!/bin/bash
# health-check.sh

echo "=== Gemeente Data Platform Health Check ==="
echo ""

# Docker daemon
echo "Docker daemon:"
systemctl is-active docker && echo "✅ Running" || echo "❌ Not running"
echo ""

# Disk space
echo "Disk space:"
df -h / | tail -1
echo ""

# Memory
echo "Memory:"
free -h | grep Mem
echo ""

# Container status
echo "Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep gemeente
echo ""

# Network connectivity
echo "Network:"
ping -c 1 192.168.1.25 > /dev/null && echo "✅ Network OK" || echo "❌ Network issue"
echo ""

# Service health
echo "Service health:"
services=(
  "Keycloak:http://192.168.1.25:8085/health/ready"
  "Superset:http://192.168.1.25:8088/health"
  "Grafana:http://192.168.1.25:13000/api/health"
  "Airflow:http://192.168.1.25:8082/health"
)

for service in "${services[@]}"; do
  name="${service%%:*}"
  url="${service#*:}"
  
  if curl -sf "$url" > /dev/null 2>&1; then
    echo "✅ $name"
  else
    echo "❌ $name"
  fi
done

echo ""
echo "=== End Health Check ==="
```

**Performance analysis:**
```bash
#!/bin/bash
# performance-check.sh

echo "=== Performance Analysis ==="
echo ""

# Container CPU usage
echo "Container CPU usage (%):"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}" | \
  grep gemeente | sort -k2 -rn | head -10
echo ""

# Container memory usage
echo "Container memory usage:"
docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}" | \
  grep gemeente | head -10
echo ""

# PostgreSQL connections
echo "PostgreSQL connections:"
docker exec gemeente_postgres psql -U gemeente -c "
SELECT 
    datname,
    count(*) AS connections
FROM pg_stat_activity
GROUP BY datname
ORDER BY connections DESC;
"
echo ""

# Slow queries (>5 seconds)
echo "Slow queries:"
docker exec gemeente_postgres psql -U gemeente -c "
SELECT 
    pid,
    now() - query_start AS duration,
    left(query, 80) AS query
FROM pg_stat_activity
WHERE state = 'active'
  AND query NOT LIKE '%pg_stat_activity%'
  AND now() - query_start > interval '5 seconds'
ORDER BY duration DESC;
"
```

---

## 🔄 Onderhoud & Updates

### Regular Maintenance Schedule

**Daily:**
- Check service health (`verify-sso-status.sh`)
- Review error logs
- Monitor disk space

**Weekly:**
- Database vacuuming
- Log rotation
- Security vulnerability scan
- Review user access logs

**Monthly:**
- Update container images
- Review and update documentation
- Test backup restore
- Security audit
- Performance optimization

**Quarterly:**
- Password rotation
- Access rights review
- Disaster recovery drill
- Compliance audit

### Container Updates

**Check for updates:**
```bash
# List current versions
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}"

# Check DockerHub for new versions
# apache/superset: https://hub.docker.com/r/apache/superset/tags
# grafana/grafana: https://hub.docker.com/r/grafana/grafana/tags
```

**Update procedure:**

**Stap 1: Backup alles**
```bash
# Database backup
./scripts/postgres-backup.sh

# Volume backup
./scripts/volume-backup.sh

# Config backup
./scripts/config-backup.sh
```

**Stap 2: Test in development**
```bash
# Pull new images
docker-compose pull

# Check release notes
# Read CHANGELOG for breaking changes

# Test upgrade path
docker-compose up -d --no-deps superset
docker logs -f gemeente_superset

# If OK, proceed. If issues, rollback:
docker-compose down
# Restore from backup
```

**Stap 3: Update production**
```bash
# Maintenance window announcement
# Email users: "Platform maintenance 02:00-04:00"

# During maintenance window:
docker-compose down

# Pull new images
docker-compose pull

# Start services
docker-compose up -d

# Monitor logs
docker-compose logs -f

# Verify all services
./scripts/verify-sso-status.sh
```

**Stap 4: Rollback (indien nodig)**
```bash
# Stop new version
docker-compose down

# Restore old image
docker-compose -f docker-compose.backup.yml up -d

# Or restore from backup
# See disaster recovery section
```

### Database Maintenance

**Vacuum & analyze:**
```bash
# Automated weekly vacuum
cat > /etc/cron.weekly/postgres-maintenance <<'EOF'
#!/bin/bash
docker exec gemeente_postgres psql -U gemeente -c "
VACUUM ANALYZE;
REINDEX DATABASE gemeente;
"
EOF

chmod +x /etc/cron.weekly/postgres-maintenance
```

**Index maintenance:**
```sql
-- Find bloated indexes
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size,
    idx_scan AS scans
FROM pg_stat_user_indexes
ORDER BY pg_relation_size(indexrelid) DESC;

-- Rebuild bloated indexes
REINDEX INDEX CONCURRENTLY idx_name;

-- Remove unused indexes (scans = 0)
DROP INDEX idx_unused;
```

**Statistics update:**
```sql
-- Update table statistics
ANALYZE topdesk_departments;

-- Update all tables
ANALYZE;

-- Check last analyze time
SELECT
    schemaname,
    tablename,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
ORDER BY last_analyze;
```

### Log Management

**Configure log rotation:**
```bash
# /etc/logrotate.d/gemeente-platform
/opt/gemeente-data-platform/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
    sharedscripts
    postrotate
        docker-compose restart promtail
    endscript
}
```

**Docker log limits:**
```json
// /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
```

### Configuration Management

**Version control configs:**
```bash
cd /opt/gemeente-data-platform

# Initialize git repo
git init
git add .env.example docker-compose.yml superset_config.py
git commit -m "Initial commit"

# Create branch for changes
git checkout -b update-superset-config

# Make changes
nano superset_config.py

# Commit
git add superset_config.py
git commit -m "Update session timeout"

# Merge to main
git checkout main
git merge update-superset-config
```

**⚠️ Never commit `.env` with real passwords!**

---

## 📧 Email Configuratie

### SMTP Setup voor Keycloak

**⚠️ Belangrijk:** Email is momenteel NIET geconfigureerd. Dit is nodig voor:
- Password reset emails
- User verification emails
- Notifications

**SMTP configuratie:**

**Optie 1: Gmail SMTP (development/testing)**

1. **Create App Password in Gmail:**
   - Ga naar Google Account → Security
   - Enable 2-factor authentication
   - App Passwords → Generate for "Mail"
   - Kopieer generated password

2. **Configure in Keycloak:**
   - Keycloak Admin → Realm Settings → Email tab
   - Vul in:
     ```
     From: gemeente-platform@gmail.com
     From Display Name: Gemeente Data Platform
     Host: smtp.gmail.com
     Port: 587
     Authentication: Enabled
     Username: gemeente-platform@gmail.com
     Password: [app password]
     Enable StartTLS: Yes
     Enable SSL: No
     ```
   - Klik **Save**

3. **Test email:**
   - Users → Selecteer user
   - **Send test email** button
   - Check inbox

**Optie 2: Microsoft 365/Outlook SMTP**

```
Host: smtp.office365.com
Port: 587
Enable StartTLS: Yes
Username: platformadmin@gemeente.nl
Password: [password]
```

**Optie 3: Dedicated SMTP server**

```
Host: mail.gemeente.nl
Port: 25 (or 587)
Authentication: Yes/No (depending on config)
```

### Email Templates Aanpassen

**Keycloak email templates:**

```bash
# Kopieer default templates
docker exec gemeente_keycloak mkdir -p /opt/keycloak/themes/gemeente/email
docker cp gemeente_keycloak:/opt/keycloak/themes/base/email /tmp/email-templates

# Pas templates aan
cd /tmp/email-templates
nano html/password-reset.ftl

# Upload terug
docker cp /tmp/email-templates gemeente_keycloak:/opt/keycloak/themes/gemeente/email

# Restart Keycloak
docker-compose restart keycloak
```

**Voorbeeld custom template:**
```html
<!-- password-reset.ftl -->
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; }
        .header { background: #1e3c72; color: white; padding: 20px; }
        .button { background: #00d4ff; color: white; padding: 10px 20px; text-decoration: none; }
    </style>
</head>
<body>
    <div class="header">
        <h2>Gemeente Data Platform</h2>
    </div>
    <p>Hallo ${user.firstName},</p>
    <p>Je hebt een wachtwoord reset aangevraagd voor het Data Platform.</p>
    <p>
        <a href="${link}" class="button">Reset wachtwoord</a>
    </p>
    <p>Deze link is 5 minuten geldig.</p>
    <p>Met vriendelijke groet,<br>IT Beheer</p>
</body>
</html>
```

### SMTP Troubleshooting

**Test SMTP connectivity:**
```bash
# Test from host
telnet smtp.gmail.com 587

# Send test email
swaks --to admin@gemeente.nl \
  --from platform@gemeente.nl \
  --server smtp.gmail.com:587 \
  --auth-user gemeente-platform@gmail.com \
  --auth-password "app-password" \
  --tls
```

**Check Keycloak email logs:**
```bash
docker logs gemeente_keycloak | grep -i email
docker logs gemeente_keycloak | grep -i smtp
```

**Common issues:**
- **Authentication failed:** Wrong username/password or app password not enabled
- **Connection refused:** Wrong port or firewall blocking
- **TLS errors:** Enable/disable StartTLS or SSL
- **From address rejected:** SMTP server doesn't allow this sender

---

## 🚀 Production Deployment

### Pre-Production Checklist

**Security:**
- [ ] Switch to production passwords (`switch-environment.sh prod`)
- [ ] Enable SSL/TLS with valid certificates
- [ ] Configure firewall (allow only internal network)
- [ ] Disable unnecessary services/ports
- [ ] Enable audit logging for all services
- [ ] Configure backup retention (30+ days)
- [ ] Setup monitoring alerts
- [ ] Document disaster recovery plan
- [ ] Conduct penetration test

**Performance:**
- [ ] Configure resource limits per container
- [ ] Setup load balancing (if needed)
- [ ] Enable caching (Redis)
- [ ] Optimize database queries
- [ ] Configure connection pooling
- [ ] Monitor resource usage patterns

**Compliance:**
- [ ] GDPR compliance check
- [ ] BIO compliance check
- [ ] Data retention policy documented
- [ ] Privacy impact assessment
- [ ] Terms of service/privacy policy published
- [ ] User consent management

**Operations:**
- [ ] Automated backups configured
- [ ] Monitoring dashboards setup
- [ ] Alert notifications configured
- [ ] Incident response plan documented
- [ ] On-call schedule established
- [ ] Runbooks created

### Production-Ready Configuration

**Environment switch:**
```bash
cd /opt/gemeente-data-platform

# Generate production passwords
./scripts/switch-environment.sh prod

# Verify
cat .env | grep -E "PASSWORD|SECRET|TOKEN"

# Backup production .env
cp .env .env.production.backup
```

**Production docker-compose additions:**
```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  superset:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  postgres:
    deploy:
      resources:
        limits:
          cpus: '4'
          memory: 8G
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - /backup/postgres:/backup  # External backup mount
    command: >
      postgres
      -c shared_buffers=2GB
      -c effective_cache_size=6GB
      -c maintenance_work_mem=512MB
      -c checkpoint_completion_target=0.9
      -c wal_buffers=16MB
      -c default_statistics_target=100
      -c random_page_cost=1.1
      -c effective_io_concurrency=200
      -c work_mem=64MB
      -c min_wal_size=1GB
      -c max_wal_size=4GB
```

**Production start:**
```bash
# Start with production override
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Verify
./scripts/verify-sso-status.sh
```

### High Availability Setup

**PostgreSQL replication:**
```bash
# Primary server (current)
# Already running

# Standby server setup
docker run -d \
  --name gemeente_postgres_standby \
  --network gemeente_data_platform_dev_backend \
  -e POSTGRES_PASSWORD=gemeente123 \
  -e PGDATA=/var/lib/postgresql/data/pgdata \
  -e POSTGRES_MASTER_SERVICE_HOST=gemeente_postgres \
  -v postgres_standby_data:/var/lib/postgresql/data \
  bitnami/postgresql:14-replication

# Monitor replication
docker exec gemeente_postgres psql -U gemeente -c "SELECT * FROM pg_stat_replication;"
```

**Load Balancer (HAProxy):**
```bash
# haproxy.cfg
global
    maxconn 4096

defaults
    mode http
    timeout connect 5s
    timeout client 50s
    timeout server 50s

frontend superset_front
    bind *:80
    default_backend superset_back

backend superset_back
    balance roundrobin
    server superset1 192.168.1.25:8088 check
    server superset2 192.168.1.26:8088 check backup
```

### Monitoring & Alerting (Production)

**Prometheus alerting rules:**
```yaml
# /etc/prometheus/alert.rules.yml
groups:
  - name: gemeente_platform
    interval: 30s
    rules:
      - alert: HighCPUUsage
        expr: rate(container_cpu_usage_seconds_total[5m]) > 0.8
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.name }}"

      - alert: HighMemoryUsage
        expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.9
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High memory usage on {{ $labels.name }}"

      - alert: ServiceDown
        expr: up{job="gemeente_services"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.instance }} is down"
```

**Grafana alerts to email:**
```bash
# grafana.ini additions
[smtp]
enabled = true
host = smtp.gmail.com:587
user = platform@gemeente.nl
password = app_password
from_address = grafana@gemeente.nl
from_name = Grafana Gemeente Platform

[alerting]
enabled = true
execute_alerts = true
```

### DNS & Reverse Proxy

**Production domain setup:**
```bash
# Internal DNS (example)
data.gemeente.local     IN A    192.168.1.25
keycloak.gemeente.local IN A    192.168.1.25
superset.gemeente.local IN A    192.168.1.25
```

**Nginx reverse proxy:**
```nginx
# /etc/nginx/sites-available/gemeente-platform

upstream superset {
    server 192.168.1.25:8088 max_fails=3 fail_timeout=30s;
}

upstream keycloak {
    server 192.168.1.25:8085 max_fails=3 fail_timeout=30s;
}

server {
    listen 443 ssl http2;
    server_name data.gemeente.nl;

    ssl_certificate /etc/ssl/certs/gemeente.crt;
    ssl_certificate_key /etc/ssl/private/gemeente.key;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Superset
    location / {
        proxy_pass http://superset;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}

# Keycloak
server {
    listen 443 ssl http2;
    server_name auth.gemeente.nl;

    ssl_certificate /etc/ssl/certs/gemeente.crt;
    ssl_certificate_key /etc/ssl/private/gemeente.key;

    location / {
        proxy_pass http://keycloak;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Production Runbooks

**Incident Response:**
1. **Detect:** Alert received via monitoring
2. **Assess:** Check logs, metrics, user reports
3. **Respond:** Follow runbook for specific issue
4. **Communicate:** Notify stakeholders
5. **Resolve:** Implement fix
6. **Document:** Post-mortem analysis

**Example runbook - Database connection failures:**
```markdown
# Runbook: Database Connection Failures

## Symptoms
- Services cannot connect to PostgreSQL
- Errors: "Connection refused" or "Connection timeout"

## Diagnosis
1. Check PostgreSQL status:
   docker ps | grep postgres
   docker logs gemeente_postgres --tail 50

2. Test connectivity:
   docker exec gemeente_superset ping gemeente_postgres
   
3. Check connections:
   docker exec gemeente_postgres psql -U gemeente -c "SELECT * FROM pg_stat_activity;"

## Resolution Steps
1. If PostgreSQL is down:
   docker-compose restart postgres
   
2. If connection limit reached:
   docker exec gemeente_postgres psql -U gemeente -c "ALTER SYSTEM SET max_connections = 200;"
   docker-compose restart postgres
   
3. If network issue:
   docker network inspect gemeente_data_platform_dev_backend
   docker network connect gemeente_data_platform_dev_backend gemeente_superset

## Escalation
If issue persists >15 minutes:
- Contact: Senior DBA [phone]
- Escalate to: Infrastructure team

## Prevention
- Monitor connection usage
- Set connection pooling limits
- Regular database maintenance
```

---

## 📞 Support & Escalatie

### Support Tiers

**Tier 1: First Line (IT Helpdesk)**
- Scope: User account issues, basic troubleshooting
- Response: Within 4 business hours
- Availability: Mon-Fri 08:00-17:00

**Tier 2: Platform Support (Platform Admin)**
- Scope: Service issues, configuration, performance
- Response: Within 2 business hours
- Availability: Mon-Fri 08:00-18:00

**Tier 3: Infrastructure (DevOps/Senior Admin)**
- Scope: Infrastructure failures, security incidents
- Response: Within 1 hour (critical), 4 hours (non-critical)
- Availability: 24/7 on-call for critical

**Tier 4: Vendor Support**
- Scope: Software bugs, advanced troubleshooting
- Response: Per SLA with vendor
- Escalation: Via Tier 3

### Contact Information

**Platform Admin:**
- Name: [Naam]
- Email: [email]
- Phone: [telefoon]
- Teams: [teams channel]

**Infrastructure Team:**
- Email: infra@gemeente.nl
- Phone: [on-call nummer]
- Pager: [pager nummer]

**Emergency Contacts:**
- Critical outage: [24/7 nummer]
- Security incident: security@gemeente.nl

### Incident Severity Levels

**Severity 1 (Critical):**
- Complete platform outage
- Data breach or security incident
- Data loss
- **Response:** Immediate
- **Resolution target:** 2 hours

**Severity 2 (High):**
- Major service degradation
- Multiple users affected
- Critical feature unavailable
- **Response:** 30 minutes
- **Resolution target:** 4 hours

**Severity 3 (Medium):**
- Single service issue
- Workaround available
- Limited user impact
- **Response:** 2 hours
- **Resolution target:** 1 business day

**Severity 4 (Low):**
- Minor issue
- No user impact
- Feature request
- **Response:** 1 business day
- **Resolution target:** 5 business days

---

## 📚 Appendix

### Useful Commands Cheat Sheet

```bash
# === Docker Compose ===
docker-compose ps                # Status
docker-compose logs -f service   # Logs
docker-compose restart service   # Restart
docker-compose up -d service     # Start
docker-compose down              # Stop all

# === Container Management ===
docker exec -it container bash   # Shell access
docker logs container -f         # Logs
docker inspect container         # Details
docker stats                     # Resource usage

# === Database ===
docker exec gemeente_postgres psql -U gemeente  # SQL shell
docker exec gemeente_postgres pg_dump -U gemeente gemeente > backup.sql  # Backup

# === Monitoring ===
./scripts/verify-sso-status.sh   # Health check
docker ps --format "table {{.Names}}\t{{.Status}}"  # Container status
df -h                            # Disk usage
free -h                          # Memory usage

# === Logs ===
docker-compose logs --tail=100 superset  # Last 100 lines
docker logs gemeente_keycloak --since 1h # Last hour
journalctl -u docker -f          # Docker daemon logs

# === Cleanup ===
docker system prune -f           # Clean unused resources
docker volume prune -f           # Clean unused volumes
docker image prune -a -f         # Clean unused images
```

### Port Reference

| Port | Service | Access |
|------|---------|--------|
| 20432 | PostgreSQL | Internal |
| 20379 | Redis | Internal |
| 8081 | pgAdmin | External |
| 8085 | Keycloak | External |
| 8088 | Superset | External |
| 8082 | Airflow | External (SSO) |
| 13000 | Grafana | External (SSO) |
| 9001 | MinIO Console | External |
| 9002 | MinIO API | Internal |
| 8200 | Vault | External |
| 9080 | APISIX | Internal |
| 9000 | APISIX Dashboard | External |
| 4180 | OAuth2-Proxy | External |
| 9090 | Prometheus | Internal (via Proxy) |
| 3100 | Loki | Internal (via Proxy) |
| 7474 | Neo4j Browser | External |
| 7687 | Neo4j Bolt | Internal |
| 28080 | Spark Master UI | External |
| 27077 | Spark Master | Internal |
| 8888 | Platform Dashboard | External |

### File Locations

```
/opt/gemeente-data-platform/        # Installation root
├── .env                            # Environment variables
├── docker-compose.yml              # Main compose
├── superset_config.py              # Superset config
├── /backups/                       # Backup storage
│   ├── /postgres/                 # DB backups
│   ├── /volumes/                  # Volume backups
│   └── /configs/                  # Config backups
├── /logs/                          # Application logs
├── /scripts/                       # Utility scripts
└── /dags/                          # Airflow DAGs

/var/lib/docker/volumes/            # Docker volumes
├── gemeente_data_platform_dev_postgres_data/
├── gemeente_data_platform_dev_superset_home/
└── [other volumes]

/var/log/                           # System logs
├── /docker-cleanup.log            # Cleanup logs
├── /postgres-backup.log           # Backup logs
└── /gemeente-platform-health.log  # Health check logs
```

### Glossary

**Airflow:** Workflow orchestration platform  
**API Gateway:** Single entry point for API calls (APISIX)  
**Backup:** Copy of data for recovery purposes  
**Container:** Isolated runtime environment (Docker)  
**DAG:** Directed Acyclic Graph (Airflow workflow)  
**Docker Compose:** Tool for multi-container Docker applications  
**Keycloak:** Identity and Access Management (IAM) solution  
**Loki:** Log aggregation system  
**MinIO:** S3-compatible object storage  
**OAuth2:** Authorization framework  
**pgAdmin:** PostgreSQL administration tool  
**Prometheus:** Monitoring and alerting system  
**Realm:** Keycloak security domain  
**SSO:** Single Sign-On authentication  
**Superset:** Business Intelligence platform  
**Volume:** Persistent storage for Docker containers  

---

**Document Versie:** 2.0  
**Laatst bijgewerkt:** September 2025  
**Auteur:** Platform Team  
**Review datum:** Quarterly

*Voor vragen of feedback: platform-team@gemeente.nl*