CREATE TRIGGER IF NOT EXISTS trg_order_refunds_validate
BEFORE INSERT ON order_refunds
BEGIN
  SELECT CASE
    WHEN NEW.amount <= 0 THEN RAISE(ABORT, 'refund_amount_invalid')
    WHEN NEW.type NOT IN ('wallet', 'manual') THEN RAISE(ABORT, 'refund_type_invalid')
    WHEN NOT EXISTS (SELECT 1 FROM orders WHERE id = NEW.order_id) THEN RAISE(ABORT, 'refund_order_missing')
    WHEN NOT EXISTS (
      SELECT 1
      FROM orders
      WHERE id = NEW.order_id
        AND (paid_at IS NOT NULL OR status IN ('paid', 'fulfilling', 'partially_delivered', 'delivered', 'completed', 'partially_refunded'))
    ) THEN RAISE(ABORT, 'refund_order_unpaid')
    WHEN NEW.type = 'wallet' AND NOT EXISTS (
      SELECT 1 FROM orders WHERE id = NEW.order_id AND user_id > 0 AND user_id = NEW.user_id
    ) THEN RAISE(ABORT, 'refund_wallet_user_invalid')
    WHEN ROUND(NEW.amount, 2) > (
      SELECT ROUND(MAX(0, total_amount - refunded_amount), 2)
      FROM orders
      WHERE id = NEW.order_id
    ) THEN RAISE(ABORT, 'refund_amount_exceeded')
  END;
END;

CREATE TRIGGER IF NOT EXISTS trg_order_refunds_apply_order
AFTER INSERT ON order_refunds
BEGIN
  UPDATE orders
  SET refunded_amount = ROUND(refunded_amount + NEW.amount, 2),
      status = CASE
        WHEN ROUND(refunded_amount + NEW.amount, 2) >= ROUND(total_amount, 2) THEN 'refunded'
        ELSE 'partially_refunded'
      END ,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.order_id;
END;

CREATE TRIGGER IF NOT EXISTS trg_order_refunds_apply_wallet
AFTER INSERT ON order_refunds
WHEN NEW.type = 'wallet'
BEGIN
  INSERT OR IGNORE INTO user_wallets (user_id, balance, currency)
  VALUES (NEW.user_id, 0, NEW.currency);

  UPDATE user_wallets
  SET balance = ROUND(balance + NEW.amount, 2),
      updated_at = CURRENT_TIMESTAMP
  WHERE user_id = NEW.user_id;

  INSERT INTO wallet_transactions (
    user_id, order_id, type, direction, amount,
    balance_before, balance_after, currency,
    reference, remark, related_type, related_id
  )
  SELECT
    NEW.user_id,
    NEW.order_id,
    'order_refund',
    'in',
    ROUND(NEW.amount, 2),
    ROUND(balance - NEW.amount, 2),
    ROUND(balance, 2),
    NEW.currency,
    'REFUND:' || NEW.id,
    CASE WHEN NEW.remark <> '' THEN NEW.remark ELSE '订单退款' END ,
    'order_refund',
    NEW.id
  FROM user_wallets
  WHERE user_id = NEW.user_id;

  UPDATE order_refunds
  SET wallet_txn_id = last_insert_rowid(),
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.id;
END;

CREATE UNIQUE INDEX IF NOT EXISTS idx_wallet_transactions_atomic_refund
ON wallet_transactions(reference)
WHERE type = 'order_refund' AND reference LIKE 'REFUND:%';
