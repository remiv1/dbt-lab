DROP SCHEMA IF EXISTS integration_raw CASCADE;
CREATE SCHEMA integration_raw;

CREATE TABLE integration_raw.orders (
    order_id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    order_date DATE NOT NULL,
    amount NUMERIC(8,2) NOT NULL,
    status TEXT NOT NULL,
    row_hash TEXT NOT NULL
);

INSERT INTO integration_raw.orders (
    order_id,
    customer_id,
    order_date,
    amount,
    status,
    row_hash
)
VALUES
    (
        9901,
        1,
        '2026-11-20',
        100.00,
        'completed',
        'hash_9901_v1'
    ),
    (
        9902,
        2,
        '2026-11-20',
        75.50,
        'pending',
        'hash_9902_v1'
    );