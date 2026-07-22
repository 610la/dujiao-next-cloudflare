CREATE TABLE IF NOT EXISTS order_refunds (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL DEFAULT 0,
  guest_email TEXT NOT NULL DEFAULT '',
  guest_locale TEXT NOT NULL DEFAULT 'zh-CN',
  type TEXT NOT NULL DEFAULT 'manual',
  amount REAL NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'CNY',
  remark TEXT NOT NULL DEFAULT '',
  items_json TEXT NOT NULL DEFAULT '[]',
  wallet_txn_id INTEGER,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_order_refunds_order ON order_refunds(order_id);
CREATE INDEX IF NOT EXISTS idx_order_refunds_user ON order_refunds(user_id);
CREATE INDEX IF NOT EXISTS idx_order_refunds_type ON order_refunds(type);
CREATE INDEX IF NOT EXISTS idx_order_refunds_created_at ON order_refunds(created_at);
