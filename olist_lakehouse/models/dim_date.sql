{{ config(
    materialized='table',
    table_type='iceberg',
    format='parquet'
) }}

WITH distinct_dates AS (
    -- Extract just the unique dates (no times) from the orders table
    SELECT DISTINCT DATE(order_purchase_timestamp) AS full_date
    FROM base_orders
    WHERE order_purchase_timestamp IS NOT NULL
)

SELECT 
    -- Create an integer key (e.g., 20180514) which is much faster for databases to join
    CAST(DATE_FORMAT(full_date, '%Y%m%d') AS INTEGER) AS date_key,
    
    full_date,
    EXTRACT(MONTH FROM full_date) AS month,
    EXTRACT(YEAR FROM full_date) AS year,
    EXTRACT(DAY_OF_WEEK FROM full_date) AS day_of_week

FROM distinct_dates
