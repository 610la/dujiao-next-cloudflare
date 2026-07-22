CREATE TABLE IF NOT EXISTS order_processing_state (
  order_id INTEGER PRIMARY KEY,
  manual_stock_consumed_at TEXT,
  business_effects_completed_at TEXT,
  notifications_sent_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
);

-- Existing paid orders were already processed by the previous implementation.
INSERT OR IGNORE INTO order_processing_state (
  order_id, manual_stock_consumed_at, business_effects_completed_at, notifications_sent_at
)
SELECT id, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM orders
WHERE paid_at IS NOT NULL;
