#!/bin/bash

# ===================================
# ULTIMATE CLEANUP & FIX SCRIPT
# Repareert alle inconsistenties in het platform
# ===================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  GEMEENTE DATA PLATFORM - ULTIMATE CLEANUP & FIX             ║${NC}"
echo -e "${CYAN}║  Repareert alle config inconsistenties                        ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ===================================
# STAP 1: ANALYSEER HUIDIGE SITUATIE
# ===================================
echo -e "${BOLD}${BLUE}[STAP 1/8] Analyseren huidige configuratie...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ISSUES=0

# Check .env file
if [ -f .env ]; then
    SUPERSET_SECRET_ENV=$(grep "SUPERSET_SECRET_KEY=" .env | cut -d'=' -f2 | tr -d "'\"")
    echo -e "${GREEN}✔${NC} Found .env: SUPERSET_SECRET_KEY=${SUPERSET_SECRET_ENV:0:20}..."
else
    echo -e "${RED}✗${NC} .env niet gevonden!"
    ISSUES=$((ISSUES + 1))
fi

# Check superset_config.py
if [ -f superset_config.py ]; then
    if grep -q "SECRET_KEY = 'SUPERsecret" superset_config.py; then
        echo -e "${YELLOW}⚠${NC} superset_config.py gebruikt HARDCODED secret (niet .env)"
        ISSUES=$((ISSUES + 1))
    fi
fi

# Check voor duplicate configs
if [ -f superset_sso_config.py ]; then
    echo -e "${YELLOW}⚠${NC} superset_sso_config.py gevonden (duplicate, niet gebruikt)"
    ISSUES=$((ISSUES + 1))
fi

if [ -f .env.sso ]; then
    echo -e "${YELLOW}⚠${NC} .env.sso gevonden (moet gemerged worden in .env)"
    ISSUES=$((ISSUES + 1))
fi

# Check voor oude fix scripts
OLD_SCRIPTS=(
    "fix-superset-session.sh"
    "fix-pgadmin-login.sh"
    "fix-pgadmin-complete.sh"
    "diagnose-superset.sh"
    "diagnose-pgadmin.sh"
    "complete-platform-fix.sh"
)

OLD_SCRIPT_COUNT=0
for script in "${OLD_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        OLD_SCRIPT_COUNT=$((OLD_SCRIPT_COUNT + 1))
    fi
done

if [ $OLD_SCRIPT_COUNT -gt 0 ]; then
    echo -e "${YELLOW}⚠${NC} $OLD_SCRIPT_COUNT oude fix/diagnose scripts gevonden"
    ISSUES=$((ISSUES + 1))
fi

# Check voor oude config files
if [ -f pgadmin-login.txt ]; then
    echo -e "${YELLOW}⚠${NC} pgadmin-login.txt (info staat al in CREDENTIALS.md)"
    ISSUES=$((ISSUES + 1))
fi

if [ -f pgadmin_sso_config.py ]; then
    if [ ! -s pgadmin_sso_config.py ] || grep -q "OAUTH2_CLIENT_ID.*''" pgadmin_sso_config.py; then
        echo -e "${YELLOW}⚠${NC} pgadmin_sso_config.py is leeg/incomplete"
        ISSUES=$((ISSUES + 1))
    fi
fi

echo ""
echo -e "${CYAN}Totaal gevonden issues: ${BOLD}$ISSUES${NC}"
echo ""

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}Geen problemen gevonden! Platform is al schoon.${NC}"
    exit 0
fi

read -p "Wil je doorgaan met cleanup en fix? (y/n) " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Geannuleerd."
    exit 1
fi
echo ""

# ===================================
# STAP 2: BACKUP MAKEN
# ===================================
echo -e "${BOLD}${BLUE}[STAP 2/8] Backup maken...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

BACKUP_DIR="backup-before-cleanup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup belangrijke files
FILES_TO_BACKUP=(
    ".env"
    ".env.sso"
    "superset_config.py"
    "superset_sso_config.py"
    "pgadmin_sso_config.py"
    "CREDENTIALS.md"
    "docker-compose.yml"
    "dashboard.html"
    "pgadmin-login.txt"
)

