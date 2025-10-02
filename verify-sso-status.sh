#!/bin/bash

# ===================================
# SSO Verification & Troubleshooting Script
# Test and debug SSO configuration
# ===================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SERVER_IP="192.168.1.25"
KEYCLOAK_URL="http://${SERVER_IP}:8085"
REALM_NAME="gemeente"

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

print_header() {
    echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║        SSO VERIFICATION & TROUBLESHOOTING      ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

test_service() {
    local SERVICE_NAME=$1
    local TEST_URL=$2
    local EXPECTED=$3
    local CHECK_TYPE=${4:-"contains"}
    
    echo -n "Testing ${SERVICE_NAME}... "
    
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" ${TEST_URL} 2>/dev/null || echo "000")
    
    if [ "$CHECK_TYPE" == "status" ]; then
        if [ "$RESPONSE" == "$EXPECTED" ]; then
            echo -e "${GREEN}✔ OK (HTTP ${RESPONSE})${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            echo -e "${RED}✗ FAILED (HTTP ${RESPONSE}, expected ${EXPECTED})${NC}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    else
        CONTENT=$(curl -s ${TEST_URL} 2>/dev/null || echo "")
        if echo "$CONTENT" | grep -q "$EXPECTED"; then
            echo -e "${GREEN}✔ OK${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            echo -e "${RED}✗ FAILED${NC}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    fi
}

test_keycloak() {
    echo -e "${BLUE}=== Testing Keycloak ===${NC}"
    
    # Test Keycloak health
    test_service "Keycloak Health" "${KEYCLOAK_URL}/health/ready" "UP" "contains"
    
    # Test realm exists
    test_service "Gemeente Realm" "${KEYCLOAK_URL}/realms/${REALM_NAME}" "gemeente" "contains"
    
    # Test OIDC discovery
    test_service "OIDC Discovery" "${KEYCLOAK_URL}/realms/${REALM_NAME}/.well-known/openid-configuration" "issuer" "contains"
    
    # Test login with default admin
    echo -n "Testing admin login... "
    TOKEN_RESPONSE=$(curl -s -X POST "${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "client_id=gemeente-platform" \
        -d "client_secret=gemeente-client-secret-change-me" \
        -d "grant_type=password" \
        -d "username=admin" \
        -d "password=admin123" 2>/dev/null || echo "{}")
    
    if echo "$TOKEN_RESPONSE" | grep -q "access_token"; then
        echo -e "${GREEN}✔ OK${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token' 2>/dev/null || echo "")
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo -e "${YELLOW}  Response: $(echo $TOKEN_RESPONSE | jq -r '.error_description' 2>/dev/null || echo 'No response')${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    echo ""
}

test_oauth2_proxy() {
    echo -e "${BLUE}=== Testing OAuth2 Proxy ===${NC}"
    
    # Test OAuth2-proxy health
    test_service "OAuth2-proxy" "http://${SERVER_IP}:4180/ping" "200" "status"
    
    # Test sign-in page
    test_service "Sign-in Page" "http://${SERVER_IP}:4180/oauth2/sign_in" "Sign in" "contains"
    
    # Test protected endpoints redirect
    test_service "Prometheus Protection" "http://${SERVER_IP}:4180/prometheus/" "302" "status"
    test_service "Loki Protection" "http://${SERVER_IP}:4180/loki/" "302" "status"
    
    echo ""
}

test_service_sso() {
    echo -e "${BLUE}=== Testing Service SSO Integration ===${NC}"
    
    # Grafana SSO
    echo -n "Testing Grafana SSO config... "
    GRAFANA_CONFIG=$(curl -s http://${SERVER_IP}:13000/api/health 2>/dev/null || echo "")
    if [ ! -z "$GRAFANA_CONFIG" ]; then
        echo -e "${GREEN}✔ Grafana reachable${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Grafana not responding${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Superset SSO
    test_service "Superset" "http://${SERVER_IP}:8088/health" "200" "status"
    
    # MinIO Console
    test_service "MinIO Console" "http://${SERVER_IP}:9001" "200" "status"
    
    # pgAdmin
    test_service "pgAdmin" "http://${SERVER_IP}:8081/misc/ping" "200" "status"
    
    echo ""
}

check_docker_services() {
    echo -e "${BLUE}=== Checking Docker Services ===${NC}"
    
    SERVICES=("keycloak" "oauth2-proxy" "grafana" "superset" "minio" "pgadmin")
    
    for SERVICE in "${SERVICES[@]}"; do
        echo -n "Checking gemeente_${SERVICE}... "
        if docker ps | grep -q "gemeente_${SERVICE}"; then
            STATUS=$(docker ps --format "table {{.Status}}" --filter "name=gemeente_${SERVICE}" | tail -n 1)
            echo -e "${GREEN}✔ Running (${STATUS})${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}✗ Not running${NC}"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    done
    
    echo ""
}

check_configuration() {
    echo -e "${BLUE}=== Checking Configuration Files ===${NC}"
    
    # Check environment files
    echo -n "Checking .env.sso... "
    if [ -f .env.sso ]; then
        echo -e "${GREEN}✔ Found${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Not found${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    # Check Docker Compose override
    echo -n "Checking docker-compose.sso.yml... "
    if [ -f docker-compose.sso.yml ]; then
        echo -e "${GREEN}✔ Found${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠ Not found (optional)${NC}"
    fi
    
    # Check if SSO env is sourced
    echo -n "Checking if SSO environment is loaded... "
    if [ ! -z "$KEYCLOAK_REALM" ]; then
        echo -e "${GREEN}✔ Loaded (realm: $KEYCLOAK_REALM)${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}⚠ Not loaded (run: source .env.sso)${NC}"
    fi
    
    echo ""
}

troubleshoot_common_issues() {
    echo -e "${BLUE}=== Common Issues & Solutions ===${NC}"
    
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "${YELLOW}Found ${TESTS_FAILED} issues. Here are common solutions:${NC}"
        echo ""
        
        # Keycloak issues
        if ! curl -s ${KEYCLOAK_URL}/health/ready | grep -q "UP"; then
            echo -e "${YELLOW}Issue: Keycloak not responding${NC}"
            echo "Solutions:"
            echo "  1. Check if container is running: docker ps | grep keycloak"
            echo "  2. Check logs: docker-compose logs keycloak"
            echo "  3. Restart: docker-compose restart keycloak"
            echo "  4. Check database: docker-compose logs postgres"
            echo ""
        fi
        
        # OAuth2-proxy issues
        if ! curl -s http://${SERVER_IP}:4180/ping &>/dev/null; then
            echo -e "${YELLOW}Issue: OAuth2-proxy not responding${NC}"
            echo "Solutions:"
            echo "  1. Check configuration: docker-compose logs oauth2-proxy"
            echo "  2. Verify Keycloak URL in .env.sso"
            echo "  3. Check client secret matches Keycloak"
            echo "  4. Restart: docker-compose restart oauth2-proxy"
            echo ""
        fi
        
        # Login issues
        if ! test_service "Test Login" "${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/token" "access_token" "contains"; then
            echo -e "${YELLOW}Issue: Cannot authenticate${NC}"
            echo "Solutions:"
            echo "  1. Verify realm exists: ${KEYCLOAK_URL}/realms/${REALM_NAME}"
            echo "  2. Check client configuration in Keycloak admin"
            echo "  3. Verify user exists and password is correct"
            echo "  4. Check client secret in .env.sso"
            echo ""
        fi
    else
        echo -e "${GREEN}No issues found! SSO is working correctly.${NC}"
    fi
}

generate_test_commands() {
    echo -e "${BLUE}=== Useful Test Commands ===${NC}"
    
    cat <<EOF
# Get access token:
curl -X POST ${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/token \\
  -d "client_id=gemeente-platform" \\
  -d "client_secret=gemeente-client-secret-change-me" \\
  -d "grant_type=password" \\
  -d "username=admin" \\
  -d "password=admin123" | jq .

# Test protected endpoint with token:
TOKEN=\$(curl -s -X POST ${KEYCLOAK_URL}/realms/${REALM_NAME}/protocol/openid-connect/token \\
  -d "client_id=gemeente-platform" \\
  -d "client_secret=gemeente-client-secret-change-me" \\
  -d "grant_type=password" \\
  -d "username=admin" \\
  -d "password=admin123" | jq -r .access_token)

curl -H "Authorization: Bearer \$TOKEN" http://${SERVER_IP}:13000/api/user

# View Keycloak realm config:
curl ${KEYCLOAK_URL}/realms/${REALM_NAME} | jq .

# Check OAuth2-proxy config:
docker exec gemeente_oauth2_proxy cat /etc/oauth2-proxy/oauth2-proxy.cfg

# View service logs:
docker-compose logs -f keycloak oauth2-proxy grafana

EOF
}

show_access_urls() {
    echo -e "${BLUE}=== Quick Access URLs ===${NC}"
    
    echo "Keycloak Admin Console:"
    echo "  ${KEYCLOAK_URL}/admin"
    echo "  Username: admin"
    echo "  Password: admin123"
    echo ""
    echo "User Self-Service:"
    echo "  ${KEYCLOAK_URL}/realms/${REALM_NAME}/account"
    echo ""
    echo "Services with SSO:"
    echo "  Grafana: http://${SERVER_IP}:13000"
    echo "  Superset: http://${SERVER_IP}:8088"
    echo "  MinIO: http://${SERVER_IP}:9001"
    echo ""
    echo "Protected Services (via OAuth2-proxy):"
    echo "  Prometheus: http://${SERVER_IP}:4180/prometheus/"
    echo "  Elasticsearch: http://${SERVER_IP}:4180/elasticsearch/"
    echo "  Loki: http://${SERVER_IP}:4180/loki/"
    echo ""
}

print_summary() {
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo -e "${CYAN}           TEST SUMMARY                 ${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
    echo ""
    echo -e "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "Tests Failed: ${RED}${TESTS_FAILED}${NC}"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ All tests passed! SSO is fully functional.${NC}"
    elif [ $TESTS_FAILED -lt 3 ]; then
        echo -e "${YELLOW}⚠ Minor issues detected. SSO is partially functional.${NC}"
    else
        echo -e "${RED}❌ Major issues detected. SSO needs configuration.${NC}"
    fi
}

# Main execution
main() {
    print_header
    
    check_configuration
    check_docker_services
    test_keycloak
    test_oauth2_proxy
    test_service_sso
    
    echo ""
    troubleshoot_common_issues
    echo ""
    show_access_urls
    echo ""
    generate_test_commands
    echo ""
    print_summary
}

# Run with specific test if provided
if [ "$1" == "--keycloak" ]; then
    print_header
    test_keycloak
elif [ "$1" == "--oauth" ]; then
    print_header
    test_oauth2_proxy
elif [ "$1" == "--services" ]; then
    print_header
    test_service_sso
elif [ "$1" == "--docker" ]; then
    print_header
    check_docker_services
elif [ "$1" == "--help" ]; then
    echo "Usage: $0 [--keycloak|--oauth|--services|--docker]"
    echo ""
    echo "Options:"
    echo "  --keycloak   Test only Keycloak"
    echo "  --oauth      Test only OAuth2-proxy"
    echo "  --services   Test only service SSO"
    echo "  --docker     Test only Docker services"
    echo "  --help       Show this help"
    echo ""
    echo "Without options, runs all tests"
else
    main
fi