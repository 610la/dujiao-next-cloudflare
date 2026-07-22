CREATE TABLE IF NOT EXISTS payments_next (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  payment_no TEXT NOT NULL UNIQUE,
  order_id INTEGER NOT NULL DEFAULT 0,
  user_id INTEGER NOT NULL DEFAULT 0,
  guest_email TEXT NOT NULL DEFAULT '',
  channel_id INTEGER NOT NULL DEFAULT 0,
  provider_type TEXT NOT NULL DEFAULT 'manual',
  channel_type TEXT NOT NULL DEFAULT 'manual',
  interaction_mode TEXT NOT NULL DEFAULT 'none',
  amount REAL NOT NULL DEFAULT 0,
  payable_amount REAL NOT NULL DEFAULT 0,
  fee_rate REAL NOT NULL DEFAULT 0,
  fixed_fee REAL NOT NULL DEFAULT 0,
  fee_amount REAL NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'CNY',
  status TEXT NOT NULL DEFAULT 'success',
  provider_trade_no TEXT NOT NULL DEFAULT '',
  provider_ref TEXT NOT NULL DEFAULT '',
  pay_url TEXT NOT NULL DEFAULT '',
  qr_code TEXT NOT NULL DEFAULT '',
  provider_payload_json TEXT NOT NULL DEFAULT '{}',
  paid_at TEXT,
  expired_at TEXT,
  callback_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT OR IGNORE INTO payments_next (
  id, payment_no, order_id, user_id, guest_email, channel_id, provider_type, channel_type,
  interaction_mode, amount, payable_amount, fee_rate, fixed_fee, fee_amount, currency,
  status, provider_trade_no, provider_ref, pay_url, qr_code, provider_payload_json,
  paid_at, expired_at, callback_at, created_at, updated_at
)
SELECT
  id, payment_no, order_id, user_id, guest_email, channel_id, provider_type, channel_type,
  interaction_mode, amount, payable_amount, fee_rate, fixed_fee, fee_amount, currency,
  status, provider_trade_no, provider_ref, pay_url, qr_code, provider_payload_json,
  paid_at, expired_at, NULL, created_at, updated_at
FROM payments;

DROP TABLE payments;
ALTER TABLE payments_next RENAME TO payments;

CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_user ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_channel ON payments(channel_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payments(created_at);
CREATE INDEX IF NOT EXISTS idx_payments_callback_at ON payments(callback_at);
CREATE INDEX IF NOT EXISTS idx_wallet_recharges_payment_id ON wallet_recharges(payment_id);
