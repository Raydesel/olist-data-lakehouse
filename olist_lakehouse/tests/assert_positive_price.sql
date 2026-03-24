-- This test will FAIL if it finds any rows where the price is less than 0
SELECT 
    order_id, 
    price
FROM {{ ref('fact_order_items') }}
WHERE price < 0
