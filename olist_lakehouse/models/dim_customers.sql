{{ config(
    materialized='table',
    table_type='iceberg',
    format='parquet'
) }}

WITH source_customers AS (
    SELECT * FROM base_customers
),

-- THE MAGIC IS HERE: Notice we are not querying 'base_geolocation'. 
-- We are using dbt's ref() function to query the model we JUST built above!
geo_table AS (
    SELECT * FROM {{ ref('dim_geolocation') }}
)

SELECT 
    -- 1. Generate the Primary Key for the customer
    ROW_NUMBER() OVER(ORDER BY c.customer_id) AS customer_key,
    
    -- 2. Grab the Foreign Key from our new dim_geolocation table
    g.geolocation_key,
    
    -- 3. Keep the original customer_id (We need this later to join to the Orders table!)
    c.customer_id,
    c.customer_unique_id,
    
    -- 4. Customer attributes
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state

FROM source_customers c
LEFT JOIN geo_table g 
    ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix
