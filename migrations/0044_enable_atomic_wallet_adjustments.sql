INSERT INTO settings(key, value_json)
VALUES ('atomic_wallet_adjustments_enabled', 'true')
ON CONFLICT(key) DO UPDATE SET
  value_json='true',
  updated_at=CURRENT_TIMESTAMP;
