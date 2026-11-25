CREATE SCHEMA raw;

CREATE TABLE raw.customers (
    customer_id INTEGER,
    first_name TEXT,
    last_name TEXT,
    email TEXT,
    created_at DATE
);

CREATE TABLE raw.orders (
    order_id INTEGER,
    customer_id INTEGER,
    order_date DATE,
    amount NUMERIC(8,2),
    status TEXT,
    row_hash TEXT
);

CREATE OR REPLACE FUNCTION raw.compute_order_hash()
RETURNS trigger AS $$
BEGIN
    NEW.row_hash := md5(
        concat_ws(
            '|',
            NEW.customer_id,
            NEW.order_date,
            NEW.amount,
            NEW.status
        )
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_compute_order_hash
BEFORE INSERT OR UPDATE ON raw.orders
FOR EACH ROW
EXECUTE FUNCTION raw.compute_order_hash();

INSERT INTO raw.customers VALUES
(1, 'Remi', 'Verschuur', 'remi@example.com', '2026-01-10'),
(2, 'Claire', 'Martin', 'claire.martin@example.com', '2026-02-14'),
(3, 'PAUL', 'Dupont', 'paul.dupont@example.com', '2026-03-02'),
(4, ' Sophie ', 'Bernard', 'sophie.bernard@example.com', '2026-03-18'),
(5, 'Lucas', 'Petit', NULL, '2026-04-01'),
(6, 'Emma', 'Lemoine', 'emma.lemoine@example.com', '2026-04-15');

INSERT INTO raw.orders VALUES
(1001, 1, '2026-04-02', 120.50, 'completed'),
(1002, 2, '2026-04-03', 79.90, 'completed'),
(1003, 1, '2026-04-05', 45.00, 'completed'),
(1004, 3, '2026-04-07', 210.00, 'pending'),
(1005, 4, '2026-04-09', 35.50, 'cancelled'),
(1006, 2, '2026-04-10', 89.99, 'completed'),
(1007, 5, '2026-04-11', 150.00, 'completed');