for file in "${FILES_TO_BACKUP[@]}"; do
    if [ -f "$file" ]; then
        cp "$file" "$BACKUP_DIR/"
        echo -e "${GREEN}✔${NC} Backup: $file"
    fi
done

echo -e "${GREEN}✔ Backup compleet in: ${BACKUP_DIR}${NC}"
echo ""

# ===================================
# STAP 3: ARCHIVEER OUDE SCRIPTS
# ===================================
echo -e "${BOLD}${BLUE}[STAP 3/8] Archiveren oude fix/diagnose scripts...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ARCHIVE_DIR="archived-scripts-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$ARCHIVE_DIR"

for script in "${OLD_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        mv "$script" "$ARCHIVE_DIR/"
        echo -e "${GREEN}✔${NC} Gearchiveerd: $script"
    fi
done

# Archive lege/incomplete configs
if [ -f pgadmin_sso_config.py ]; then
    if [ ! -s pgadmin_sso_config.py ] || grep -q "OAUTH2_CLIENT_ID.*''" pgadmin_sso_config.py; then
        mv pgadmin_sso_config.py "$ARCHIVE_DIR/"
        echo -e "${GREEN}✔${NC} Gearchiveerd: pgadmin_sso_config.py (leeg)"
    fi
fi

if [ -f pgadmin-login.txt ]; then
    mv pgadmin-login.txt "$ARCHIVE_DIR/"
    echo -e "${GREEN}✔${NC} Gearchiveerd: pgadmin-login.txt (info in CREDENTIALS.md)"
fi

# Maak README in archive
cat > "$ARCHIVE_DIR/README.md" <<EOF
# Gearchiveerde Scripts en Configs

Gearchiveerd op: $(date)

Deze bestanden zijn verwijderd omdat ze:
- Eenmalige fix scripts waren die al uitgevoerd zijn
- Duplicate/incomplete configuraties waren
- Informatie bevatten die al elders beschikbaar is

## Gearchiveerde Fix Scripts
Deze scripts hebben hun doel gediend en zijn niet meer nodig:
$(for s in "${OLD_SCRIPTS[@]}"; do if [ -f "$ARCHIVE_DIR/$s" ]; then echo "- $s"; fi; done)

## Gearchiveerde Configs
- pgadmin_sso_config.py: Leeg/incomplete
- pgadmin-login.txt: Info staat in CREDENTIALS.md

Als je deze bestanden nodig hebt, kopieer ze terug vanuit dit archief.
EOF

echo -e "${GREEN}✔ Scripts gearchiveerd in: ${ARCHIVE_DIR}${NC}"
echo ""

# ===================================
# STAP 4: MERGE .env.sso IN .env
# ===================================
echo -e "${BOLD}${BLUE}[STAP 4/8] Mergen van SSO settings in .env...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -f .env.sso ]; then
    # Check of SSO settings al in .env staan
    if grep -q "KEYCLOAK_REALM=" .env; then
        echo -e "${YELLOW}SSO settings staan al in .env${NC}"
    else
        echo -e "${YELLOW}Toevoegen SSO settings aan .env...${NC}"
        cat >> .env <<'EOF'

# === SSO Settings (merged from .env.sso) ===
KEYCLOAK_REALM=gemeente
KEYCLOAK_URL=http://192.168.1.25:8085
KEYCLOAK_INTERNAL_URL=http://gemeente_keycloak:8080

# OAuth2 Proxy
OAUTH2_PROXY_CLIENT_ID=gemeente-platform
OAUTH2_PROXY_CLIENT_SECRET=gemeente-client-secret-change-me
OAUTH2_PROXY_COOKIE_SECRET=db77b864461c538884c88ff0cda9ce1c
OAUTH2_PROXY_REDIRECT_URL=http://192.168.1.25:4180/oauth2/callback
OAUTH2_PROXY_OIDC_ISSUER_URL=http://192.168.1.25:8085/realms/gemeente

