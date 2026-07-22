ALTER TABLE orders ADD COLUMN checkout_request_id TEXT NOT NULL DEFAULT '';

CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_checkout_request_id
ON orders(checkout_request_id)
WHERE parent_id IS NULL AND checkout_request_id <> '';
