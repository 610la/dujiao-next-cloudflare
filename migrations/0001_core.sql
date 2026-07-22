PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS admins (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL UNIQUE,
  password_salt TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  is_super INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS admin_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  admin_id INTEGER NOT NULL,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  parent_id INTEGER NOT NULL DEFAULT 0,
  slug TEXT NOT NULL UNIQUE,
  name_json TEXT NOT NULL,
  icon TEXT NOT NULL DEFAULT '',
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS products (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id INTEGER,
  slug TEXT NOT NULL UNIQUE,
  seo_meta_json TEXT NOT NULL DEFAULT '{}',
  title_json TEXT NOT NULL,
  description_json TEXT NOT NULL DEFAULT '{}',
  content_json TEXT NOT NULL DEFAULT '{}',
  instructions_json TEXT NOT NULL DEFAULT '{}',
  price_amount REAL NOT NULL DEFAULT 0,
  cost_price_amount REAL NOT NULL DEFAULT 0,
  images_json TEXT NOT NULL DEFAULT '[]',
  tags_json TEXT NOT NULL DEFAULT '[]',
  purchase_type TEXT NOT NULL DEFAULT 'guest',
  min_purchase_quantity INTEGER NOT NULL DEFAULT 1,
  max_purchase_quantity INTEGER NOT NULL DEFAULT 1,
  stock_display_mode TEXT NOT NULL DEFAULT 'exact',
  fulfillment_type TEXT NOT NULL DEFAULT 'manual',
  manual_form_schema_json TEXT NOT NULL DEFAULT '{"fields":[]}',
  manual_stock_total INTEGER NOT NULL DEFAULT -1,
  manual_stock_locked INTEGER NOT NULL DEFAULT 0,
  manual_stock_sold INTEGER NOT NULL DEFAULT 0,
  payment_channel_ids_json TEXT NOT NULL DEFAULT '[]',
  is_affiliate_enabled INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS product_skus (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  product_id INTEGER NOT NULL,
  sku_code TEXT NOT NULL,
  spec_values_json TEXT NOT NULL DEFAULT '{}',
  price_amount REAL NOT NULL DEFAULT 0,
  cost_price_amount REAL NOT NULL DEFAULT 0,
  manual_stock_total INTEGER NOT NULL DEFAULT -1,
  manual_stock_locked INTEGER NOT NULL DEFAULT 0,
  manual_stock_sold INTEGER NOT NULL DEFAULT 0,
  auto_stock_available INTEGER NOT NULL DEFAULT 0,
  auto_stock_total INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS orders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_no TEXT NOT NULL UNIQUE,
  parent_id INTEGER,
  user_id INTEGER NOT NULL DEFAULT 0,
  guest_email TEXT NOT NULL DEFAULT '',
  guest_locale TEXT NOT NULL DEFAULT 'zh-CN',
  status TEXT NOT NULL DEFAULT 'paid',
  currency TEXT NOT NULL DEFAULT 'CNY',
  original_amount REAL NOT NULL DEFAULT 0,
  discount_amount REAL NOT NULL DEFAULT 0,
  promotion_discount_amount REAL NOT NULL DEFAULT 0,
  wholesale_discount_amount REAL NOT NULL DEFAULT 0,
  member_discount_amount REAL NOT NULL DEFAULT 0,
  total_amount REAL NOT NULL DEFAULT 0,
  wallet_paid_amount REAL NOT NULL DEFAULT 0,
  online_paid_amount REAL NOT NULL DEFAULT 0,
  refunded_amount REAL NOT NULL DEFAULT 0,
  coupon_code TEXT NOT NULL DEFAULT '',
  client_ip TEXT NOT NULL DEFAULT '',
  expires_at TEXT,
  paid_at TEXT,
  canceled_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS order_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  sku_id INTEGER NOT NULL DEFAULT 0,
  title_json TEXT NOT NULL DEFAULT '{}',
  sku_snapshot_json TEXT NOT NULL DEFAULT '{}',
  quantity INTEGER NOT NULL DEFAULT 1,
  original_unit_price REAL NOT NULL DEFAULT 0,
  unit_price REAL NOT NULL DEFAULT 0,
  cost_price REAL NOT NULL DEFAULT 0,
  original_total_price REAL NOT NULL DEFAULT 0,
  total_price REAL NOT NULL DEFAULT 0,
  fulfillment_type TEXT NOT NULL DEFAULT 'manual',
  manual_form_schema_snapshot_json TEXT NOT NULL DEFAULT '{"fields":[]}',
  manual_form_submission_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(id),
  FOREIGN KEY (sku_id) REFERENCES product_skus(id)
);

CREATE TABLE IF NOT EXISTS fulfillments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL UNIQUE,
  type TEXT NOT NULL DEFAULT 'manual',
  status TEXT NOT NULL DEFAULT 'delivered',
  content TEXT NOT NULL DEFAULT '',
  delivery_data_json TEXT NOT NULL DEFAULT '{}',
  payload TEXT NOT NULL DEFAULT '',
  payload_line_count INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value_json TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_active ON products(is_active);
CREATE INDEX IF NOT EXISTS idx_skus_product ON product_skus(product_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);

INSERT OR IGNORE INTO settings (key, value_json)
VALUES
  ('site_config', '{"brand":{"site_name":"Dujiao Store","site_logo":"","site_icon":"","site_url":""},"seo":{"title":{"zh-CN":"Dujiao Store","zh-TW":"Dujiao Store","en-US":"Dujiao Store"},"keywords":{"zh-CN":"","zh-TW":"","en-US":""},"description":{"zh-CN":"","zh-TW":"","en-US":""}},"template_mode":"classic","currency":"CNY","captcha":{"provider":"none","scenes":{}},"scripts":{},"tenant":{"mode":"main"},"app_version":"cloudflare-port-1.0","server_time":0}'),
  ('order_config', '{"payment_expire_minutes":15,"max_refund_days":30}');