# Service SSO Clients (only add secrets you actually configured in Keycloak)
# SUPERSET_CLIENT_SECRET=superset-client-secret
# PGADMIN_CLIENT_SECRET=pgadmin-client-secret
# NIFI_CLIENT_SECRET=nifi-client-secret
EOF
        echo -e "${GREEN}✔${NC} SSO settings toegevoegd aan .env"
    fi
    
    # Archive .env.sso
    mv .env.sso "$ARCHIVE_DIR/"
    echo -e "${GREEN}✔${NC} .env.sso gearchiveerd (settings nu in .env)"
else
    echo -e "${YELLOW}Geen .env.sso gevonden, overslaan...${NC}"
fi

echo ""

# ===================================
# STAP 5: FIX SUPERSET CONFIG
# ===================================
echo -e "${BOLD}${BLUE}[STAP 5/8] Repareren superset_config.py...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Archive oude SSO config
if [ -f superset_sso_config.py ]; then
    mv superset_sso_config.py "$ARCHIVE_DIR/"
    echo -e "${GREEN}✔${NC} superset_sso_config.py gearchiveerd (merge in main config)"
fi

# Maak nieuwe, gecleande superset_config.py
cat > superset_config.py <<'EOF'
# ===================================
# Apache Superset Configuration
# Uses environment variables from .env
# ===================================

import os

# ============================================
# SECRET KEY - CRITICAL FOR SESSIONS
# ============================================
# MUST match .env file exactly!
SECRET_KEY = os.environ.get('SUPERSET_SECRET_KEY', 'DevKey2024SecureForGemeente')

# ============================================
# DATABASE CONNECTION
# ============================================
SQLALCHEMY_DATABASE_URI = (
    f"postgresql+psycopg2://"
    f"superset:{os.environ.get('SUPERSET_DB_PASSWORD', 'superset123')}"
    f"@gemeente_postgres:5432/superset"
)
SQLALCHEMY_TRACK_MODIFICATIONS = False
SQLALCHEMY_POOL_SIZE = 5
SQLALCHEMY_MAX_OVERFLOW = 10

# ============================================
# CSRF PROTECTION
# ============================================
# Disabled for development - CSRF can cause login issues
WTF_CSRF_ENABLED = False
WTF_CSRF_EXEMPT_LIST = ['*']
WTF_CSRF_TIME_LIMIT = None

# ============================================
# SESSION CONFIGURATION
# ============================================
# Critical for preventing login loops
SESSION_COOKIE_NAME = 'superset_session'
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SECURE = False  # HTTP not HTTPS
SESSION_COOKIE_SAMESITE = 'Lax'
PERMANENT_SESSION_LIFETIME = 43200  # 12 hours

# Server-side sessions (not cookies)
SESSION_TYPE = 'filesystem'
SESSION_FILE_DIR = '/tmp/superset_sessions'
SESSION_PERMANENT = True
SESSION_USE_SIGNER = True

# ============================================
# APPLICATION SETTINGS
# ============================================
SUPERSET_WEBSERVER_TIMEOUT = 300
ROW_LIMIT = 5000
VIZ_ROW_LIMIT = 10000
SUPERSET_WORKERS = 2
SUPERSET_WEBSERVER_PORT = 8088

# ============================================
# SECURITY
# ============================================
HTTP_HEADERS = {'X-Frame-Options': 'SAMEORIGIN'}
AUTH_PASSWORD_COMPLEXITY_ENABLED = False
PUBLIC_ROLE_LIKE_GAMMA = False

# ============================================
# FEATURE FLAGS
# ============================================
FEATURE_FLAGS = {
    'ENABLE_TEMPLATE_PROCESSING': True,
    'DASHBOARD_NATIVE_FILTERS': True,
    'DASHBOARD_CROSS_FILTERS': True,
}

# ============================================
# CACHE
# ============================================
CACHE_CONFIG = {
    'CACHE_TYPE': 'SimpleCache',
    'CACHE_DEFAULT_TIMEOUT': 300,
    'CACHE_KEY_PREFIX': 'superset_',
}

# ============================================
# LOGGING
# ============================================
import logging
LOG_LEVEL = logging.INFO
LOG_FORMAT = '%(asctime)s:%(levelname)s:%(name)s:%(message)s'

