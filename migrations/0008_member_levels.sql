CREATE TABLE IF NOT EXISTS member_levels (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name_json TEXT NOT NULL DEFAULT '{}',
  slug TEXT NOT NULL UNIQUE,
  icon TEXT NOT NULL DEFAULT '',
  discount_rate REAL NOT NULL DEFAULT 100,
  recharge_threshold REAL NOT NULL DEFAULT 0,
  spend_threshold REAL NOT NULL DEFAULT 0,
  is_default INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_member_levels_active ON member_levels(is_active);
CREATE INDEX IF NOT EXISTS idx_member_levels_sort ON member_levels(sort_order);

CREATE TABLE IF NOT EXISTS member_level_prices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  member_level_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  sku_id INTEGER NOT NULL DEFAULT 0,
  price_amount REAL NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(member_level_id, product_id, sku_id),
  FOREIGN KEY (member_level_id) REFERENCES member_levels(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_member_level_prices_product ON member_level_prices(product_id);
CREATE INDEX IF NOT EXISTS idx_member_level_prices_level ON member_level_prices(member_level_id);
