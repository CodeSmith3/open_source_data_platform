#!/bin/bash
set -e
set -u

echo "Starting database initialization..."

# Create gemeente database and user
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE gemeente;
    CREATE USER gemeente WITH PASSWORD 'gemeente123';
    GRANT ALL PRIVILEGES ON DATABASE gemeente TO gemeente;
EOSQL

# Create superset database and user
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE superset;
    CREATE USER superset WITH PASSWORD 'superset123';
    GRANT ALL PRIVILEGES ON DATABASE superset TO superset;
EOSQL

# Create airflow database and user
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE airflow;
    CREATE USER airflow WITH PASSWORD 'airflow123';
    GRANT ALL PRIVILEGES ON DATABASE airflow TO airflow;
EOSQL

# Create keycloak database and user
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE keycloak;
    CREATE USER keycloak WITH PASSWORD 'keycloak123';
    GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
EOSQL

# Add PostGIS extensions to gemeente database
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "gemeente" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS postgis_topology;
EOSQL

echo "Database initialization complete!"