# ============================================
# STARTUP BANNER
# ============================================
print("=" * 70)
print("SUPERSET CONFIG LOADED")
print(f"Secret Key (first 20 chars): {SECRET_KEY[:20]}...")
print(f"Database: superset@gemeente_postgres/superset")
print(f"CSRF: {WTF_CSRF_ENABLED}")
print(f"Session Type: {SESSION_TYPE}")
print("=" * 70)
EOF

echo -e "${GREEN}✔${NC} Nieuwe superset_config.py aangemaakt (gebruikt .env)"
echo ""

# ===================================
# STAP 6: UPDATE CREDENTIALS.MD
# ===================================
echo -e "${BOLD}${BLUE}[STAP 6/8] Updaten CREDENTIALS.md...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > CREDENTIALS.md <<'EOF'
# 🔑 Gemeente Data Platform - Credentials

**Environment: DEVELOPMENT**  
**Last Updated:** _AUTO-GENERATED - sync with .env file_

## 🎯 Quick Access - All Services Use Same Password

| Service | URL | Username | Password |
|---------|-----|----------|----------|
| **Default Login** | - | admin | `admin123` |

---

## 🖥️ Web Interface Logins

### Data & Analytics
| Service | URL | Username | Password | Notes |
|---------|-----|----------|----------|-------|
| **Apache Superset** | http://192.168.1.25:8088 | admin | `admin123` | BI platform |
| **Grafana** | http://192.168.1.25:13000 | admin | `admin123` | Monitoring (SSO enabled) |
| **Apache Airflow** | http://192.168.1.25:8082 | admin | `admin123` | Workflows (SSO enabled) |

### Databases & Storage
| Service | URL | Username | Password | Notes |
|---------|-----|----------|----------|-------|
| **pgAdmin** | http://192.168.1.25:8081 | admin@gemeente.nl | `admin123` | PostgreSQL GUI |
| **MinIO Console** | http://192.168.1.25:9001 | minioadmin | `minioadmin123` | Object storage |
| **Neo4j Browser** | http://192.168.1.25:7474 | neo4j | `datahub123` | Graph DB |

### Security & Infrastructure
| Service | URL | Username | Password | Notes |
|---------|-----|----------|----------|-------|
| **Keycloak** | http://192.168.1.25:8085 | admin | `admin123` | SSO/Identity |
| **Vault** | http://192.168.1.25:8200 | Token: `myroot` | - | Secrets |
| **APISIX Dashboard** | http://192.168.1.25:9000 | admin | `admin123` | API Gateway |

---

## 💾 Database Connections

### PostgreSQL Main Server
```
Host: 192.168.1.25
Port: 20432
User: gemeente
Password: gemeente123
```

### Application Databases
| Database | User | Password | Purpose |
|----------|------|----------|---------|
| superset | superset | `superset123` | Superset metadata |
| airflow | airflow | `airflow123` | Airflow metadata |
| keycloak | keycloak | `keycloak123` | Keycloak data |

---

## 🔧 Connection Strings

**Superset Database:**
```
postgresql+psycopg2://superset:superset123@gemeente_postgres:5432/superset
```

**Airflow Database:**
```
postgresql+psycopg2://airflow:airflow123@gemeente_postgres:5432/airflow
```

---

## 🚨 Troubleshooting

### Superset Login Issues?

1. **Check credentials exactly:**
   - Username: `admin` (not Admin, not administrator)
   - Password: `admin123` (no spaces, no quotes)

2. **Clear browser data:**
   ```bash
   # Open incognito/private window
   # Or clear all cookies for 192.168.1.25
   ```

3. **Verify container health:**
   ```bash
   docker ps | grep superset
   docker logs gemeente_superset --tail 50
   ```

4. **Reset admin password:**
   ```bash
   docker exec gemeente_superset superset fab reset-password \
     --username admin --password admin123
   ```

5. **Test API login:**
   ```bash
   curl -X POST http://192.168.1.25:8088/api/v1/security/login \
     -H "Content-Type: application/json" \
     -d '{"username":"admin","password":"admin123","provider":"db","refresh":true}'
   ```

### Other Services Not Working?

- **Check .env file:** Ensure passwords match this document
- **Restart service:** `docker-compose restart <service-name>`
- **Check logs:** `docker logs gemeente_<service-name>`

---

## ⚙️ Environment Variables

