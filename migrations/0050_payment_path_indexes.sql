-- Composite indexes for the checkout, payment and callback hot paths.
CREATE INDEX IF NOT EXISTS idx_orders_parent_id_id
ON orders(parent_id, id);

CREATE INDEX IF NOT EXISTS idx_orders_user_parent_status
ON orders(user_id, parent_id, status);

CREATE INDEX IF NOT EXISTS idx_orders_client_ip_parent_status
ON orders(client_ip, parent_id, status);

CREATE INDEX IF NOT EXISTS idx_orders_guest_email_parent_status
ON orders(lower(guest_email), parent_id, status);

CREATE INDEX IF NOT EXISTS idx_order_items_order_product
ON order_items(order_id, product_id);

CREATE INDEX IF NOT EXISTS idx_payments_order_channel_id
ON payments(order_id, channel_id, id DESC);

CREATE INDEX IF NOT EXISTS idx_payments_channel_provider_ref_id
ON payments(channel_id, provider_ref, id DESC);

CREATE INDEX IF NOT EXISTS idx_payment_channels_active_sort
ON payment_channels(is_active, sort_order, id);

CREATE INDEX IF NOT EXISTS idx_wallet_recharges_status_created
ON wallet_recharges(status, created_at, id);
