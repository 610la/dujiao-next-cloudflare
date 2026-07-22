CREATE TABLE IF NOT EXISTS wallet_adjustments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  idempotency_key TEXT NOT NULL UNIQUE,
  user_id INTEGER NOT NULL,
  order_id INTEGER,
  type TEXT NOT NULL,
  direction TEXT NOT NULL,
  amount REAL NOT NULL,
  currency TEXT NOT NULL DEFAULT 'CNY',
  reference TEXT NOT NULL DEFAULT '',
  remark TEXT NOT NULL DEFAULT '',
  related_type TEXT NOT NULL DEFAULT '',
  related_id INTEGER,
  wallet_txn_id INTEGER,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (wallet_txn_id) REFERENCES wallet_transactions(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_wallet_adjustments_user_id
ON wallet_adjustments(user_id, created_at);

CREATE TRIGGER IF NOT EXISTS trg_wallet_adjustments_validate
BEFORE INSERT ON wallet_adjustments
BEGIN
  SELECT CASE
    WHEN ROUND(NEW.amount, 2) <= 0 THEN RAISE(ABORT, 'wallet_adjustment_invalid')
    WHEN NEW.direction NOT IN ('in', 'out') THEN RAISE(ABORT, 'wallet_adjustment_invalid')
    WHEN NOT EXISTS (
      SELECT 1 FROM user_wallets WHERE user_id = NEW.user_id
    ) THEN RAISE(ABORT, 'wallet_adjustment_wallet_missing')
    WHEN NEW.direction = 'out' AND ROUND(NEW.amount, 2) > ROUND((
      SELECT balance FROM user_wallets WHERE user_id = NEW.user_id
    ), 2) THEN RAISE(ABORT, 'wallet_adjustment_insufficient')
  END;
END;

CREATE TRIGGER IF NOT EXISTS trg_wallet_adjustments_apply
AFTER INSERT ON wallet_adjustments
BEGIN
  UPDATE user_wallets
  SET balance = ROUND(
        balance + CASE WHEN NEW.direction = 'in' THEN NEW.amount ELSE -NEW.amount END ,
        2
      ),
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
    NEW.type,
    NEW.direction,
    ROUND(NEW.amount, 2),
    ROUND(balance + CASE WHEN NEW.direction = 'in' THEN -NEW.amount ELSE NEW.amount END , 2),
    ROUND(balance, 2),
    NEW.currency,
    NEW.reference,
    NEW.remark,
    NEW.related_type,
    NEW.related_id
  FROM user_wallets
  WHERE user_id = NEW.user_id;

  UPDATE wallet_adjustments
  SET wallet_txn_id = last_insert_rowid(),
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.id;
END;

INSERT INTO settings(key, value_json)
VALUES ('atomic_wallet_adjustments_enabled', 'false')
ON CONFLICT(key) DO NOTHING;
