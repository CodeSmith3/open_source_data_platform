#!/bin/bash

# ===================================
# Complete SSO Setup voor Gemeente Data Platform
# Configureert Keycloak SSO voor ALLE ondersteunde services
# ===================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
KEYCLOAK_URL="http://192.168.1.25:8085"
REALM_NAME="gemeente"
ADMIN_USER="admin"
ADMIN_PASS="${1:-admin123}"
SERVER_IP="192.168.1.25"

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Complete SSO Configuration Setup${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

wait_for_keycloak() {
    echo -e "${YELLOW}Waiting for Keycloak to be ready...${NC}"
    while ! curl -s "${KEYCLOAK_URL}/health/ready" | grep -q "UP"; do
        echo -n "."
        sleep 2
    done
    echo -e "\n${GREEN}✔ Keycloak is ready${NC}"
}

get_admin_token() {
    echo -e "${YELLOW}Getting admin token...${NC}"
    TOKEN=$(curl -s -X POST "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=${ADMIN_USER}" \
        -d "password=${ADMIN_PASS}" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" | jq -r '.access_token')
    
    if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
        echo -e "${RED}Failed to get admin token. Check credentials.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✔ Admin token obtained${NC}"
}

create_realm() {
    echo -e "${YELLOW}Creating gemeente realm...${NC}"
    
    REALM_JSON=$(cat <<EOF
{
    "realm": "${REALM_NAME}",
    "enabled": true,
    "displayName": "Gemeente Data Platform",
    "displayNameHtml": "<b>Gemeente Data Platform</b>",
    "registrationAllowed": true,
    "registrationEmailAsUsername": false,
    "editUsernameAllowed": true,
    "resetPasswordAllowed": true,
    "rememberMe": true,
    "verifyEmail": false,
    "loginTheme": "keycloak",
    "accessTokenLifespan": 3600,
    "ssoSessionIdleTimeout": 1800,
    "ssoSessionMaxLifespan": 36000,
    "bruteForceProtected": true,
    "permanentLockout": false,
    "maxFailureWaitSeconds": 900,
    "minimumQuickLoginWaitSeconds": 60,
    "waitIncrementSeconds": 60,
    "quickLoginCheckMilliSeconds": 1000,
    "maxDeltaTimeSeconds": 43200,
    "failureFactor": 5,
    "defaultRoles": ["user"],
    "requiredCredentials": ["password"],
    "passwordPolicy": "length(8)",
    "smtpServer": {},
    "eventsEnabled": true,
    "eventsListeners": ["jboss-logging"],
    "enabledEventTypes": ["LOGIN", "LOGIN_ERROR", "LOGOUT", "REGISTER"],
    "adminEventsEnabled": true,
    "adminEventsDetailsEnabled": true,
    "internationalizationEnabled": true,
    "supportedLocales": ["en", "nl"],
    "defaultLocale": "nl"
}
EOF
)

    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${KEYCLOAK_URL}/admin/realms" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${REALM_JSON}")
    
    if [ "$RESPONSE" == "201" ] || [ "$RESPONSE" == "409" ]; then
        echo -e "${GREEN}✔ Realm '${REALM_NAME}' configured${NC}"
    else
        echo -e "${RED}Failed to create realm (HTTP ${RESPONSE})${NC}"
    fi
}

create_client() {
    local CLIENT_ID=$1
    local CLIENT_SECRET=$2
    local REDIRECT_URIS=$3
    local DESCRIPTION=$4
    local PUBLIC_CLIENT=${5:-false}
    
    echo -e "${YELLOW}Creating client: ${CLIENT_ID}...${NC}"
    
    CLIENT_JSON=$(cat <<EOF
{
    "clientId": "${CLIENT_ID}",
    "name": "${CLIENT_ID}",
    "description": "${DESCRIPTION}",
    "rootUrl": "http://${SERVER_IP}",
    "adminUrl": "",
    "baseUrl": "",
    "surrogateAuthRequired": false,
    "enabled": true,
    "alwaysDisplayInConsole": false,
    "clientAuthenticatorType": "client-secret",
    "secret": "${CLIENT_SECRET}",
    "redirectUris": ${REDIRECT_URIS},
    "webOrigins": ["*"],
    "notBefore": 0,
    "bearerOnly": false,
    "consentRequired": false,
    "standardFlowEnabled": true,
    "implicitFlowEnabled": false,
    "directAccessGrantsEnabled": true,
    "serviceAccountsEnabled": true,
    "publicClient": ${PUBLIC_CLIENT},
    "frontchannelLogout": false,
    "protocol": "openid-connect",
    "attributes": {
        "saml.multivalued.roles": "false",
        "oauth2.device.authorization.grant.enabled": "true",
        "backchannel.logout.revoke.offline.tokens": "false",
        "use.refresh.tokens": "true",
        "oidc.ciba.grant.enabled": "false",
        "backchannel.logout.session.required": "true",
        "client_credentials.use_refresh_token": "false",
        "require.pushed.authorization.requests": "false",
        "tls.client.certificate.bound.access.tokens": "false",
        "display.on.consent.screen": "false",
        "token.response.type.bearer.lower-case": "false"
    },
    "fullScopeAllowed": true,
    "nodeReRegistrationTimeout": -1,
    "defaultClientScopes": ["web-origins", "roles", "profile", "email"],
    "optionalClientScopes": ["address", "phone", "offline_access", "microprofile-jwt"]
}
EOF
)

    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/clients" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${CLIENT_JSON}")
    
    if [ "$RESPONSE" == "201" ] || [ "$RESPONSE" == "409" ]; then
        echo -e "${GREEN}✔ Client '${CLIENT_ID}' configured${NC}"
    else
        echo -e "${RED}Failed to create client ${CLIENT_ID} (HTTP ${RESPONSE})${NC}"
    fi
}

