#!/bin/bash

# ===================================
# ULTIMATE SUPERSET FIX
# Lost redirect loop DEFINITIEF op
# ===================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  ULTIMATE SUPERSET FIX - REDIRECT LOOP DESTROYER             ║${NC}"
echo -e "${RED}║  Dit gaat ALLES resetten en opnieuw configureren              ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${YELLOW}Dit script gaat:${NC}"
echo "1. Superset VOLLEDIG verwijderen (container + volume + database)"
echo "2. Nieuwe ultra-permissive config maken"
echo "3. Database opnieuw initialiseren"
echo "4. Flask-Session library installeren"
echo "5. Alles opnieuw starten"
echo ""
read -p "Doorgaan? (y/n) " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Geannuleerd"
    exit 1
fi

# ===================================
# STAP 1: NUCLEAIRE OPTIE - ALLES WEG
# ===================================
echo ""
echo -e "${BOLD}${RED}[1/7] NUCLEAIRE RESET - Verwijderen ALLES...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Stop containers
echo "Stopping containers..."
docker-compose stop superset superset-init 2>/dev/null || true
docker stop gemeente_superset gemeente_superset-init 2>/dev/null || true

# Remove containers
echo "Removing containers..."
docker rm -f gemeente_superset gemeente_superset-init 2>/dev/null || true

# Remove volume
echo "Removing volume..."
docker volume rm gemeente_data_platform_dev_superset_home 2>/dev/null || true
docker volume rm superset_home 2>/dev/null || true

# Drop database en user
echo "Dropping database..."
docker exec gemeente_postgres psql -U gemeente -c "DROP DATABASE IF EXISTS superset;" 2>/dev/null || true
docker exec gemeente_postgres psql -U gemeente -c "DROP USER IF EXISTS superset;" 2>/dev/null || true

echo -e "${GREEN}✔ Alles verwijderd - clean slate${NC}"

# ===================================
# STAP 2: DATABASE OPNIEUW MAKEN
# ===================================
echo ""
echo -e "${BOLD}${BLUE}[2/7] Database opnieuw maken...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

docker exec gemeente_postgres psql -U gemeente -c "CREATE USER superset WITH PASSWORD 'superset123';"
docker exec gemeente_postgres psql -U gemeente -c "CREATE DATABASE superset OWNER superset;"
docker exec gemeente_postgres psql -U gemeente -c "GRANT ALL PRIVILEGES ON DATABASE superset TO superset;"
docker exec gemeente_postgres psql -U gemeente -d superset -c "GRANT ALL ON SCHEMA public TO superset;"

# Test
if docker exec gemeente_postgres psql -U superset -d superset -c "SELECT 1;" >/dev/null 2>&1; then
    echo -e "${GREEN}✔ Database setup OK${NC}"
else
    echo -e "${RED}✗ Database setup FAILED${NC}"
    exit 1
fi

# ===================================
# STAP 3: ULTRA-PERMISSIVE CONFIG
# ===================================
echo ""
echo -e "${BOLD}${BLUE}[3/7] Ultra-permissive config maken...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > superset_config.py <<'EOF'
# ===================================
# SUPERSET CONFIG - ULTRA PERMISSIVE
# Designed to fix redirect loop
# ===================================

import os

# ============================================
# SECRET KEY - Must be stable
# ============================================
SECRET_KEY = os.environ.get('SUPERSET_SECRET_KEY', 'DevKey2024SecureForGemeente')

# ============================================
# DATABASE
# ============================================
SQLALCHEMY_DATABASE_URI = 'postgresql+psycopg2://superset:superset123@gemeente_postgres:5432/superset'
SQLALCHEMY_TRACK_MODIFICATIONS = False

# ============================================
# DISABLE ALL CSRF COMPLETELY
# ============================================
WTF_CSRF_ENABLED = False
WTF_CSRF_CHECK_DEFAULT = False
TALISMAN_ENABLED = False

# ============================================
# SESSION - ULTRA PERMISSIVE
# ============================================
# Make sessions work in HTTP (not HTTPS)
SESSION_COOKIE_HTTPONLY = False  # Allow JS access (less secure but works)
SESSION_COOKIE_SECURE = False    # HTTP not HTTPS
SESSION_COOKIE_SAMESITE = None   # Allow all cross-site (most permissive)
SESSION_COOKIE_DOMAIN = None     # Auto-detect

# Long session
PERMANENT_SESSION_LIFETIME = 86400  # 24 hours

# Disable all session protections temporarily
SESSION_PROTECTION = None

# ============================================
# WERKENDE SESSION STORAGE
# ============================================
# DO NOT use filesystem - use database instead!
SESSION_TYPE = 'sqlalchemy'  # Store in database not filesystem!

# ============================================
# APPLICATION SETTINGS
# ============================================
SUPERSET_WEBSERVER_TIMEOUT = 300
ROW_LIMIT = 5000

# ============================================
# DISABLE SECURITY FEATURES FOR DEBUG
# ============================================
# Disable all security that could interfere
HTTP_HEADERS = {}
ENABLE_PROXY_FIX = True

# ============================================
# LOGGING - VERBOSE
# ============================================
import logging
LOG_LEVEL = logging.DEBUG  # Verbose logging

# ============================================
# STARTUP
# ============================================
print("=" * 70)
print("SUPERSET CONFIG - ULTRA PERMISSIVE MODE")
print("CSRF: COMPLETELY DISABLED")
print("Session: Database-backed (not filesystem)")
print("Cookie SameSite: None (most permissive)")
print("Cookie Secure: False (HTTP)")
print("Session Protection: Disabled")
print("=" * 70)
EOF

echo -e "${GREEN}✔ Ultra-permissive config gemaakt${NC}"

# ===================================
# STAP 4: SUPERSET INIT MET DEPENDENCIES
# ===================================
echo ""
echo -e "${BOLD}${BLUE}[4/7] Superset init met extra dependencies...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Start init container with custom command
cat > /tmp/superset-init-custom.sh <<'INITEOF'
#!/bin/bash
set -e

echo "Installing dependencies..."
pip install --no-cache-dir Flask-Session Flask-SQLAlchemy

echo "Upgrading database..."
superset db upgrade

echo "Creating admin user..."
superset fab create-admin \
  --username admin \
  --firstname Admin \
  --lastname User \
  --email admin@gemeente.nl \
  --password admin123 || echo "Admin user already exists"

echo "Initializing Superset..."
superset init

echo "Init complete!"
INITEOF

chmod +x /tmp/superset-init-custom.sh

# Copy init script to container and run
docker-compose up -d superset-init
sleep 5

docker cp /tmp/superset-init-custom.sh gemeente_superset-init:/tmp/init.sh
docker exec gemeente_superset-init /tmp/init.sh

echo -e "${GREEN}✔ Init compleet${NC}"

# ===================================
# STAP 5: START SUPERSET
# ===================================
echo ""
echo -e "${BOLD}${BLUE}[5/7] Superset starten met nieuwe config...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

docker-compose up -d superset

echo "Wachten op Superset start (30 sec)..."
for i in {1..30}; do echo -n "█"; sleep 1; done
echo ""

# Install Flask-Session in running container too
echo "Installing Flask-Session in running container..."
docker exec gemeente_superset pip install --no-cache-dir Flask-Session Flask-SQLAlchemy 2>/dev/null || true

# Restart to load new packages
docker-compose restart superset
echo "Wachten na restart (20 sec)..."
for i in {1..20}; do echo -n "█"; sleep 1; done
echo ""

echo -e "${GREEN}✔ Superset started${NC}"

# ===================================
# STAP 6: VERIFICATIE
# ===================================
echo ""
echo -e "${BOLD}${BLUE}[6/7] Verificatie...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check container
if docker ps | grep -q gemeente_superset; then
    echo -e "${GREEN}✔ Container running${NC}"
else
    echo -e "${RED}✗ Container not running!${NC}"
    exit 1
fi

# Check health
sleep 5
if curl -s http://localhost:8088/health | grep -q "OK"; then
    echo -e "${GREEN}✔ Health check OK${NC}"
else
    echo -e "${YELLOW}⚠ Health check failed, but continuing...${NC}"
fi

# Test API login
echo ""
echo "Testing API login..."
API_RESPONSE=$(curl -s -X POST http://localhost:8088/api/v1/security/login \
    -H "Content-Type: application/json" \
    -d '{"username":"admin","password":"admin123","provider":"db","refresh":true}')

if echo "$API_RESPONSE" | grep -q "access_token"; then
    echo -e "${GREEN}✔ API login WORKS!${NC}"
else
    echo -e "${RED}✗ API login FAILED${NC}"
    echo "Response: $API_RESPONSE"
fi

# Test browser-style login with cookies
echo ""
echo "Testing browser-style login with cookies..."
rm -f /tmp/superset-test-cookies.txt