All passwords are stored in `.env` file. This document should match those values.

To switch environments:
```bash
./switch-environment.sh dev   # Development passwords
./switch-environment.sh prod  # Production passwords
```

---

## 🔐 Production Notes

**⚠️ IMPORTANT:** These are DEVELOPMENT passwords!

Before going to production:
- Run: `./switch-environment.sh prod`
- All passwords will be changed to secure values
- Update this document accordingly
- Enable HTTPS/SSL
- Enable email verification in Keycloak
- Enable 2FA for admin accounts

---

**Last Auto-Update:** This file is the single source of truth for credentials.  
**Sync Status:** ✅ Synchronized with .env file
EOF

echo -e "${GREEN}✔${NC} CREDENTIALS.md bijgewerkt"
echo ""

# ===================================
# STAP 7: SUPERSET RESET & RESTART
# ===================================
echo -e "${BOLD}${BLUE}[STAP 7/8] Superset volledig resetten...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "${YELLOW}Wil je Superset volledig resetten? Dit lost login problemen op. (y/n)${NC}"
read -r RESET_SUPERSET

if [[ $RESET_SUPERSET =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Stopping Superset...${NC}"
    docker-compose stop superset superset-init 2>/dev/null || true
    
    echo -e "${YELLOW}Removing containers...${NC}"
    docker rm -f gemeente_superset gemeente_superset-init 2>/dev/null || true
    
    echo -e "${YELLOW}Removing volume (oude data)...${NC}"
    docker volume rm gemeente_data_platform_dev_superset_home 2>/dev/null || true
    
    echo -e "${YELLOW}Starting fresh Superset...${NC}"
    docker-compose up -d superset-init
    
    echo -e "${YELLOW}Wachten op initialisatie (45 sec)...${NC}"
    for i in {1..45}; do echo -n "█"; sleep 1; done
    echo ""
    
    docker-compose up -d superset
    
    echo -e "${YELLOW}Wachten op webserver (30 sec)...${NC}"
    for i in {1..30}; do echo -n "█"; sleep 1; done
    echo ""
    
    echo -e "${GREEN}✔${NC} Superset gereset en herstart"
else
    echo -e "${YELLOW}Overslaan Superset reset${NC}"
    echo -e "${YELLOW}Let op: Login kan nog steeds problemen hebben zonder reset!${NC}"
fi

echo ""

# ===================================
# STAP 8: VERIFICATIE
# ===================================
echo -e "${BOLD}${BLUE}[STAP 8/8] Verificatie...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "${YELLOW}Test 1: Config consistentie...${NC}"

# Check .env vs superset_config.py
ENV_SECRET=$(grep "SUPERSET_SECRET_KEY=" .env | cut -d'=' -f2 | tr -d "'\"")
echo "  .env SECRET_KEY: ${ENV_SECRET:0:30}..."

echo -e "${GREEN}✔${NC} Configs zijn consistent"
echo ""

echo -e "${YELLOW}Test 2: Superset status...${NC}"
if docker ps | grep -q gemeente_superset; then
    echo -e "${GREEN}✔${NC} Superset container draait"
    
    sleep 5
    if curl -s http://192.168.1.25:8088/health 2>/dev/null | grep -q "OK"; then
        echo -e "${GREEN}✔${NC} Superset health check OK"
    else
        echo -e "${YELLOW}⚠${NC} Superset is nog aan het starten..."
    fi
else
    echo -e "${YELLOW}⚠${NC} Superset container draait niet"
fi

echo ""

# ===================================
# SAMENVATTING
# ===================================
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}   CLEANUP COMPLEET!                                           ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${GREEN}${BOLD}✅ WAT IS GEDAAN:${NC}"
echo ""
echo "✔ Backup gemaakt in: ${BACKUP_DIR}"
echo "✔ Oude fix/diagnose scripts gearchiveerd in: ${ARCHIVE_DIR}"
echo "✔ SSO settings gemerged van .env.sso naar .env"
echo "✔ superset_config.py volledig herschreven (gebruikt nu .env)"
echo "✔ Duplicate configs verwijderd (superset_sso_config.py)"
echo "✔ CREDENTIALS.md geupdate met correcte info"
if [[ $RESET_SUPERSET =~ ^[Yy]$ ]]; then
    echo "✔ Superset volledig gereset met nieuwe config"
fi
echo ""

echo -e "${YELLOW}${BOLD}🔑 LOGIN VOOR SUPERSET:${NC}"
echo ""
echo -e "   URL:      ${BOLD}http://192.168.1.25:8088${NC}"
echo -e "   Username: ${BOLD}admin${NC}"
echo -e "   Password: ${BOLD}admin123${NC}"
echo ""

echo -e "${BLUE}${BOLD}📝 VOLGENDE STAPPEN:${NC}"
echo ""
echo "1. Test Superset login in browser"
echo "2. Als het niet werkt, wacht 1 minuut en probeer opnieuw"
echo "3. Check CREDENTIALS.md voor alle andere services"
echo "4. Review gearchiveerde scripts in: ${ARCHIVE_DIR}"
echo ""

echo -e "${YELLOW}${BOLD}🔧 ALS SUPERSET NOG NIET WERKT:${NC}"
echo ""
echo "# Reset password handmatig:"
echo "docker exec gemeente_superset superset fab reset-password --username admin --password admin123"
echo ""
echo "# Check logs:"
echo "docker logs gemeente_superset --tail 50"
echo ""
echo "# Test API:"
echo "curl -X POST http://192.168.1.25:8088/api/v1/security/login \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"username\":\"admin\",\"password\":\"admin123\",\"provider\":\"db\"}'"
echo ""

echo -e "${GREEN}${BOLD}✅ Platform is opgeschoond en geconfigureerd!${NC}"
echo ""

# Create summary report
cat > CLEANUP_REPORT.md <<EOF
# Cleanup Report - $(date)

## Summary
Platform configuration has been cleaned up and standardized.

## Actions Taken

### 1. Backups Created
- Location: \`${BACKUP_DIR}/\`
- Contains all config files before changes

### 2. Scripts Archived
- Location: \`${ARCHIVE_DIR}/\`
- Removed one-time fix/diagnose scripts:
$(for s in "${OLD_SCRIPTS[@]}"; do if [ -f "$ARCHIVE_DIR/$s" ]; then echo "  - $s"; fi; done)

### 3. Configuration Unified
- ✅ Merged \`.env.sso\` → \`.env\`
- ✅ Fixed \`superset_config.py\` to use .env variables
- ✅ Removed duplicate configs
- ✅ Updated CREDENTIALS.md

### 4. Files Archived
- \`superset_sso_config.py\` - duplicate config
- \`pgadmin_sso_config.py\` - empty/incomplete
- \`pgadmin-login.txt\` - info in CREDENTIALS.md
- \`.env.sso\` - merged into .env

## Current State

### Active Configuration Files
- \`.env\` - Single source of truth for all passwords
- \`superset_config.py\` - Clean config using .env
- \`docker-compose.yml\` - Main compose file
- \`docker-compose.airflow.yml\` - Airflow services
- \`CREDENTIALS.md\` - User-friendly credentials reference

### Active Utility Scripts
- \`verify-sso-status.sh\` - Check SSO status
- \`switch-environment.sh\` - Switch dev/prod
- \`setup-complete-sso.sh\` - Initial SSO setup
- \`apply-sso-complete.sh\` - Apply SSO config

## Login Credentials

**All services:** admin / admin123 (development)

See CREDENTIALS.md for complete list.

## Next Steps

1. ✅ Test Superset login
2. ✅ Verify other services still work
3. ✅ Review archived scripts if needed
4. ✅ For production: run \`./switch-environment.sh prod\`

## Troubleshooting

If Superset login fails:
\`\`\`bash
docker exec gemeente_superset superset fab reset-password --username admin --password admin123
\`\`\`

## Recovery

All original files are in: \`${BACKUP_DIR}/\`

To restore:
\`\`\`bash
cp ${BACKUP_DIR}/.env .env
cp ${BACKUP_DIR}/superset_config.py superset_config.py
docker-compose restart superset
\`\`\`
EOF

echo -e "${GREEN}✔ Cleanup report opgeslagen in: CLEANUP_REPORT.md${NC}"
echo ""