create_realm_roles() {
    echo -e "${YELLOW}Creating realm roles...${NC}"
    
    local roles=("data-admin" "data-analyst" "data-engineer" "developer" "viewer" "power-user")
    local descriptions=(
        "Full access to all data platform services"
        "Read and analyze data, create dashboards"
        "Build and maintain data pipelines"
        "Develop applications and integrations"
        "Read-only access to reports and dashboards"
        "Extended access for advanced users"
    )
    
    for i in "${!roles[@]}"; do
        curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/roles" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"${roles[$i]}\",\"description\":\"${descriptions[$i]}\"}"
        echo -e "${GREEN}✔ Created role: ${roles[$i]}${NC}"
    done
}

create_user() {
    local USERNAME=$1
    local PASSWORD=$2
    local EMAIL=$3
    local FIRSTNAME=$4
    local LASTNAME=$5
    local ROLES=$6
    
    echo -e "${YELLOW}Creating user: ${USERNAME}...${NC}"
    
    USER_JSON=$(cat <<EOF
{
    "username": "${USERNAME}",
    "email": "${EMAIL}",
    "firstName": "${FIRSTNAME}",
    "lastName": "${LASTNAME}",
    "enabled": true,
    "emailVerified": true,
    "credentials": [{
        "type": "password",
        "value": "${PASSWORD}",
        "temporary": false
    }],
    "realmRoles": ${ROLES},
    "attributes": {
        "department": ["Data Platform"],
        "organization": ["Gemeente"]
    }
}
EOF
)

    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}/users" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${USER_JSON}")
    
    if [ "$RESPONSE" == "201" ] || [ "$RESPONSE" == "409" ]; then
        echo -e "${GREEN}✔ User '${USERNAME}' created${NC}"
    else
        echo -e "${YELLOW}User '${USERNAME}' might already exist (HTTP ${RESPONSE})${NC}"
    fi
}

