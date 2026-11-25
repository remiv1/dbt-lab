{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='merge'
    )
}}

SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    o.amount,
    o.status,
    o.row_hash

FROM {{ ref('stg_orders') }} AS o

{% if is_incremental() %}

WHERE NOT EXISTS (
    SELECT 1
    FROM {{ this }} AS current_orders
    WHERE current_orders.order_id = o.order_id
      AND current_orders.row_hash = o.row_hash
)

{% endif %}