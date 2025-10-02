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