setup_all_service_clients() {
    echo -e "${BLUE}\n=== Setting up ALL Service Clients ===${NC}"
    
    # Main OAuth2-proxy client for protecting multiple services
    create_client "gemeente-platform" \
        "gemeente-client-secret-change-me" \
        '["http://'${SERVER_IP}':4180/oauth2/callback","http://'${SERVER_IP}':4180/oauth2/callback/*"]' \
        "Main platform SSO client for OAuth2 proxy" \
        false
    
    # Grafana (native OAuth support)
    create_client "grafana" \
        "grafana-client-secret" \
        '["http://'${SERVER_IP}':13000/login/generic_oauth","http://'${SERVER_IP}':13000/*"]' \
        "Grafana monitoring dashboards" \
        false
    
    # Superset (native OAuth support)
    create_client "superset" \
        "superset-client-secret" \
        '["http://'${SERVER_IP}':8088/oauth-authorized/keycloak","http://'${SERVER_IP}':8088/*"]' \
        "Apache Superset BI platform" \
        false
    
    # pgAdmin (OAuth support in v7+)
    create_client "pgadmin" \
        "pgadmin-client-secret" \
        '["http://'${SERVER_IP}':8081/oauth2/authorize","http://'${SERVER_IP}':8081/*"]' \
        "PostgreSQL admin interface" \
        false
    
    # MinIO (OAuth support)
    create_client "minio" \
        "minio-client-secret" \
        '["http://'${SERVER_IP}':9001/oauth_callback","http://'${SERVER_IP}':9001/*"]' \
        "MinIO object storage" \
        false
    
    # NiFi (OAuth support)
    create_client "nifi" \
        "nifi-client-secret" \
        '["http://'${SERVER_IP}':8090/nifi-api/access/oidc/callback","http://'${SERVER_IP}':8090/*"]' \
        "Apache NiFi data flows" \
        false
    
    # Neo4j (via OAuth2-proxy)
    create_client "neo4j" \
        "neo4j-client-secret" \
        '["http://'${SERVER_IP}':7474/*"]' \
        "Neo4j graph database" \
        false
    
    # APISIX Dashboard
    create_client "apisix" \
        "apisix-client-secret" \
        '["http://'${SERVER_IP}':9000/*"]' \
        "APISIX API Gateway dashboard" \
        false
    
    # Vault UI (OAuth support)
    create_client "vault" \
        "vault-client-secret" \
        '["http://'${SERVER_IP}':8200/ui/vault/auth/oidc/oidc/callback","http://'${SERVER_IP}':8200/*"]' \
        "HashiCorp Vault secrets management" \
        false
    
    # DataHub (if you add it later)
    create_client "datahub" \
        "datahub-client-secret" \
        '["http://'${SERVER_IP}':9002/callback/oidc","http://'${SERVER_IP}':9002/*"]' \
        "DataHub metadata platform" \
        false
}

setup_users() {
    echo -e "${BLUE}\n=== Creating Users ===${NC}"
    
    # Admin users
    create_user "admin" "admin123" "admin@gemeente.nl" "Platform" "Admin" '["data-admin","power-user"]'
    create_user "dataadmin" "dataadmin123" "dataadmin@gemeente.nl" "Data" "Admin" '["data-admin"]'
    
    # Regular users
    create_user "analyst" "analyst123" "analyst@gemeente.nl" "Data" "Analyst" '["data-analyst","viewer"]'
    create_user "engineer" "engineer123" "engineer@gemeente.nl" "Data" "Engineer" '["data-engineer","developer"]'
    create_user "developer" "developer123" "developer@gemeente.nl" "App" "Developer" '["developer"]'
    create_user "viewer" "viewer123" "viewer@gemeente.nl" "Report" "Viewer" '["viewer"]'
    
    # Test users
    create_user "test" "test123" "test@gemeente.nl" "Test" "User" '["viewer"]'
    create_user "demo" "demo123" "demo@gemeente.nl" "Demo" "User" '["data-analyst","viewer"]'
}

