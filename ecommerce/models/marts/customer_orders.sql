SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(o.order_id) AS order_count,
    SUM(o.amount) AS total_amount,
    MAX(o.order_date) AS last_order_date

FROM {{ ref('stg_customers') }} AS c

LEFT JOIN {{ ref('stg_orders') }} AS o
    ON c.customer_id = o.customer_id

GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name