#!/bin/bash

# ===================================
# Environment Switcher voor Gemeente Data Platform
# Switch tussen development en production passwords
# ===================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}====================================${NC}"
    echo -e "${BLUE}  Environment Password Switcher${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo ""
}

switch_to_dev() {
    echo -e "${YELLOW}Switching to DEVELOPMENT passwords...${NC}"
    
    cat > .env << 'EOF'
# ===================================
# Gemeente Data Platform - DEVELOPMENT Environment
# ⚠️ NIET GEBRUIKEN VOOR PRODUCTIE!
# ===================================

# === Database Configuration ===
POSTGRES_PASSWORD=gemeente123
PGADMIN_DEFAULT_PASSWORD=admin123

# Separate database passwords
AIRFLOW_DB_PASSWORD=airflow123
KEYCLOAK_DB_PASSWORD=keycloak123
SUPERSET_DB_PASSWORD=superset123
DATAHUB_DB_PASSWORD=datahub123

# === Storage Configuration ===
MINIO_ROOT_PASSWORD=minioadmin123

# === Security & Identity ===
KEYCLOAK_ADMIN_PASSWORD=admin123
VAULT_ROOT_TOKEN=myroot
NEO4J_PASSWORD=datahub123

# === Application Passwords ===
NIFI_ADMIN_PASSWORD=adminadmin
AIRFLOW_ADMIN_PASSWORD=admin123
AIRFLOW_FERNET_KEY='Zv8-bGq6UQ_B0K8eQf7WEjPfzKXyUJrSCxP9vXzjZIs='
SUPERSET_ADMIN_PASSWORD=admin123
SUPERSET_SECRET_KEY='dev-secret-key-not-for-production-use'
GRAFANA_ADMIN_PASSWORD=admin123

# === API Configuration ===
APISIX_ADMIN_KEY=admin-key-dev

# === Additional Settings ===
COMPOSE_PROJECT_NAME=gemeente_data_platform_dev
TZ=Europe/Amsterdam
EOF

    echo -e "${GREEN}✓ Switched to DEVELOPMENT environment${NC}"
    echo -e "${YELLOW}⚠️  Waarschuwing: Gebruik deze passwords ALLEEN voor development!${NC}"
    echo ""
    echo "Development credentials:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Default username: admin"
    echo "Default password: admin123 (of {service}123)"
    echo ""
}

switch_to_prod() {
    echo -e "${BLUE}Switching to PRODUCTION passwords...${NC}"
    
    # Check if production env backup exists
    if [ -f ".env.production" ]; then
        cp .env.production .env
        echo -e "${GREEN}✓ Restored production environment from .env.production${NC}"
    else
        echo -e "${YELLOW}Creating new production environment...${NC}"
        
        # Generate secure passwords
        generate_password() {
            openssl rand -base64 12 | tr -d "=+/" | cut -c1-16
        }
        
        cat > .env << EOF
# ===================================
# Gemeente Data Platform - PRODUCTION Environment
# Generated: $(date)
# ===================================

# === Database Configuration ===
POSTGRES_PASSWORD=Gemeente@DB2024!Secure
PGADMIN_DEFAULT_PASSWORD=PgAdmin@Gemeente2024!

# Separate database passwords
AIRFLOW_DB_PASSWORD=Airflow@DB2024!Flow
KEYCLOAK_DB_PASSWORD=Keycloak@DB2024!Auth
SUPERSET_DB_PASSWORD=Superset@DB2024!Viz
DATAHUB_DB_PASSWORD=DataHub@DB2024!Hub

# === Storage Configuration ===
MINIO_ROOT_PASSWORD=MinIO@Storage2024!Safe

# === Security & Identity ===
KEYCLOAK_ADMIN_PASSWORD=Keycloak@Admin2024!
VAULT_ROOT_TOKEN=vault-gemeente-$(generate_password)
NEO4J_PASSWORD=Neo4j@Graph2024!

# === Application Passwords ===
NIFI_ADMIN_PASSWORD=NiFi@Admin2024!Flow
AIRFLOW_ADMIN_PASSWORD=Airflow@Admin2024!
AIRFLOW_FERNET_KEY='$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())" 2>/dev/null || echo "Zv8-bGq6UQ_B0K8eQf7WEjPfzKXyUJrSCxP9vXzjZIs=")'
SUPERSET_ADMIN_PASSWORD=Superset@Admin2024!
SUPERSET_SECRET_KEY='$(generate_password)-$(generate_password)-$(generate_password)'
GRAFANA_ADMIN_PASSWORD=Grafana@Monitor2024!

# === API Configuration ===
APISIX_ADMIN_KEY=apisix-gemeente-$(generate_password)

# === Additional Settings ===
COMPOSE_PROJECT_NAME=gemeente_data_platform
TZ=Europe/Amsterdam
EOF
        
        # Backup production env
        cp .env .env.production
        echo -e "${GREEN}✓ Created production environment${NC}"
        echo -e "${GREEN}✓ Backup saved to .env.production${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}Production environment active${NC}"
    echo -e "${YELLOW}⚠️  Bewaar je credentials veilig!${NC}"
    echo ""
}

show_current() {
    if [ ! -f ".env" ]; then
        echo -e "${RED}No .env file found!${NC}"
        return 1
    fi
    
    if grep -q "gemeente123" .env 2>/dev/null; then
        echo -e "${YELLOW}Current environment: DEVELOPMENT${NC}"
        echo "Simple passwords are active (admin123, etc.)"
    else
        echo -e "${GREEN}Current environment: PRODUCTION${NC}"
        echo "Secure passwords are active"
    fi
    
    echo ""
    echo "Services status:"
    docker-compose ps --services 2>/dev/null | head -5 || echo "No services running"
}

backup_current() {
    if [ ! -f ".env" ]; then
        echo -e "${RED}No .env file to backup!${NC}"
        return 1
    fi
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_file=".env.backup.${timestamp}"
    cp .env "$backup_file"
    echo -e "${GREEN}✓ Current .env backed up to: $backup_file${NC}"
}

print_header

case "${1:-}" in
    dev|development)
        backup_current
        switch_to_dev
        ;;
    prod|production)
        backup_current
        switch_to_prod
        ;;
    status|current)
        show_current
        ;;
    backup)
        backup_current
        ;;
    *)
        echo "Usage: $0 {dev|prod|status|backup}"
        echo ""
        echo "Commands:"
        echo "  dev    - Switch to development passwords (simple)"
        echo "  prod   - Switch to production passwords (secure)"
        echo "  status - Show current environment"
        echo "  backup - Backup current .env file"
        echo ""
        show_current
        echo ""
        echo "Example:"
        echo "  $0 dev    # For local development"
        echo "  $0 prod   # For production deployment"
        ;;
esac
