import os
from datetime import timedelta

import secrets
# Database configuration
SQLALCHEMY_DATABASE_URI = 'postgresql+psycopg2://superset:superset@postgres:5432/superset'
SECRET_KEY = secrets.token_urlsafe(64)

# Flask-WTF flag for CSRF
WTF_CSRF_ENABLED = True
WTF_CSRF_TIME_LIMIT = None

# Set this API key to enable Mapbox
MAPBOX_API_KEY = ''

# Cache configuration
CACHE_CONFIG = {
    'CACHE_TYPE': 'redis',
    'CACHE_DEFAULT_TIMEOUT': 300,
    'CACHE_KEY_PREFIX': 'superset_',
    'CACHE_REDIS_HOST': 'redis',
    'CACHE_REDIS_PORT': 6379,
    'CACHE_REDIS_DB': 1,
    'CACHE_REDIS_URL': 'redis://redis:6379/1'
}

# Async queries via Celery
CELERY_CONFIG = {
    'broker_url': 'redis://redis:6379/0',
    'result_backend': 'redis://redis:6379/0',
    'worker_log_level': 'DEBUG',
    'worker_prefetch_multiplier': 10,
    'task_acks_late': True,
}

class CeleryConfig(object):
    BROKER_URL = 'redis://redis:6379/0'
    CELERY_IMPORTS = (
        'superset.sql_lab',
        'superset.tasks',
    )
    CELERY_RESULT_BACKEND = 'redis://redis:6379/0'
    CELERYD_LOG_LEVEL = 'DEBUG'
    CELERYD_PREFETCH_MULTIPLIER = 10
    CELERY_ACKS_LATE = True
    CELERY_ANNOTATIONS = {
        'sql_lab.get_sql_results': {
            'rate_limit': '100/s',
        },
    }

CELERY_CONFIG = CeleryConfig

# Security
SECRET_KEY = '6WKMoeZ-EQDsvFEc3wT0d6D5yOQadz0W-SyB_yECxdJya3b_9ovjkhsC16YiB52BJAj27usfWNrX-UnqUTec9Q'

# Feature flags
FEATURE_FLAGS = {
    'ENABLE_TEMPLATE_PROCESSING': True,
    'DASHBOARD_NATIVE_FILTERS': True,
    'DASHBOARD_CROSS_FILTERS': True,
    'DASHBOARD_RBAC': True,
    'EMBEDDABLE_CHARTS': True,
    'SCHEDULED_QUERIES': True,
    'ESTIMATE_QUERY_COST': False,
    'ENABLE_REACT_CRUD_VIEWS': True,
    'ALERT_REPORTS': True,
}

# Email configuration (optional)
SMTP_HOST = 'localhost'
SMTP_STARTTLS = True
SMTP_SSL = False
SMTP_USER = 'superset'
SMTP_PORT = 25
SMTP_PASSWORD = 'superset'
SMTP_MAIL_FROM = 'superset@gemeente.nl'

# Results backend configuration  
RESULTS_BACKEND = {
    'backend': 'db',
    'db_connection_pool_size': 10,
    'db_connection_pool_max_overflow': 5,
}

# CSV export encoding
CSV_EXPORT = {
    'encoding': 'utf-8',
}