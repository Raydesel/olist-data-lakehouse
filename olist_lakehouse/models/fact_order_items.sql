{{ config(
    materialized='table',
    table_type='iceberg',
    format='parquet'
) }}

WITH source_items AS (
    SELECT * FROM base_order_items
),
source_orders AS (
    SELECT * FROM base_orders
),

-- Reference all our clean dimension tables!
dim_cust AS ( SELECT * FROM {{ ref('dim_customers') }} ),
dim_prod AS ( SELECT * FROM {{ ref('dim_products') }} ),
dim_sell AS ( SELECT * FROM {{ ref('dim_sellers') }} ),
dim_date AS ( SELECT * FROM {{ ref('dim_date') }} )

SELECT 
    -- 1. Generate the Fact Key
    ROW_NUMBER() OVER(ORDER BY i.order_id, i.order_item_id) AS fact_key,

    -- 2. Keep the original Order ID
    i.order_id,
    i.order_item_id AS order_item_sequence_id,

    -- 3. Grab the Surrogate Keys from our Dimensions
    c.customer_key,
    p.product_key,
    s.seller_key,
    d.date_key AS order_purchase_date_key,

    -- 4. The core metrics (Facts)
    i.price,
    i.freight_value

FROM source_items i

-- First, join the Orders table so we know WHO bought it and WHEN
LEFT JOIN source_orders o 
    ON i.order_id = o.order_id

-- Next, join the Dimensions to swap out the messy string IDs for our clean Keys
LEFT JOIN dim_cust c 
    ON o.customer_id = c.customer_id
LEFT JOIN dim_prod p 
    ON i.product_id = p.product_id
LEFT JOIN dim_sell s 
    ON i.seller_id = s.seller_id
LEFT JOIN dim_date d 
    ON CAST(DATE_FORMAT(DATE(o.order_purchase_timestamp), '%Y%m%d') AS INTEGER) = d.date_key
