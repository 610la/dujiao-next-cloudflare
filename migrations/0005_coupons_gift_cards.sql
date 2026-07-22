CREATE TABLE IF NOT EXISTS coupons (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  code TEXT NOT NULL UNIQUE,
  type TEXT NOT NULL DEFAULT 'fixed',
  value REAL NOT NULL DEFAULT 0,
  min_amount REAL NOT NULL DEFAULT 0,
  max_discount REAL NOT NULL DEFAULT 0,
  usage_limit INTEGER NOT NULL DEFAULT 0,
  used_count INTEGER NOT NULL DEFAULT 0,
  per_user_limit INTEGER NOT NULL DEFAULT 0,
  payment_roles_json TEXT NOT NULL DEFAULT '[]',
  member_levels_json TEXT NOT NULL DEFAULT '[]',
  scope_type TEXT NOT NULL DEFAULT 'product',
  scope_ref_ids_json TEXT NOT NULL DEFAULT '[]',
  starts_at TEXT,
  ends_at TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS coupon_usages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  coupon_id INTEGER NOT NULL,
  coupon_code TEXT NOT NULL,
  coupon_type TEXT NOT NULL,
  order_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL DEFAULT 0,
  guest_email TEXT NOT NULL DEFAULT '',
  product_ids_json TEXT NOT NULL DEFAULT '[]',
  discount_amount REAL NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (coupon_id) REFERENCES coupons(id) ON DELETE CASCADE,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS gift_card_batches (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  batch_no TEXT NOT NULL UNIQUE,
  total_count INTEGER NOT NULL DEFAULT 0,
  amount REAL NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'CNY',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS gift_cards (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  batch_id INTEGER,
  name TEXT NOT NULL,
  code TEXT NOT NULL UNIQUE,
  amount REAL NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'CNY',
  status TEXT NOT NULL DEFAULT 'active',
  expires_at TEXT,
  redeemed_at TEXT,
  redeemed_user_id INTEGER,
  wallet_txn_id INTEGER,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (batch_id) REFERENCES gift_card_batches(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_coupons_code ON coupons(code);
CREATE INDEX IF NOT EXISTS idx_coupons_active ON coupons(is_active);
CREATE INDEX IF NOT EXISTS idx_coupon_usages_coupon ON coupon_usages(coupon_id);
CREATE INDEX IF NOT EXISTS idx_coupon_usages_order ON coupon_usages(order_id);
CREATE INDEX IF NOT EXISTS idx_gift_cards_code ON gift_cards(code);
CREATE INDEX IF NOT EXISTS idx_gift_cards_status ON gift_cards(status);
CREATE INDEX IF NOT EXISTS idx_gift_cards_batch ON gift_cards(batch_id);

ALTER TABLE order_items ADD COLUMN coupon_discount_amount REAL NOT NULL DEFAULT 0;
