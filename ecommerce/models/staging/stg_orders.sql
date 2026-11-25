SELECT
    CAST(order_id AS INT) AS order_id,
    CAST(customer_id AS INT) AS customer_id,
    CAST(order_date AS DATE) AS order_date,
    CAST(amount AS NUMERIC(8, 2)) AS amount,
    LOWER(TRIM(status)) AS status,
    row_hash
FROM {{ source('ecommerce', 'orders') }}
