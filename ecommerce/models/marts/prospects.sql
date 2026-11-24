SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    o.order_id
FROM {{ ref('stg_customers') }} AS c
LEFT JOIN {{ ref('stg_orders') }} AS o
    ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL