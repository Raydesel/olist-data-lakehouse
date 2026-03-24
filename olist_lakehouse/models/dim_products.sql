{{ config(
    materialized='table',
    table_type='iceberg',
    format='parquet'
) }}

WITH source_products AS (
    SELECT * FROM base_products
),

source_translations AS (
    SELECT * FROM base_translations
)

SELECT 
    -- 1. Generate the Primary Key using ROW_NUMBER
    ROW_NUMBER() OVER(ORDER BY p.product_id) AS product_key,
    
    -- 2. Keep the original ID for joining later
    p.product_id,
    
    -- 3. Bring in the English translation
    COALESCE(t.product_category_name_english, 'Unknown') AS product_category_name_english,
    
    -- 4. Keep the product dimensions
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm

FROM source_products p
LEFT JOIN source_translations t 
    ON p.product_category_name = t.product_category_name
