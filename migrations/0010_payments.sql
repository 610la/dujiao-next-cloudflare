CREATE TABLE IF NOT EXISTS payment_channels (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL DEFAULT '',
  provider_type TEXT NOT NULL DEFAULT 'manual',
  channel_type TEXT NOT NULL DEFAULT 'manual',
  interaction_mode TEXT NOT NULL DEFAULT 'none',
  fee_rate REAL NOT NULL DEFAULT 0,
  fixed_fee REAL NOT NULL DEFAULT 0,
  min_amount REAL NOT NULL DEFAULT 0,
  max_amount REAL NOT NULL DEFAULT 0,
  hide_amount_out_range INTEGER NOT NULL DEFAULT 0,
  payment_types_json TEXT NOT NULL DEFAULT '[]',
  payment_roles_json TEXT NOT NULL DEFAULT '[]',
  member_levels_json TEXT NOT NULL DEFAULT '[]',
  config_json TEXT NOT NULL DEFAULT '{}',
  icon TEXT NOT NULL DEFAULT '',
  is_active INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 100,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_payment_channels_provider ON payment_channels(provider_type);
CREATE INDEX IF NOT EXISTS idx_payment_channels_type ON payment_channels(channel_type);
CREATE INDEX IF NOT EXISTS idx_payment_channels_active ON payment_channels(is_active);

CREATE TABLE IF NOT EXISTS payments (
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
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_user ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_channel ON payments(channel_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
CREATE INDEX IF NOT EXISTS idx_payments_created_at ON payments(created_at);
