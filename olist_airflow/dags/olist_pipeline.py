from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.amazon.aws.operators.glue import GlueJobOperator
from airflow.operators.bash import BashOperator

# 1. Pipeline Configuration
default_args = {
    'owner': 'data_engineer',
    'depends_on_past': False,
    'start_date': datetime(2026, 3, 20),
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# 2. Define the DAG
with DAG(
    'olist_lakehouse_pipeline',
    default_args=default_args,
    description='Orchestrates the Olist Lakehouse: Glue (EL) -> dbt (T)',
    schedule='@daily', # Run this automatically every day!
    catchup=False
) as dag:

    # Task 1: Run the PySpark Job in AWS Glue
    # This replaces you typing `aws glue start-job-run` in the terminal
    run_glue_job = GlueJobOperator(
        task_id='run_glue_base_tables',
        job_name='olist_iceberg_clean_and_convert',
        script_location='s3://olist-transformation-zone-4adb3345/scripts/iceberg_transform.py',
        s3_bucket='olist-transformation-zone-4adb3345',
        iam_role_name='olist_glue_service_role',
        region_name='us-east-1',
        wait_for_completion=True # MAGIC: Airflow automatically polls AWS until the job turns Green!
    )

    # Task 2: Run dbt to build the Star Schema in Athena
    # This replaces you typing `dbt run` and `dbt test` in the terminal
    run_dbt_models = BashOperator(
        task_id='build_and_test_star_schema',
        bash_command='cd /path/to/your/olist_lakehouse && dbt run && dbt test'
    )

    # 3. Define the Pipeline Order (Dependencies)
    run_glue_job >> run_dbt_models