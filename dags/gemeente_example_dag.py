"""
Example DAG for Gemeente Data Platform
Demonstrates basic Airflow functionality with SSO
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook

default_args = {
    'owner': 'gemeente',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

def hello_gemeente():
    """Simple hello function"""
    print("=" * 50)
    print("Hello from Gemeente Data Platform!")
    print("Airflow with SSO is working!")
    print("=" * 50)
    return "Success"

def check_connections():
    """Check available connections"""
    from airflow.models import Connection
    from airflow.settings import Session
    
    session = Session()
    connections = session.query(Connection).all()
    
    print("\n" + "=" * 50)
    print("Available Connections:")
    print("=" * 50)
    for conn in connections:
        print(f"  - {conn.conn_id} ({conn.conn_type})")
    print("=" * 50 + "\n")
    
    session.close()
    return len(connections)

def test_postgres():
    """Test PostgreSQL connection"""
    try:
        pg_hook = PostgresHook(postgres_conn_id='postgres_default')
        
        # Test query
        records = pg_hook.get_records("SELECT version();")
        
        print("\n" + "=" * 50)
        print("PostgreSQL Connection Test:")
        print("=" * 50)
        print(f"Version: {records[0][0]}")
        print("✔ PostgreSQL connection working!")
        print("=" * 50 + "\n")
        
        return True
    except Exception as e:
        print(f"✗ PostgreSQL connection failed: {e}")
        return False

with DAG(
    'gemeente_example_dag',
    default_args=default_args,
    description='Example DAG for Gemeente platform',
    schedule_interval=timedelta(days=1),
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['example', 'gemeente', 'tutorial'],
) as dag:

    # Task 1: Hello
    hello_task = PythonOperator(
        task_id='hello_gemeente',
        python_callable=hello_gemeente,
    )

    # Task 2: Check connections
    check_connections_task = PythonOperator(
        task_id='check_connections',
        python_callable=check_connections,
    )

    # Task 3: System info
    system_info_task = BashOperator(
        task_id='system_info',
        bash_command='echo "Hostname: $(hostname)" && echo "Date: $(date)" && echo "User: $(whoami)"',
    )

    # Task 4: Test PostgreSQL
    test_postgres_task = PythonOperator(
        task_id='test_postgres',
        python_callable=test_postgres,
    )

    # Task 5: List files
    list_files_task = BashOperator(
        task_id='list_dags',
        bash_command='echo "DAG files:" && ls -lh /opt/airflow/dags/',
    )

    # Define task dependencies
    hello_task >> [check_connections_task, system_info_task]
    check_connections_task >> test_postgres_task
    system_info_task >> list_files_task
    test_postgres_task >> list_files_task
