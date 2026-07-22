CREATE UNIQUE INDEX IF NOT EXISTS idx_wallet_transactions_order_payment_once
ON wallet_transactions(user_id, order_id)
WHERE type = 'order_payment' AND order_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_wallet_transactions_recharge_once
ON wallet_transactions(related_type, related_id)
WHERE type = 'recharge' AND related_type = 'wallet_recharge' AND related_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_wallet_transactions_cancel_refund_once
ON wallet_transactions(user_id, order_id, reference)
WHERE type = 'order_refund' AND order_id IS NOT NULL AND reference LIKE '%:cancel';
