CREATE TABLE IF NOT EXISTS fulfillment_components (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL,
  source_type TEXT NOT NULL,
  source_id INTEGER NOT NULL DEFAULT 0,
  fulfillment_type TEXT NOT NULL DEFAULT 'manual',
  delivery_data_json TEXT NOT NULL DEFAULT '{}',
  payload TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  UNIQUE (order_id, source_type, source_id)
);

CREATE INDEX IF NOT EXISTS idx_fulfillment_components_order
ON fulfillment_components(order_id);

INSERT OR IGNORE INTO fulfillment_components (
  order_id, source_type, source_id, fulfillment_type, delivery_data_json, payload, created_at, updated_at
)
SELECT
  order_id,
  CASE WHEN type IN ('auto', 'manual', 'upstream') THEN type ELSE 'legacy' END ,
  0,
  type,
  delivery_data_json,
  payload,
  created_at,
  updated_at
FROM fulfillments
WHERE payload <> '';
