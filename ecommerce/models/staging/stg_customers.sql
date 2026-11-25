SELECT
    CAST(customer_id AS INT) AS customer_id,
    {{ normalize_text('first_name', case='upper') }} AS first_name,
    {{ normalize_text('last_name', case='upper') }} AS last_name,
    {{ normalize_text('email', case='lower', remove_spaces=true) }} AS email,
    created_at
FROM {{ source('ecommerce', 'customers') }}