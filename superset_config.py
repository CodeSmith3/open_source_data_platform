# Superset Configuration - Localhost
import os

SECRET_KEY = os.environ.get('SUPERSET_SECRET_KEY', 'DevKey2024SecureForGemeente')
SQLALCHEMY_DATABASE_URI = 'postgresql+psycopg2://superset:superset123@gemeente_postgres:5432/superset'
SQLALCHEMY_TRACK_MODIFICATIONS = False

# Disable CSRF for development
WTF_CSRF_ENABLED = False
WTF_CSRF_CHECK_DEFAULT = False
TALISMAN_ENABLED = False

# Session configuration
SESSION_COOKIE_HTTPONLY = False
SESSION_COOKIE_SECURE = False
SESSION_COOKIE_SAMESITE = None
SESSION_COOKIE_DOMAIN = None
PERMANENT_SESSION_LIFETIME = 86400
SESSION_PROTECTION = None
SESSION_TYPE = 'sqlalchemy'

# Application settings
SUPERSET_WEBSERVER_TIMEOUT = 300
ROW_LIMIT = 5000
ENABLE_PROXY_FIX = True
HTTP_HEADERS = {}

# Logging
import logging
LOG_LEVEL = logging.DEBUG
