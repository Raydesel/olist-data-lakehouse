{{ config(
    materialized='table',
    table_type='iceberg',
    format='parquet'
) }}

WITH source_sellers AS (
    SELECT * FROM base_sellers
),

geo_table AS (
    SELECT * FROM {{ ref('dim_geolocation') }}
)

SELECT 
    -- 1. Generate Primary Key
    ROW_NUMBER() OVER(ORDER BY s.seller_id) AS seller_key,
    
    -- 2. Foreign Key to Geolocation
    g.geolocation_key,
    
    -- 3. Original ID and attributes
    s.seller_id,
    s.seller_city,
    s.seller_state

FROM source_sellers s
LEFT JOIN geo_table g 
    ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix
