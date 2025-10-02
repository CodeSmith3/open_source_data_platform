from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
import requests
from requests.auth import HTTPBasicAuth
import json

default_args = {
    'owner': 'gemeente',
    'depends_on_past': False,
    'start_date': datetime(2025, 9, 30),
    'email_on_failure': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'topdesk_departments_sync',
    default_args=default_args,
    description='Sync TOPdesk Departments to PostgreSQL',
    schedule_interval=None,  # Manual trigger
    catchup=False,
    tags=['topdesk', 'etl'],
)

def extract_topdesk_data(**context):
    """Extract data from TOPdesk OData API"""
    
    # VERVANG WACHTWOORD HIERONDER MET VOLLEDIG WACHTWOORD
    TOPDESK_URL = "https://klantportaal.syntrophos.nl/services/reporting/v2/odata/Departments"
    TOPDESK_USER = "SRV-API-RAPPORTAGE"
    TOPDESK_PASS = "get4e-zenjv-4m3vi-a7w67-jzvag"  # VERVANG MET VOLLEDIG WACHTWOORD
    
    print(f"Fetching from {TOPDESK_URL}")
    
    response = requests.get(
        TOPDESK_URL,
        auth=HTTPBasicAuth(TOPDESK_USER, TOPDESK_PASS),
        headers={'Accept': 'application/json'},
        timeout=30
    )
    response.raise_for_status()
    
    data = response.json()
    records = data.get('value', data)
    
    print(f"Extracted {len(records)} records")
    context['task_instance'].xcom_push(key='topdesk_data', value=records)
    
    return len(records)

def load_to_postgres(**context):
    """Load data to PostgreSQL"""
    
    ti = context['task_instance']
    records = ti.xcom_pull(task_ids='extract_topdesk', key='topdesk_data')
    
    if not records:
        raise ValueError("No data to load")
    
    # Use postgres connection
    pg_hook = PostgresHook(postgres_conn_id='postgres_default')
    conn = pg_hook.get_conn()
    cursor = conn.cursor()
    
    print("Creating table...")
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS topdesk_departments (
            id SERIAL PRIMARY KEY,
            dept_id TEXT,
            name TEXT,
            description TEXT,
            external_number TEXT,
            archived BOOLEAN,
            raw_data JSONB,
            loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    print("Truncating old data...")
    cursor.execute("TRUNCATE TABLE topdesk_departments RESTART IDENTITY")
    
    print(f"Inserting {len(records)} records...")
    inserted = 0
    for record in records:
        cursor.execute("""
            INSERT INTO topdesk_departments 
            (dept_id, name, description, external_number, archived, raw_data)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (
            record.get('id'),
            record.get('name'),
            record.get('description'),
            record.get('externalNumber'),
            record.get('archived', False),
            json.dumps(record)
        ))
        inserted += 1
    
    conn.commit()
    cursor.close()
    
    print(f"Successfully loaded {inserted} records")
    return inserted

# Define tasks
extract_task = PythonOperator(
    task_id='extract_topdesk',
    python_callable=extract_topdesk_data,
    dag=dag,
)

load_task = PythonOperator(
    task_id='load_postgres',
    python_callable=load_to_postgres,
    dag=dag,
)

# Dependencies
extract_task >> load_task
