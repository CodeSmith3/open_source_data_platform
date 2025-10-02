#!/bin/bash
set -e
echo "Initialiseer databases..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE airflow;
    CREATE DATABASE keycloak;  
    CREATE DATABASE datahub;
    GRANT ALL PRIVILEGES ON DATABASE airflow TO $POSTGRES_USER;
    GRANT ALL PRIVILEGES ON DATABASE keycloak TO $POSTGRES_USER;
    GRANT ALL PRIVILEGES ON DATABASE datahub TO $POSTGRES_USER;
EOSQL