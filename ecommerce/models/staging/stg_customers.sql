SELECT
    CAST(customer_id AS INT) AS customer_id,
    TRIM(
        REGEXP_REPLACE(first_name, '\\s+', ' ', 'g')
    ) AS first_name,
    UPPER(
        TRIM(
            REGEXP_REPLACE(last_name, '\\s+', ' ', 'g')
        )
    ) AS last_name,
    LOWER(TRIM(email)) AS email,
    created_at
FROM {{ source('ecommerce', 'customers') }}