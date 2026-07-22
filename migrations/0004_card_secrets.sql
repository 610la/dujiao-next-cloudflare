CREATE TABLE IF NOT EXISTS card_secret_batches (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id INTEGER NOT NULL,
  sku_id INTEGER NOT NULL DEFAULT 0,
  name TEXT NOT NULL DEFAULT '',
  batch_no TEXT NOT NULL DEFAULT '',
  source TEXT NOT NULL DEFAULT 'manual',
  note TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  FOREIGN KEY (sku_id) REFERENCES product_skus(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS card_secrets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id INTEGER NOT NULL,
  sku_id INTEGER NOT NULL DEFAULT 0,
  batch_id INTEGER,
  secret TEXT NOT NULL,
  secret_hash TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'available',
  order_id INTEGER,
  reserved_at TEXT,
  used_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  FOREIGN KEY (sku_id) REFERENCES product_skus(id) ON DELETE CASCADE,
  FOREIGN KEY (batch_id) REFERENCES card_secret_batches(id) ON DELETE SET NULL,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_card_secret_batches_product ON card_secret_batches(product_id, sku_id);
CREATE INDEX IF NOT EXISTS idx_card_secret_batches_batch_no ON card_secret_batches(batch_no);
CREATE INDEX IF NOT EXISTS idx_card_secrets_product_sku_status ON card_secrets(product_id, sku_id, status);
CREATE INDEX IF NOT EXISTS idx_card_secrets_batch ON card_secrets(batch_id);
CREATE INDEX IF NOT EXISTS idx_card_secrets_order ON card_secrets(order_id);
CREATE INDEX IF NOT EXISTS idx_card_secrets_hash ON card_secrets(product_id, sku_id, secret_hash);
