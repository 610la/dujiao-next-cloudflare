ALTER TABLE procurement_orders ADD COLUMN source_key TEXT NOT NULL DEFAULT '';

UPDATE procurement_orders
SET source_key = 'legacy:' || id
WHERE source_key = '';

CREATE UNIQUE INDEX IF NOT EXISTS idx_procurement_orders_source_key
ON procurement_orders(source_key)
WHERE source_key <> '';

CREATE UNIQUE INDEX IF NOT EXISTS idx_reseller_ledger_entries_idempotency
ON reseller_ledger_entries(idempotency_key)
WHERE idempotency_key <> '';
