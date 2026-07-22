CREATE TABLE IF NOT EXISTS email_delivery_claims (
  dedupe_key TEXT PRIMARY KEY,
  status TEXT NOT NULL DEFAULT 'sending',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_email_delivery_claims_status
ON email_delivery_claims(status, updated_at);

INSERT OR IGNORE INTO email_delivery_claims (dedupe_key, status, created_at, updated_at)
SELECT dedupe_key, 'sent', MIN(created_at), MAX(created_at)
FROM email_delivery_logs
WHERE dedupe_key <> '' AND status = 'sent'
GROUP BY dedupe_key;
