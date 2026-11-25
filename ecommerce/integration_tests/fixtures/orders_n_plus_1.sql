UPDATE integration_raw.orders
SET
    status = 'completed',
    row_hash = 'hash_9902_v2'
WHERE order_id = 9902;

INSERT INTO integration_raw.orders (
    order_id,
    customer_id,
    order_date,
    amount,
    status,
    row_hash
)
VALUES (
    9903,
    3,
    '2026-11-21',
    42.00,
    'completed',
    'hash_9903_v1'
);