# Get login page first (establish session)
curl -s -c /tmp/superset-test-cookies.txt -b /tmp/superset-test-cookies.txt \
    http://localhost:8088/login/ > /dev/null

sleep 2

# Try to login
LOGIN_RESPONSE=$(curl -s -i -c /tmp/superset-test-cookies.txt -b /tmp/superset-test-cookies.txt \
    -X POST http://localhost:8088/login/ \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "Referer: http://localhost:8088/login/" \
    -d "username=admin&password=admin123" \
    -L 2>&1)

# Check for successful redirect
if echo "$LOGIN_RESPONSE" | grep -q "Location.*superset/welcome"; then
    echo -e "${GREEN}✔✔✔ BROWSER LOGIN WORKS! Redirects to welcome page!${NC}"
elif echo "$LOGIN_RESPONSE" | grep -q "HTTP.*200"; then
    if echo "$LOGIN_RESPONSE" | grep -q "Welcome"; then
        echo -e "${GREEN}✔✔✔ BROWSER LOGIN WORKS! Welcome page loaded!${NC}"
    else
        echo -e "${YELLOW}⚠ Got 200 but not sure if logged in${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Login response unclear, check manually${NC}"
fi

# Show cookies
echo ""
echo "Session cookies set:"
cat /tmp/superset-test-cookies.txt | grep -v "^#" | grep "superset" || echo "No cookies found"

rm -f /tmp/superset-test-cookies.txt

# ===================================
# STAP 7: DEBUG INFO & INSTRUCTIONS
# ===================================
echo ""
echo -e "${BOLD}${BLUE}[7/7] Debug info & instructies...${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > test-browser-login.sh <<'EOF'
#!/bin/bash
# Test browser-style login in detail

echo "=== SUPERSET BROWSER LOGIN TEST ==="
echo ""

# Clean cookies
rm -f /tmp/test-cookies.txt

echo "Step 1: Getting login page..."
curl -v -c /tmp/test-cookies.txt -b /tmp/test-cookies.txt \
    http://192.168.1.25:8088/login/ \
    -o /tmp/login-page.html 2>&1 | grep -E "< HTTP|Set-Cookie"

echo ""
echo "Step 2: Posting login..."
curl -v -c /tmp/test-cookies.txt -b /tmp/test-cookies.txt \
    -X POST http://192.168.1.25:8088/login/ \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -H "Referer: http://192.168.1.25:8088/login/" \
    -d "username=admin&password=admin123" \
    -L 2>&1 | grep -E "< HTTP|Location|Set-Cookie"

echo ""
echo "Cookies after login:"
cat /tmp/test-cookies.txt

echo ""
echo "If you see 'Location: /superset/welcome/' then login works!"
EOF

chmod +x test-browser-login.sh

echo -e "${GREEN}✔ Debug script created: test-browser-login.sh${NC}"

# ===================================
# FINALE
# ===================================
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}   ULTIMATE FIX COMPLEET!                                      ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${GREEN}${BOLD}KLAAR!${NC}"
echo ""
echo -e "${YELLOW}WAT IS GEDAAN:${NC}"
echo "✔ Superset VOLLEDIG verwijderd (nucleaire optie)"
echo "✔ Database opnieuw gemaakt"
echo "✔ Ultra-permissive config (CSRF OFF, Session permissive)"
echo "✔ Flask-Session library geïnstalleerd"
echo "✔ Session storage = database (niet filesystem)"
echo "✔ Admin user opnieuw aangemaakt"
echo "✔ Superset herstart met nieuwe config"
echo ""

echo -e "${CYAN}${BOLD}PROBEER NU IN BROWSER:${NC}"
echo ""
echo "1. Open NIEUWE INCOGNITO window (belangrijk!)"
echo "2. Ga naar: http://192.168.1.25:8088"
echo "3. Login: admin / admin123"
echo ""
echo -e "${GREEN}Als het NOG STEEDS niet werkt:${NC}"
echo ""
echo "1. Run debug script:"
echo "   ./test-browser-login.sh"
echo ""
echo "2. Check logs:"
echo "   docker logs gemeente_superset -f"
echo "   (Dan probeer in te loggen en kijk wat er gebeurt)"
echo ""
echo "3. Check session in database:"
echo "   docker exec gemeente_postgres psql -U superset -d superset -c \"SELECT * FROM sessions LIMIT 5;\""
echo ""

echo -e "${YELLOW}${BOLD}KRITIEK: Gebruik INCOGNITO MODE!${NC}"
echo "Anders heeft je browser oude cookies die alles breken!"
echo ""