configure_self_registration() {
    echo -e "${BLUE}\n=== Configuring Self-Registration ===${NC}"
    
    # Enable self-registration with email verification
    REGISTRATION_CONFIG=$(cat <<EOF
{
    "registrationAllowed": true,
    "registrationEmailAsUsername": false,
    "verifyEmail": true,
    "loginWithEmailAllowed": true,
    "duplicateEmailsAllowed": false,
    "resetPasswordAllowed": true,
    "editUsernameAllowed": false
}
EOF
)
    
    curl -s -X PUT "${KEYCLOAK_URL}/admin/realms/${REALM_NAME}" \
        -H "Authorization: Bearer ${TOKEN}" \
        -H "Content-Type: application/json" \
        -d "${REGISTRATION_CONFIG}"
    
    echo -e "${GREEN}✔ Self-registration enabled with email verification${NC}"
}

generate_env_file() {
    echo -e "${BLUE}\n=== Generating SSO Configuration Files ===${NC}"
    
    # Main SSO environment file
    cat > .env.sso <<EOF
# ===================================
# SSO Configuration for Gemeente Data Platform
# Generated: $(date)
# ===================================

# Keycloak Base Configuration
KEYCLOAK_REALM=${REALM_NAME}
KEYCLOAK_URL=${KEYCLOAK_URL}
KEYCLOAK_INTERNAL_URL=http://gemeente_keycloak:8080
KEYCLOAK_ADMIN_PASSWORD=${ADMIN_PASS}

# OAuth2 Proxy Settings
OAUTH2_PROXY_CLIENT_ID=gemeente-platform
OAUTH2_PROXY_CLIENT_SECRET=gemeente-client-secret-change-me
OAUTH2_PROXY_COOKIE_SECRET=$(openssl rand -hex 16)
OAUTH2_PROXY_REDIRECT_URL=http://${SERVER_IP}:4180/oauth2/callback
OAUTH2_PROXY_OIDC_ISSUER_URL=${KEYCLOAK_URL}/realms/${REALM_NAME}

# Service-specific OAuth Client Secrets
GRAFANA_CLIENT_ID=grafana
GRAFANA_CLIENT_SECRET=grafana-client-secret
SUPERSET_CLIENT_ID=superset
SUPERSET_CLIENT_SECRET=superset-client-secret
PGADMIN_CLIENT_ID=pgadmin
PGADMIN_CLIENT_SECRET=pgadmin-client-secret
MINIO_CLIENT_ID=minio
MINIO_CLIENT_SECRET=minio-client-secret
NIFI_CLIENT_ID=nifi
NIFI_CLIENT_SECRET=nifi-client-secret
VAULT_CLIENT_ID=vault
VAULT_CLIENT_SECRET=vault-client-secret

# Service URLs for SSO callbacks
SSO_GRAFANA_URL=http://${SERVER_IP}:13000
SSO_SUPERSET_URL=http://${SERVER_IP}:8088
SSO_PGADMIN_URL=http://${SERVER_IP}:8081
SSO_MINIO_URL=http://${SERVER_IP}:9001
SSO_NIFI_URL=http://${SERVER_IP}:8090
SSO_VAULT_URL=http://${SERVER_IP}:8200
EOF

    echo -e "${GREEN}✔ SSO configuration saved to .env.sso${NC}"
}

