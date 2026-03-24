{{ config(
    materialized='table',
    table_type='iceberg',
    format='parquet'
) }}

WITH source_geo AS (
    SELECT * FROM base_geolocation
)

SELECT 
    -- 1. Generate the Primary Key
    ROW_NUMBER() OVER(ORDER BY geolocation_zip_code_prefix) AS geolocation_key,
    
    -- 2. Keep the original prefix for joining
    geolocation_zip_code_prefix,
    
    -- 3. Geo attributes
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state

FROM source_geo
