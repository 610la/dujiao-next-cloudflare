ALTER TABLE api_credentials ADD COLUMN api_secret TEXT NOT NULL DEFAULT '';
ALTER TABLE procurement_orders ADD COLUMN upstream_order_id INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS downstream_order_refs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL UNIQUE,
  api_credential_id INTEGER NOT NULL,
  downstream_order_no TEXT NOT NULL DEFAULT '',
  callback_url TEXT NOT NULL DEFAULT '',
  trace_id TEXT NOT NULL DEFAULT '',
  callback_status TEXT NOT NULL DEFAULT 'pending',
  callback_retry_count INTEGER NOT NULL DEFAULT 0,
  last_callback_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  FOREIGN KEY (api_credential_id) REFERENCES api_credentials(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_downstream_order_refs_credential_no ON downstream_order_refs(api_credential_id, downstream_order_no);
CREATE INDEX IF NOT EXISTS idx_downstream_order_refs_order ON downstream_order_refs(order_id);
CREATE INDEX IF NOT EXISTS idx_downstream_order_refs_callback ON downstream_order_refs(callback_status);