generate_docker_compose_override() {
    echo -e "${BLUE}\n=== Generating Docker Compose Override ===${NC}"
    
    cat > docker-compose.sso.yml <<'EOF'
version: '3.8'

services:
  # Update OAuth2 Proxy to protect more services
  oauth2-proxy:
    image: quay.io/oauth2-proxy/oauth2-proxy:v7.5.1
    container_name: gemeente_oauth2_proxy
    restart: always
    depends_on:
      keycloak:
        condition: service_healthy
    environment:
      OAUTH2_PROXY_PROVIDER: keycloak-oidc
      OAUTH2_PROXY_CLIENT_ID: ${OAUTH2_PROXY_CLIENT_ID}
      OAUTH2_PROXY_CLIENT_SECRET: ${OAUTH2_PROXY_CLIENT_SECRET}
      OAUTH2_PROXY_REDIRECT_URL: ${OAUTH2_PROXY_REDIRECT_URL}
      OAUTH2_PROXY_OIDC_ISSUER_URL: ${OAUTH2_PROXY_OIDC_ISSUER_URL}
      OAUTH2_PROXY_COOKIE_SECRET: ${OAUTH2_PROXY_COOKIE_SECRET}
      OAUTH2_PROXY_COOKIE_SECURE: 'false'
      OAUTH2_PROXY_EMAIL_DOMAINS: '*'
      OAUTH2_PROXY_SKIP_PROVIDER_BUTTON: 'false'
      OAUTH2_PROXY_PASS_BASIC_AUTH: 'true'
      OAUTH2_PROXY_PASS_USER_HEADERS: 'true'
      OAUTH2_PROXY_SET_XAUTHREQUEST: 'true'
      OAUTH2_PROXY_HTTP_ADDRESS: 0.0.0.0:4180
      OAUTH2_PROXY_UPSTREAMS: |
        http://prometheus:9090/=http://prometheus:9090/
        http://elasticsearch:9200/=http://elasticsearch:9200/
        http://loki:3100/=http://loki:3100/
        http://neo4j:7474/=http://neo4j:7474/
        http://apisix-dashboard:9000/apisix/=http://apisix-dashboard:9000/
    ports:
      - "4180:4180"
    networks:
      - backend

  # Update Grafana with SSO
  grafana:
    environment:
      GF_AUTH_GENERIC_OAUTH_ENABLED: 'true'
      GF_AUTH_GENERIC_OAUTH_NAME: 'Keycloak SSO'
      GF_AUTH_GENERIC_OAUTH_ALLOW_SIGN_UP: 'true'
      GF_AUTH_GENERIC_OAUTH_CLIENT_ID: ${GRAFANA_CLIENT_ID}
      GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET: ${GRAFANA_CLIENT_SECRET}
      GF_AUTH_GENERIC_OAUTH_SCOPES: 'openid email profile'
      GF_AUTH_GENERIC_OAUTH_AUTH_URL: ${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/auth
      GF_AUTH_GENERIC_OAUTH_TOKEN_URL: ${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token
      GF_AUTH_GENERIC_OAUTH_API_URL: ${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/userinfo
      GF_AUTH_SIGNOUT_REDIRECT_URL: ${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/protocol/openid-connect/logout?redirect_uri=${SSO_GRAFANA_URL}
      GF_SERVER_ROOT_URL: ${SSO_GRAFANA_URL}
      GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH: "contains(roles[*], 'data-admin') && 'Admin' || contains(roles[*], 'data-analyst') && 'Editor' || 'Viewer'"
      GF_AUTH_DISABLE_LOGIN_FORM: 'false'
      GF_AUTH_OAUTH_AUTO_LOGIN: 'false'

  # MinIO with OpenID Connect
  minio:
    environment:
      MINIO_IDENTITY_OPENID_CONFIG_URL: ${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}/.well-known/openid-configuration
      MINIO_IDENTITY_OPENID_CLIENT_ID: ${MINIO_CLIENT_ID}
      MINIO_IDENTITY_OPENID_CLIENT_SECRET: ${MINIO_CLIENT_SECRET}
      MINIO_IDENTITY_OPENID_SCOPES: 'openid,profile,email'
      MINIO_IDENTITY_OPENID_REDIRECT_URI: ${SSO_MINIO_URL}/oauth_callback
      MINIO_IDENTITY_OPENID_CLAIM_NAME: 'preferred_username'
      MINIO_IDENTITY_OPENID_DISPLAY_NAME: 'SSO Login'

  # Vault with OIDC
  vault:
    environment:
      VAULT_UI: 'true'
      VAULT_OIDC_DISCOVERY_URL: ${KEYCLOAK_URL}/realms/${KEYCLOAK_REALM}
      VAULT_OIDC_CLIENT_ID: ${VAULT_CLIENT_ID}
      VAULT_OIDC_CLIENT_SECRET: ${VAULT_CLIENT_SECRET}
EOF

    echo -e "${GREEN}✔ Docker Compose SSO override saved to docker-compose.sso.yml${NC}"
}

generate_service_configs() {
    echo -e "${BLUE}\n=== Generating Service Configuration Files ===${NC}"
    
    # Superset SSO config
    cat > superset_sso_config.py <<EOF
# Add to your superset_config.py

from flask_appbuilder.security.manager import AUTH_OAUTH
import os

# Existing configuration
SECRET_KEY = os.environ.get('SUPERSET_SECRET_KEY', 'ThisIsASecureKeyForDevelopment2024ChangeInProduction')
SQLALCHEMY_DATABASE_URI = 'postgresql+psycopg2://superset:superset123@gemeente_postgres:5432/superset'

# OAuth configuration
AUTH_TYPE = AUTH_OAUTH
OAUTH_PROVIDERS = [
    {
        'name': 'keycloak',
        'icon': 'fa-key',
        'token_key': 'access_token',
        'remote_app': {
            'client_id': os.environ.get('SUPERSET_CLIENT_ID', 'superset'),
            'client_secret': os.environ.get('SUPERSET_CLIENT_SECRET', 'superset-client-secret'),
            'client_kwargs': {
                'scope': 'openid email profile'
            },
            'access_token_method': 'POST',
            'api_base_url': os.environ.get('KEYCLOAK_URL', 'http://192.168.1.25:8085') + '/realms/gemeente/protocol/',
            'access_token_url': os.environ.get('KEYCLOAK_URL', 'http://192.168.1.25:8085') + '/realms/gemeente/protocol/openid-connect/token',
            'authorize_url': os.environ.get('KEYCLOAK_URL', 'http://192.168.1.25:8085') + '/realms/gemeente/protocol/openid-connect/auth',
            'server_metadata_url': os.environ.get('KEYCLOAK_URL', 'http://192.168.1.25:8085') + '/realms/gemeente/.well-known/openid-configuration'
        }
    }
]

# Map OAuth groups to Superset roles
AUTH_ROLE_ADMIN = 'Admin'
AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = 'Viewer'

# Custom role mapping function
def custom_oauth_user_info_getter(client, user_info):
    roles = user_info.get('roles', [])
    if 'data-admin' in roles:
        return {'role': 'Admin'}
    elif 'data-analyst' in roles:
        return {'role': 'Alpha'}
    elif 'data-engineer' in roles:
        return {'role': 'Gamma'}
    else:
        return {'role': 'Viewer'}

CUSTOM_SECURITY_MANAGER = custom_oauth_user_info_getter
EOF

    echo -e "${GREEN}✔ Superset SSO config saved to superset_sso_config.py${NC}"
    
    # pgAdmin SSO config
    cat > pgadmin_sso_config.py <<EOF
# pgAdmin OAuth configuration
# Add to pgAdmin config

AUTHENTICATION_SOURCES = ['oauth2']
OAUTH2_CONFIG = [
    {
        'OAUTH2_NAME': 'Keycloak SSO',
        'OAUTH2_DISPLAY_NAME': 'Login with SSO',
        'OAUTH2_CLIENT_ID': '${PGADMIN_CLIENT_ID}',
        'OAUTH2_CLIENT_SECRET': '${PGADMIN_CLIENT_SECRET}',
        'OAUTH2_TOKEN_URL': '${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/token',
        'OAUTH2_AUTHORIZATION_URL': '${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/auth',
        'OAUTH2_API_BASE_URL': '${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/',
        'OAUTH2_USERINFO_ENDPOINT': '${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/userinfo',
        'OAUTH2_SCOPE': 'openid email profile',
        'OAUTH2_ICON': 'fa-key',
        'OAUTH2_BUTTON_COLOR': '#3253dc'
    }
]
EOF

    echo -e "${GREEN}✔ pgAdmin SSO config saved to pgadmin_sso_config.py${NC}"
}

print_access_info() {
    echo -e "${GREEN}\n========================================${NC}"
    echo -e "${GREEN}  ✔ Complete SSO Setup Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}Keycloak Admin Console:${NC}"
    echo "  URL: ${KEYCLOAK_URL}"
    echo "  Username: admin"
    echo "  Password: ${ADMIN_PASS}"
    echo ""
    echo -e "${BLUE}Services with Native SSO (direct login):${NC}"
    echo "  Grafana: http://${SERVER_IP}:13000 - Click 'Sign in with Keycloak SSO'"
    echo "  Superset: http://${SERVER_IP}:8088 - Click OAuth login"
    echo "  MinIO: http://${SERVER_IP}:9001 - Click SSO Login"
    echo "  Vault: http://${SERVER_IP}:8200 - Select OIDC method"
    echo ""
    echo -e "${BLUE}Services via OAuth2 Proxy:${NC}"
    echo "  Prometheus: http://${SERVER_IP}:4180/prometheus/"
    echo "  Elasticsearch: http://${SERVER_IP}:4180/elasticsearch/"
    echo "  Loki: http://${SERVER_IP}:4180/loki/"
    echo "  Neo4j: http://${SERVER_IP}:4180/neo4j/"
    echo ""
    echo -e "${BLUE}Services requiring manual SSO setup:${NC}"
    echo "  NiFi: Needs additional configuration in nifi.properties"
    echo "  pgAdmin: Update config_local.py with OAuth settings"
    echo ""
    echo -e "${BLUE}Test Users:${NC}"
    echo "  admin/admin123 - Full platform admin"
    echo "  dataadmin/dataadmin123 - Data administration"
    echo "  analyst/analyst123 - Data analysis access"
    echo "  engineer/engineer123 - Pipeline development"
    echo "  developer/developer123 - Application development"
    echo "  viewer/viewer123 - Read-only access"
    echo ""
    echo -e "${YELLOW}Self-Registration:${NC}"
    echo "  Users can self-register at: ${KEYCLOAK_URL}/realms/${REALM_NAME}/account"
    echo "  New users get 'viewer' role by default"
    echo "  Admins can upgrade roles in Keycloak admin console"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Source SSO environment: source .env.sso"
    echo "2. Apply Docker Compose override: docker-compose -f docker-compose.yml -f docker-compose.sso.yml up -d"
    echo "3. Update service configs with generated SSO configs"
    echo "4. Test SSO login for each service"
    echo ""
    echo -e "${GREEN}Security Notes:${NC}"
    echo "• Change all client secrets before production"
    echo "• Configure email server in Keycloak for password reset"
    echo "• Enable 2FA for admin accounts"
    echo "• Regular review user access and roles"
    echo ""
}

# Main execution
print_header

# Check if Keycloak is running
if ! docker ps | grep -q gemeente_keycloak; then
    echo -e "${RED}Keycloak container is not running!${NC}"
    echo "Start it with: docker-compose up -d keycloak"
    exit 1
fi

wait_for_keycloak
get_admin_token
create_realm
create_realm_roles
setup_all_service_clients
setup_users
configure_self_registration
generate_env_file
generate_docker_compose_override
generate_service_configs
print_access_info

echo -e "${GREEN}✅ Complete SSO setup finished!${NC}"
echo -e "${YELLOW}Config files created:${NC}"
echo "  • .env.sso - Environment variables"
echo "  • docker-compose.sso.yml - Docker override"
echo "  • superset_sso_config.py - Superset OAuth config"
echo "  • pgadmin_sso_config.py - pgAdmin OAuth config"