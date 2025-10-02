#!/bin/bash
set -e
set -u

function create_user_and_database() {
    local database=$1
    local user=$2
    local password=$3
    
    echo "Creating user and database: $database"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$user') THEN
                CREATE USER $user WITH PASSWORD '$password';
            END IF;
        END
        \$\$;
        
        SELECT 'CREATE DATABASE $database OWNER $user'
        WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$database')\gexec
        
        GRANT ALL PRIVILEGES ON DATABASE $database TO $user;
EOSQL
}

if [ -n "${POSTGRES_MULTIPLE_DATABASES:-}" ]; then
    echo "Creating multiple databases..."
    
    for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
        case $db in
            gemeente)
                create_user_and_database "gemeente" "gemeente" "${POSTGRES_PASSWORD:-gemeente123}"
                ;;
            superset)
                create_user_and_database "superset" "superset" "superset123"
                ;;
            airflow)
                create_user_and_database "airflow" "airflow" "airflow123"
                ;;
            keycloak)
                create_user_and_database "keycloak" "keycloak" "keycloak123"
                ;;
        esac
    done
fi

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "gemeente" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS postgis;
    CREATE EXTENSION IF NOT EXISTS postgis_topology;
EOSQL

echo "Database initialization complete!"
