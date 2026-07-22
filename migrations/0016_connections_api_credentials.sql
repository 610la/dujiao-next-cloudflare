CREATE TABLE IF NOT EXISTS site_connections (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL DEFAULT '',
  base_url TEXT NOT NULL DEFAULT '',
  api_key TEXT NOT NULL DEFAULT '',
  api_secret TEXT NOT NULL DEFAULT '',
  protocol TEXT NOT NULL DEFAULT 'dujiao-next',
  callback_url TEXT NOT NULL DEFAULT '',
  retry_max INTEGER NOT NULL DEFAULT 3,
  retry_intervals TEXT NOT NULL DEFAULT '[30,60,120]',
  exchange_rate REAL NOT NULL DEFAULT 1,
  price_markup_percent REAL NOT NULL DEFAULT 0,
  price_rounding_mode TEXT NOT NULL DEFAULT 'none',
  auto_sync_price INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  last_ping_at TEXT,
  last_ping_status TEXT NOT NULL DEFAULT '',
  last_ping_message TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS api_credentials (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL DEFAULT 0,
  api_key TEXT NOT NULL UNIQUE,
  key_hash TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending_review',
  is_active INTEGER NOT NULL DEFAULT 0,
  reject_reason TEXT NOT NULL DEFAULT '',
  approved_at TEXT,
  last_used_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_site_connections_status ON site_connections(status);
CREATE INDEX IF NOT EXISTS idx_api_credentials_user_id ON api_credentials(user_id);
CREATE INDEX IF NOT EXISTS idx_api_credentials_status ON api_credentials(status);
CREATE INDEX IF NOT EXISTS idx_api_credentials_active ON api_credentials(is_active);
