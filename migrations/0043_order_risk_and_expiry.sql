CREATE TABLE IF NOT EXISTS rate_limit_counters (
  counter_key TEXT PRIMARY KEY,
  window_started_at INTEGER NOT NULL,
  request_count INTEGER NOT NULL DEFAULT 0,
  blocked_until INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_rate_limit_counters_updated_at
ON rate_limit_counters(updated_at);

CREATE TABLE IF NOT EXISTS order_maintenance_state (
  order_id INTEGER PRIMARY KEY,
  expiry_cleanup_completed_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);
