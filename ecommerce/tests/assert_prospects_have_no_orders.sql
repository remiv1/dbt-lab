SELECT
    p.customer_id,
    p.first_name,
    p.last_name,
    o.order_id

FROM {{ ref('prospects') }} AS p

INNER JOIN {{ ref('stg_orders') }} AS o
    ON p.customer_id = o.customer_id
