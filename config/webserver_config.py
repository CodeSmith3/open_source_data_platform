# -*- coding: utf-8 -*-
#
# Airflow Webserver Configuration with Keycloak SSO
#

import os
from flask_appbuilder.security.manager import AUTH_OAUTH
from airflow.www.security import AirflowSecurityManager

# Base configuration
basedir = os.path.abspath(os.path.dirname(__file__))

# Flask-WTF flag for CSRF
WTF_CSRF_ENABLED = True
WTF_CSRF_TIME_LIMIT = None

# Authentication Type
AUTH_TYPE = AUTH_OAUTH

# OAuth Configuration
OAUTH_PROVIDERS = [{
    'name': 'keycloak',
    'icon': 'fa-key',
    'token_key': 'access_token',
    'remote_app': {
        'client_id': os.environ.get('AIRFLOW_OIDC_CLIENT_ID', 'airflow'),
        'client_secret': os.environ.get('AIRFLOW_OIDC_CLIENT_SECRET', 'airflow-client-secret'),
        'api_base_url': os.environ.get('KEYCLOAK_URL', 'http://192.168.1.25:8085') + '/realms/' + os.environ.get('KEYCLOAK_REALM', 'gemeente') + '/protocol/openid-connect',
        'client_kwargs': {
            'scope': 'openid email profile'
        },
        'access_token_url': os.environ.get('AIRFLOW_OIDC_TOKEN_URL'),
        'authorize_url': os.environ.get('AIRFLOW_OIDC_AUTHORIZE_URL'),
        'request_token_url': None,
        'jwks_uri': os.environ.get('AIRFLOW_OIDC_JWKS_URL'),
    }
}]

# Custom Security Manager for role mapping
class CustomSecurityManager(AirflowSecurityManager):
    def oauth_user_info(self, provider, response=None):
        if provider == 'keycloak':
            # Get user info from Keycloak
            me = self.appbuilder.sm.oauth_remotes[provider].get('userinfo')
            data = me.json()
            
            # Extract user information
            return {
                'username': data.get('preferred_username', ''),
                'email': data.get('email', ''),
                'first_name': data.get('given_name', ''),
                'last_name': data.get('family_name', ''),
                'role_keys': data.get('roles', [])  # Keycloak roles
            }

# Override the security manager class
SECURITY_MANAGER_CLASS = CustomSecurityManager

# Role mapping from Keycloak roles to Airflow roles
AUTH_ROLES_MAPPING = {
    'data-admin': ['Admin'],
    'data-engineer': ['Op'],
    'data-analyst': ['User'],
    'viewer': ['Viewer'],
}

# Automatically sync roles from OAuth provider
AUTH_ROLES_SYNC_AT_LOGIN = True

# Allow users to self-register (they get Public role by default)
AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = "Viewer"

# If you want to allow users to self-register with a specific role
# uncomment and adjust:
# AUTH_USER_REGISTRATION_ROLE = "Viewer"

# Optionally, set a fallback role if the user has no mapped roles
# This gives them at least viewer access
AUTH_USER_REGISTRATION_ROLE_JMESPATH = "contains(['data-admin', 'data-engineer', 'data-analyst', 'viewer'], role_keys[0]) || 'Viewer'"
