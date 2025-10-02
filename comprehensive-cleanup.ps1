# comprehensive-cleanup.ps1
# ===================================
# COMPREHENSIVE PROJECT CLEANUP (PowerShell versie)
# Gemeente Data Platform
# ===================================

$ErrorActionPreference = "Stop"

# Kleuren
Function Write-Info($msg)    { Write-Host $msg -ForegroundColor Cyan }
Function Write-Warn($msg)    { Write-Host $msg -ForegroundColor Yellow }
Function Write-Success($msg) { Write-Host $msg -ForegroundColor Green }
Function Write-ErrorMsg($msg){ Write-Host $msg -ForegroundColor Red }

# Timestamp
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$finalBackup = "final-backup-$timestamp"

Write-Info "==============================================="
Write-Info "COMPREHENSIVE PROJECT CLEANUP"
Write-Info "This will remove ALL redundant files"
Write-Info "==============================================="
Write-Host ""

# Backup maken
Write-Host "Creating final backup before cleanup..." -ForegroundColor Blue
New-Item -ItemType Directory -Force -Path $finalBackup | Out-Null

Copy-Item ".env" "$finalBackup" -ErrorAction SilentlyContinue
Copy-Item "docker-compose.yml" "$finalBackup" -ErrorAction SilentlyContinue
Copy-Item "docker-compose.airflow.yml" "$finalBackup" -ErrorAction SilentlyContinue
Copy-Item "superset_config.py" "$finalBackup" -ErrorAction SilentlyContinue
Copy-Item "dags" "$finalBackup" -Recurse -ErrorAction SilentlyContinue

Write-Success "[OK] Backup created in: $finalBackup"

# Bevestiging vragen
Write-Warn "This will DELETE redundant backups, configs, placeholders, and unused folders."
$reply = Read-Host "Continue with cleanup? This CANNOT be undone (except from backup). (y/N)"
if ($reply -notmatch "^[Yy]$") {
    Write-Host "Cleanup cancelled."
    exit
}

# === 1. Oude backups verwijderen ===
Write-Warn "[1/8] Removing old backup folders..."
Remove-Item "backup-20250929-173539" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "backup-before-cleanup-20250930-131243" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "platform-backup-20250930-121908" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "archived-scripts-20250930-114239" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "archived-scripts-20250930-131243" -Recurse -Force -ErrorAction SilentlyContinue
Write-Success "[OK] Old backups removed"

# === 2. NiFi config verwijderen ===
Write-Warn "[2/8] Removing NiFi configurations..."
Remove-Item "config\nifi" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "nginx-nifi.conf","htpasswd" -Force -ErrorAction SilentlyContinue
(Get-Content ".gitignore") | Where-Object {$_ -notmatch "nifi"} | Set-Content ".gitignore"
Write-Success "[OK] NiFi files removed"

# === 3. Backup config files verwijderen ===
Write-Warn "[3/8] Removing backup configuration files..."
Remove-Item "CREDENTIALS.md.backup-*" -Force -ErrorAction SilentlyContinue
Remove-Item "docker-compose.yml.backup-*" -Force -ErrorAction SilentlyContinue
Remove-Item "superset_config.py.backup-*" -Force -ErrorAction SilentlyContinue
Write-Success "[OK] Backup configs removed"

# === 4. Placeholder files verwijderen ===
Write-Warn "[4/8] Removing placeholder files..."
Remove-Item "config\keycloak\custom-providers\provider.py" -Force -ErrorAction SilentlyContinue
Remove-Item "config\spark\jobs\*.py" -Force -ErrorAction SilentlyContinue
Remove-Item "tests\fixtures\*.json" -Force -ErrorAction SilentlyContinue
Write-Success "[OK] Placeholder files removed"

# === 5. Lege directories verwijderen ===
Write-Warn "[5/8] Removing empty directories..."
Get-ChildItem "config","monitoring","tests","utilities","security","docs" -Recurse -Directory |
    Where-Object { @(Get-ChildItem $_.FullName -Force -Recurse -ErrorAction SilentlyContinue).Count -eq 0 } |
    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
Write-Success "[OK] Empty directories removed"

# === 6. Redundante scripts verwijderen ===
Write-Warn "[6/8] Consolidating scripts..."
Remove-Item "scripts\fix-compose-booleans.sh","scripts\init-db.sh","scripts\backup-data.sh","scripts\restore-data.sh","scripts\setup-permissions.sh" -Force -ErrorAction SilentlyContinue
Write-Success "[OK] Scripts consolidated"

# === 7. Monitoring configs opschonen ===
Write-Warn "[7/8] Cleaning monitoring configs..."
Remove-Item "config\monitoring\prometheus\prometheus.yml","config\monitoring\prometheus\alerts.yml" -Force -ErrorAction SilentlyContinue
Remove-Item "config\monitoring\prometheus\targets\*.yml" -Force -ErrorAction SilentlyContinue
Write-Success "[OK] Monitoring configs cleaned"

# === 8. Cleanup rapport maken ===
Write-Warn "[8/8] Creating cleanup documentation..."
$report = @"
# Project Cleanup - Complete
Date: $(Get-Date)
Backup created in: $finalBackup
See script for details of what was removed and kept.
"@
$report | Out-File -FilePath "CLEANUP_COMPLETE.md" -Encoding utf8
Write-Success "[OK] Documentation created"

# === Samenvatting ===
Write-Info "==============================================="
Write-Info "CLEANUP COMPLETE!"
Write-Info "==============================================="
Write-Success "[SUCCESS] Project successfully cleaned!"
Write-Warn "Backup location: $finalBackup"
Write-Warn "Cleanup report: CLEANUP_COMPLETE.md"
