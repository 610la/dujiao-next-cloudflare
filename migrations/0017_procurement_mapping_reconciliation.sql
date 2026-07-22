ALTER TABLE api_credentials ADD COLUMN name TEXT NOT NULL DEFAULT 'Default API Key';
ALTER TABLE api_credentials ADD COLUMN secret_hash TEXT NOT NULL DEFAULT '';
ALTER TABLE api_credentials ADD COLUMN secret_tail TEXT NOT NULL DEFAULT '';
ALTER TABLE api_credentials ADD COLUMN permissions_json TEXT NOT NULL DEFAULT '["orders:read","orders:create"]';
ALTER TABLE api_credentials ADD COLUMN ip_whitelist_json TEXT NOT NULL DEFAULT '[]';
ALTER TABLE api_credentials ADD COLUMN rate_limit INTEGER NOT NULL DEFAULT 60;

CREATE TABLE IF NOT EXISTS product_mappings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  connection_id INTEGER NOT NULL,
  local_product_id INTEGER NOT NULL,
  upstream_product_id INTEGER NOT NULL,
  upstream_sku_id INTEGER NOT NULL DEFAULT 0,
  upstream_product_name TEXT NOT NULL DEFAULT '',
  upstream_sku_name TEXT NOT NULL DEFAULT '',
  upstream_price REAL NOT NULL DEFAULT 0,
  upstream_currency TEXT NOT NULL DEFAULT 'CNY',
  upstream_status TEXT NOT NULL DEFAULT 'active',
  upstream_payload_json TEXT NOT NULL DEFAULT '{}',
  is_active INTEGER NOT NULL DEFAULT 1,
  last_sync_at TEXT,
  last_sync_status TEXT NOT NULL DEFAULT '',
  last_sync_message TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (connection_id) REFERENCES site_connections(id) ON DELETE CASCADE,
  FOREIGN KEY (local_product_id) REFERENCES products(id) ON DELETE CASCADE,
  UNIQUE (connection_id, upstream_product_id)
);

CREATE TABLE IF NOT EXISTS product_mapping_skus (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  mapping_id INTEGER NOT NULL,
  local_sku_id INTEGER NOT NULL,
  upstream_sku_id INTEGER NOT NULL,
  upstream_price REAL NOT NULL DEFAULT 0,
  upstream_stock INTEGER NOT NULL DEFAULT -1,
  upstream_is_active INTEGER NOT NULL DEFAULT 1,
  upstream_payload_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (mapping_id) REFERENCES product_mappings(id) ON DELETE CASCADE,
  FOREIGN KEY (local_sku_id) REFERENCES product_skus(id) ON DELETE CASCADE,
  UNIQUE (mapping_id, local_sku_id)
);

CREATE TABLE IF NOT EXISTS procurement_orders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  connection_id INTEGER NOT NULL,
  local_order_id INTEGER NOT NULL,
  local_order_no TEXT NOT NULL DEFAULT '',
  parent_order_no TEXT NOT NULL DEFAULT '',
  upstream_order_no TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending',
  upstream_amount REAL NOT NULL DEFAULT 0,
  upstream_currency TEXT NOT NULL DEFAULT 'CNY',
  local_sell_amount REAL NOT NULL DEFAULT 0,
  local_sell_currency TEXT NOT NULL DEFAULT 'CNY',
  local_cost REAL NOT NULL DEFAULT 0,
  error_message TEXT NOT NULL DEFAULT '',
  retry_count INTEGER NOT NULL DEFAULT 0,
  next_retry_at TEXT,
  trace_id TEXT NOT NULL DEFAULT '',
  upstream_payload TEXT NOT NULL DEFAULT '',
  upstream_payload_line_count INTEGER NOT NULL DEFAULT 0,
  upstream_refund_records_json TEXT NOT NULL DEFAULT '[]',
  upstream_refunded_amount REAL NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (connection_id) REFERENCES site_connections(id) ON DELETE CASCADE,
  FOREIGN KEY (local_order_id) REFERENCES orders(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS reconciliation_jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  connection_id INTEGER NOT NULL,
  type TEXT NOT NULL DEFAULT 'full',
  status TEXT NOT NULL DEFAULT 'pending',
  time_range_start TEXT NOT NULL,
  time_range_end TEXT NOT NULL,
  total_items INTEGER NOT NULL DEFAULT 0,
  matched_items INTEGER NOT NULL DEFAULT 0,
  mismatched_items INTEGER NOT NULL DEFAULT 0,
  missing_items INTEGER NOT NULL DEFAULT 0,
  result_json TEXT NOT NULL DEFAULT '{}',
  started_at TEXT,
  finished_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (connection_id) REFERENCES site_connections(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS reconciliation_items (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id INTEGER NOT NULL,
  type TEXT NOT NULL DEFAULT 'order',
  local_order_no TEXT NOT NULL DEFAULT '',
  upstream_order_no TEXT NOT NULL DEFAULT '',
  local_amount REAL NOT NULL DEFAULT 0,
  upstream_amount REAL NOT NULL DEFAULT 0,
  local_status TEXT NOT NULL DEFAULT '',
  upstream_status TEXT NOT NULL DEFAULT '',
  mismatch_type TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'open',
  resolution TEXT NOT NULL DEFAULT '',
  remark TEXT NOT NULL DEFAULT '',
  resolved_by TEXT NOT NULL DEFAULT '',
  resolved_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (job_id) REFERENCES reconciliation_jobs(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_product_mappings_connection ON product_mappings(connection_id);
CREATE INDEX IF NOT EXISTS idx_product_mappings_product ON product_mappings(local_product_id);
CREATE INDEX IF NOT EXISTS idx_product_mappings_active ON product_mappings(is_active);
CREATE INDEX IF NOT EXISTS idx_procurement_orders_connection ON procurement_orders(connection_id);
CREATE INDEX IF NOT EXISTS idx_procurement_orders_status ON procurement_orders(status);
CREATE INDEX IF NOT EXISTS idx_procurement_orders_local_order ON procurement_orders(local_order_id);
CREATE INDEX IF NOT EXISTS idx_procurement_orders_created_at ON procurement_orders(created_at);
CREATE INDEX IF NOT EXISTS idx_reconciliation_jobs_connection ON reconciliation_jobs(connection_id);
CREATE INDEX IF NOT EXISTS idx_reconciliation_jobs_status ON reconciliation_jobs(status);
CREATE INDEX IF NOT EXISTS idx_reconciliation_items_job ON reconciliation_items(job_id);
CREATE INDEX IF NOT EXISTS idx_reconciliation_items_status ON reconciliation_items(status);
