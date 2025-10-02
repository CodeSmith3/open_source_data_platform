#!/bin/bash

# ===================================
# Cleanup Old/Redundant Scripts
# Verwijdert verouderde migratie en fix scripts
# ===================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Script Cleanup Tool                                 ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Create archive directory
ARCHIVE_DIR="archived-scripts-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$ARCHIVE_DIR"

echo -e "${BLUE}Analysis of scripts:${NC}"
echo ""

# Scripts to remove (one-time migration/fix scripts)
SCRIPTS_TO_ARCHIVE=(
    # NiFi to Airflow migration scripts (already completed)
    "step1-remove-nifi.sh"
    "step2-setup-keycloak-airflow.sh"
    "step3-install-airflow-sso.sh"
    "step4-update-dashboard.sh"
    "step5-verify-all.sh"
    
    # One-time fix scripts (issues already resolved)
    "fix-sso-final.sh"
    "fix-network-issue.sh"
    "fix-database-password.sh"
    "fix-container-conflict.sh"
)

# Scripts to keep (ongoing utility)
SCRIPTS_TO_KEEP=(
    "verify-sso-status.sh"          # Useful for troubleshooting
    "switch-environment.sh"          # Switch dev/prod
    "setup-complete-sso.sh"          # Can setup SSO from scratch
    "apply-sso-complete.sh"          # Apply SSO configuration
)

echo -e "${YELLOW}Scripts to archive (move to backup):${NC}"
for script in "${SCRIPTS_TO_ARCHIVE[@]}"; do
    if [ -f "$script" ]; then
        echo "  📦 $script"
    fi
done

echo ""
echo -e "${GREEN}Scripts to keep (still useful):${NC}"
for script in "${SCRIPTS_TO_KEEP[@]}"; do
    if [ -f "$script" ]; then
        echo "  ✅ $script"
    fi
done

echo ""
echo -e "${YELLOW}Do you want to proceed with archiving? (y/n)${NC}"
read -r response

if [[ "$response" != "y" ]]; then
    echo "Cancelled"
    exit 0
fi

# Archive old scripts
echo ""
echo -e "${BLUE}Archiving old scripts...${NC}"
archived_count=0

for script in "${SCRIPTS_TO_ARCHIVE[@]}"; do
    if [ -f "$script" ]; then
        mv "$script" "$ARCHIVE_DIR/"
        echo -e "${GREEN}✔${NC} Archived: $script"
        archived_count=$((archived_count + 1))
    fi
done

# Create README in archive
cat > "$ARCHIVE_DIR/README.md" <<EOF
# Archived Scripts

These scripts were archived on $(date) as they are no longer needed for regular operations.

## Migration Scripts (Completed)
These scripts were used for the one-time NiFi → Airflow migration:
- step1-remove-nifi.sh
- step2-setup-keycloak-airflow.sh
- step3-install-airflow-sso.sh
- step4-update-dashboard.sh
- step5-verify-all.sh

## Fix Scripts (Issues Resolved)
These scripts fixed specific one-time issues:
- fix-sso-final.sh
- fix-network-issue.sh
- fix-database-password.sh
- fix-container-conflict.sh

## Recovery
If you need any of these scripts, they are preserved in this archive.
Simply copy them back to the main directory if needed.

Archive created: $(date)
EOF

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}   Cleanup Summary                                     ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}✅ Archived: $archived_count scripts${NC}"
echo -e "${BLUE}📁 Archive location: $ARCHIVE_DIR${NC}"
echo ""
echo -e "${GREEN}Active utility scripts:${NC}"
for script in "${SCRIPTS_TO_KEEP[@]}"; do
    if [ -f "$script" ]; then
        echo "  • $script"
    fi
done

echo ""
echo -e "${YELLOW}Note: Archived scripts are safely stored and can be restored if needed.${NC}"
echo ""