DROP TRIGGER IF EXISTS trg_reseller_withdraw_reserve_before_insert;
DROP TRIGGER IF EXISTS trg_reseller_withdraw_paid_before_update;
DROP TRIGGER IF EXISTS trg_reseller_withdraw_paid_after_update;

CREATE TABLE IF NOT EXISTS reseller_withdraw_allocations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  withdraw_request_id INTEGER NOT NULL,
  ledger_entry_id INTEGER NOT NULL,
  amount REAL NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (withdraw_request_id) REFERENCES reseller_withdraws(id) ON DELETE CASCADE,
  FOREIGN KEY (ledger_entry_id) REFERENCES reseller_ledger_entries(id) ON DELETE RESTRICT,
  UNIQUE(withdraw_request_id, ledger_entry_id)
);

CREATE TABLE IF NOT EXISTS reseller_withdraw_allocation_jobs (
  withdraw_request_id INTEGER PRIMARY KEY,
  reseller_id INTEGER NOT NULL,
  amount REAL NOT NULL,
  currency TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (withdraw_request_id) REFERENCES reseller_withdraws(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_reseller_withdraw_allocations_ledger
  ON reseller_withdraw_allocations(ledger_entry_id);
CREATE INDEX IF NOT EXISTS idx_reseller_ledger_settlement_due
  ON reseller_ledger_entries(status, available_at);
CREATE INDEX IF NOT EXISTS idx_reseller_ledger_withdraw_scope
  ON reseller_ledger_entries(reseller_id, currency, status, withdraw_request_id, available_at, id);

-- Preserve the pre-migration cached balance as a one-time opening adjustment.
-- Older Worker builds deducted paid withdrawals only from the cache and did not
-- bind the original positive ledger rows, so recomputing without this bridge
-- would make historical withdrawals available again.
INSERT OR IGNORE INTO reseller_ledger_entries (
  reseller_id, type, amount, currency, idempotency_key,
  metadata_json, status, available_at, remark
)
SELECT
  account.reseller_id,
  'manual_adjust',
  ROUND(
    account.available_amount_cache + account.locked_amount_cache -
    COALESCE((
      SELECT SUM(entry.amount)
      FROM reseller_ledger_entries entry
      WHERE entry.reseller_id = account.reseller_id
        AND entry.currency = account.currency
        AND entry.status IN ('available', 'locked')
    ), 0),
    2
  ),
  account.currency,
  'legacy-balance-reconciliation:' || account.id,
  json_object('source', '0047_reseller_settlement_parity'),
  'available',
  CURRENT_TIMESTAMP,
  '历史分销余额迁移对账'
FROM reseller_balance_accounts account
WHERE ABS(ROUND(
  account.available_amount_cache + account.locked_amount_cache -
  COALESCE((
    SELECT SUM(entry.amount)
    FROM reseller_ledger_entries entry
    WHERE entry.reseller_id = account.reseller_id
      AND entry.currency = account.currency
      AND entry.status IN ('available', 'locked')
  ), 0),
  2
)) >= 0.01;

CREATE TRIGGER trg_reseller_withdraw_validate_before_insert
BEFORE INSERT ON reseller_withdraws
WHEN NEW.status IN ('pending', 'pending_review')
BEGIN
  SELECT CASE
    WHEN ROUND(NEW.amount, 2) <= 0
      THEN RAISE(ABORT, 'reseller_withdraw_amount_invalid')
    WHEN COALESCE((
      SELECT status
      FROM reseller_balance_accounts
      WHERE reseller_id = NEW.reseller_id AND currency = NEW.currency
    ), 'normal') IN ('negative_balance', 'frozen_review', 'disabled')
      THEN RAISE(ABORT, 'reseller_balance_frozen')
    WHEN ROUND(NEW.amount, 2) > ROUND(COALESCE((
      SELECT SUM(entry.amount)
      FROM reseller_ledger_entries entry
      WHERE entry.reseller_id = NEW.reseller_id
        AND entry.currency = NEW.currency
        AND entry.status = 'available'
        AND entry.withdraw_request_id IS NULL
    ), 0), 2)
      THEN RAISE(ABORT, 'reseller_withdraw_insufficient')
  END;
END;

CREATE TRIGGER trg_reseller_withdraw_enqueue_after_insert
AFTER INSERT ON reseller_withdraws
WHEN NEW.status IN ('pending', 'pending_review')
BEGIN
  INSERT OR IGNORE INTO reseller_withdraw_allocation_jobs (
    withdraw_request_id, reseller_id, amount, currency
  ) VALUES (NEW.id, NEW.reseller_id, ROUND(NEW.amount, 2), NEW.currency);
END;

CREATE TRIGGER trg_reseller_withdraw_allocate_after_job
AFTER INSERT ON reseller_withdraw_allocation_jobs
BEGIN
  INSERT OR IGNORE INTO reseller_withdraw_allocations (
    withdraw_request_id, ledger_entry_id, amount
  )
  SELECT
    NEW.withdraw_request_id,
    entry.id,
    ROUND(MIN(
      entry.amount,
      NEW.amount - COALESCE((
        SELECT SUM(previous.amount)
        FROM reseller_ledger_entries previous
        WHERE previous.reseller_id = NEW.reseller_id
          AND previous.currency = NEW.currency
          AND previous.status = 'available'
          AND previous.withdraw_request_id IS NULL
          AND previous.amount > 0
          AND (
            COALESCE(previous.available_at, '') < COALESCE(entry.available_at, '')
            OR (
              COALESCE(previous.available_at, '') = COALESCE(entry.available_at, '')
              AND previous.id < entry.id
            )
          )
      ), 0)
    ), 2)
  FROM reseller_ledger_entries entry
  WHERE entry.reseller_id = NEW.reseller_id
    AND entry.currency = NEW.currency
    AND entry.status = 'available'
    AND entry.withdraw_request_id IS NULL
    AND entry.amount > 0
    AND COALESCE((
      SELECT SUM(previous.amount)
      FROM reseller_ledger_entries previous
      WHERE previous.reseller_id = NEW.reseller_id
        AND previous.currency = NEW.currency
        AND previous.status = 'available'
        AND previous.withdraw_request_id IS NULL
        AND previous.amount > 0
        AND (
          COALESCE(previous.available_at, '') < COALESCE(entry.available_at, '')
          OR (
            COALESCE(previous.available_at, '') = COALESCE(entry.available_at, '')
            AND previous.id < entry.id
          )
        )
    ), 0) < NEW.amount
  ORDER BY COALESCE(entry.available_at, '') ASC, entry.id ASC;

  INSERT OR IGNORE INTO reseller_ledger_entries (
    reseller_id, order_id, type, amount, currency, idempotency_key,
    metadata_json, status, available_at, withdraw_request_id, remark,
    created_at, updated_at
  )
  SELECT
    entry.reseller_id,
    entry.order_id,
    entry.type,
    ROUND(entry.amount - allocation.amount, 2),
    entry.currency,
    CASE
      WHEN entry.idempotency_key <> ''
        THEN entry.idempotency_key || ':split:withdraw:' || NEW.withdraw_request_id
      ELSE 'split:' || entry.id || ':withdraw:' || NEW.withdraw_request_id
    END ,
    entry.metadata_json,
    'available',
    entry.available_at,
    NULL,
    entry.remark,
    entry.created_at,
    CURRENT_TIMESTAMP
  FROM reseller_withdraw_allocations allocation
  JOIN reseller_ledger_entries entry ON entry.id = allocation.ledger_entry_id
  WHERE allocation.withdraw_request_id = NEW.withdraw_request_id
    AND ROUND(entry.amount - allocation.amount, 2) > 0;

  UPDATE reseller_ledger_entries
  SET amount = ROUND((
        SELECT allocation.amount
        FROM reseller_withdraw_allocations allocation
        WHERE allocation.withdraw_request_id = NEW.withdraw_request_id
          AND allocation.ledger_entry_id = reseller_ledger_entries.id
      ), 2),
      status = 'locked',
      withdraw_request_id = NEW.withdraw_request_id,
      updated_at = CURRENT_TIMESTAMP
  WHERE id IN (
    SELECT ledger_entry_id
    FROM reseller_withdraw_allocations
    WHERE withdraw_request_id = NEW.withdraw_request_id
  );

  UPDATE reseller_withdraws
  SET status = 'rejected',
      reject_reason = 'legacy_allocation_insufficient',
      processed_at = CURRENT_TIMESTAMP,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.withdraw_request_id
    AND ROUND(COALESCE((
      SELECT SUM(amount)
      FROM reseller_withdraw_allocations
      WHERE withdraw_request_id = NEW.withdraw_request_id
    ), 0), 2) <> ROUND(NEW.amount, 2);

  UPDATE reseller_balance_accounts
  SET available_amount_cache = ROUND(COALESCE((
        SELECT SUM(entry.amount)
        FROM reseller_ledger_entries entry
        WHERE entry.reseller_id = NEW.reseller_id
          AND entry.currency = NEW.currency
          AND entry.status = 'available'
      ), 0), 2),
      locked_amount_cache = ROUND(COALESCE((
        SELECT SUM(entry.amount)
        FROM reseller_ledger_entries entry
        WHERE entry.reseller_id = NEW.reseller_id
          AND entry.currency = NEW.currency
          AND entry.status = 'locked'
      ), 0), 2),
      negative_amount_cache = MAX(0, -ROUND(COALESCE((
        SELECT SUM(entry.amount)
        FROM reseller_ledger_entries entry
        WHERE entry.reseller_id = NEW.reseller_id
          AND entry.currency = NEW.currency
          AND entry.status = 'available'
      ), 0), 2)),
      status = CASE
        WHEN ROUND(COALESCE((
          SELECT SUM(entry.amount)
          FROM reseller_ledger_entries entry
          WHERE entry.reseller_id = NEW.reseller_id
            AND entry.currency = NEW.currency
            AND entry.status = 'available'
        ), 0), 2) < 0 THEN 'negative_balance'
        WHEN status = 'negative_balance' THEN 'normal'
        ELSE status
      END ,
      last_ledger_entry_id = COALESCE((
        SELECT MAX(entry.id)
        FROM reseller_ledger_entries entry
        WHERE entry.reseller_id = NEW.reseller_id AND entry.currency = NEW.currency
      ), last_ledger_entry_id),
      updated_at = CURRENT_TIMESTAMP
  WHERE reseller_id = NEW.reseller_id AND currency = NEW.currency;
END;

CREATE TRIGGER trg_reseller_withdraw_reject_release_after_update
AFTER UPDATE OF status ON reseller_withdraws
WHEN OLD.status IN ('pending', 'pending_review') AND NEW.status = 'rejected'
BEGIN
  UPDATE reseller_ledger_entries
  SET status = 'available', withdraw_request_id = NULL, updated_at = CURRENT_TIMESTAMP
  WHERE withdraw_request_id = NEW.id AND status = 'locked';

  UPDATE reseller_balance_accounts
  SET available_amount_cache = ROUND(COALESCE((
        SELECT SUM(entry.amount) FROM reseller_ledger_entries entry
        WHERE entry.reseller_id = NEW.reseller_id AND entry.currency = NEW.currency
          AND entry.status = 'available'
      ), 0), 2),
      locked_amount_cache = ROUND(COALESCE((
        SELECT SUM(entry.amount) FROM reseller_ledger_entries entry
        WHERE entry.reseller_id = NEW.reseller_id AND entry.currency = NEW.currency
          AND entry.status = 'locked'
      ), 0), 2),
      negative_amount_cache = MAX(0, -ROUND(COALESCE((
        SELECT SUM(entry.amount) FROM reseller_ledger_entries entry
        WHERE entry.reseller_id = NEW.reseller_id AND entry.currency = NEW.currency
          AND entry.status = 'available'
      ), 0), 2)),
      status = CASE
        WHEN ROUND(COALESCE((
          SELECT SUM(entry.amount) FROM reseller_ledger_entries entry
          WHERE entry.reseller_id = NEW.reseller_id AND entry.currency = NEW.currency
            AND entry.status = 'available'
        ), 0), 2) < 0 THEN 'negative_balance'
        WHEN status = 'negative_balance' THEN 'normal'
        ELSE status
      END ,
      updated_at = CURRENT_TIMESTAMP
  WHERE reseller_id = NEW.reseller_id AND currency = NEW.currency;
END;

CREATE TRIGGER trg_reseller_withdraw_validate_pay_before_update
BEFORE UPDATE OF status ON reseller_withdraws
WHEN OLD.status IN ('pending', 'pending_review') AND NEW.status = 'paid'
BEGIN
  SELECT CASE WHEN ROUND(COALESCE((
    SELECT SUM(amount)
    FROM reseller_withdraw_allocations
    WHERE withdraw_request_id = OLD.id
  ), 0), 2) <> ROUND(OLD.amount, 2)
    THEN RAISE(ABORT, 'reseller_withdraw_allocation_invalid')
  END;
END;

CREATE TRIGGER trg_reseller_withdraw_pay_after_update
AFTER UPDATE OF status ON reseller_withdraws
WHEN OLD.status IN ('pending', 'pending_review') AND NEW.status = 'paid'
BEGIN
  UPDATE reseller_ledger_entries
  SET status = 'withdrawn', updated_at = CURRENT_TIMESTAMP
  WHERE withdraw_request_id = NEW.id AND status = 'locked';

  UPDATE reseller_balance_accounts
  SET available_amount_cache = ROUND(COALESCE((
        SELECT SUM(entry.amount) FROM reseller_ledger_entries entry
        WHERE entry.reseller_id = NEW.reseller_id AND entry.currency = NEW.currency
          AND entry.status = 'available'
      ), 0), 2),
      locked_amount_cache = ROUND(COALESCE((
        SELECT SUM(entry.amount) FROM reseller_ledger_entries entry
        WHERE entry.reseller_id = NEW.reseller_id AND entry.currency = NEW.currency
          AND entry.status = 'locked'
      ), 0), 2),
      negative_amount_cache = MAX(0, -ROUND(COALESCE((
        SELECT SUM(entry.amount) FROM reseller_ledger_entries entry
        WHERE entry.reseller_id = NEW.reseller_id AND entry.currency = NEW.currency
          AND entry.status = 'available'
      ), 0), 2)),
      status = CASE
        WHEN ROUND(COALESCE((
          SELECT SUM(entry.amount) FROM reseller_ledger_entries entry
          WHERE entry.reseller_id = NEW.reseller_id AND entry.currency = NEW.currency
            AND entry.status = 'available'
        ), 0), 2) < 0 THEN 'negative_balance'
        WHEN status = 'negative_balance' THEN 'normal'
        ELSE status
      END ,
      updated_at = CURRENT_TIMESTAMP
  WHERE reseller_id = NEW.reseller_id AND currency = NEW.currency;
END;

CREATE TRIGGER trg_reseller_ledger_confirm_refresh_after_update
AFTER UPDATE OF status ON reseller_ledger_entries
WHEN OLD.status = 'pending_confirm' AND NEW.status = 'available'
BEGIN
  UPDATE reseller_balance_accounts
  SET available_amount_cache = ROUND(COALESCE((
        SELECT SUM(entry.amount) FROM reseller_ledger_entries entry
        WHERE entry.reseller_id = NEW.reseller_id AND entry.currency = NEW.currency
          AND entry.status = 'available'
      ), 0), 2),
      locked_amount_cache = ROUND(COALESCE((
        SELECT SUM(entry.amount) FROM reseller_ledger_entries entry
        WHERE entry.reseller_id = NEW.reseller_id AND entry.currency = NEW.currency
          AND entry.status = 'locked'
      ), 0), 2),
      negative_amount_cache = MAX(0, -ROUND(COALESCE((
        SELECT SUM(entry.amount) FROM reseller_ledger_entries entry
        WHERE entry.reseller_id = NEW.reseller_id AND entry.currency = NEW.currency
          AND entry.status = 'available'
      ), 0), 2)),
      status = CASE
        WHEN ROUND(COALESCE((
          SELECT SUM(entry.amount) FROM reseller_ledger_entries entry
          WHERE entry.reseller_id = NEW.reseller_id AND entry.currency = NEW.currency
            AND entry.status = 'available'
        ), 0), 2) < 0 THEN 'negative_balance'
        WHEN status = 'negative_balance' THEN 'normal'
        ELSE status
      END ,
      last_ledger_entry_id = MAX(last_ledger_entry_id, NEW.id),
      updated_at = CURRENT_TIMESTAMP
  WHERE reseller_id = NEW.reseller_id AND currency = NEW.currency;
END;

-- Allocate any request created by the older Worker implementation. Requests
-- that cannot be fully backed by positive ledger rows are rejected and released.
UPDATE reseller_withdraws
SET status = 'pending', updated_at = CURRENT_TIMESTAMP
WHERE status = 'pending_review';

INSERT OR IGNORE INTO reseller_withdraw_allocation_jobs (
  withdraw_request_id, reseller_id, amount, currency
)
SELECT id, reseller_id, ROUND(amount, 2), currency
FROM reseller_withdraws
WHERE status = 'pending';

UPDATE reseller_balance_accounts
SET available_amount_cache = ROUND(COALESCE((
      SELECT SUM(entry.amount) FROM reseller_ledger_entries entry
      WHERE entry.reseller_id = reseller_balance_accounts.reseller_id
        AND entry.currency = reseller_balance_accounts.currency
        AND entry.status = 'available'
    ), 0), 2),
    locked_amount_cache = ROUND(COALESCE((
      SELECT SUM(entry.amount) FROM reseller_ledger_entries entry
      WHERE entry.reseller_id = reseller_balance_accounts.reseller_id
        AND entry.currency = reseller_balance_accounts.currency
        AND entry.status = 'locked'
    ), 0), 2),
    negative_amount_cache = MAX(0, -ROUND(COALESCE((
      SELECT SUM(entry.amount) FROM reseller_ledger_entries entry
      WHERE entry.reseller_id = reseller_balance_accounts.reseller_id
        AND entry.currency = reseller_balance_accounts.currency
        AND entry.status = 'available'
    ), 0), 2)),
    status = CASE
      WHEN ROUND(COALESCE((
        SELECT SUM(entry.amount) FROM reseller_ledger_entries entry
        WHERE entry.reseller_id = reseller_balance_accounts.reseller_id
          AND entry.currency = reseller_balance_accounts.currency
          AND entry.status = 'available'
      ), 0), 2) < 0 THEN 'negative_balance'
      WHEN status = 'negative_balance' THEN 'normal'
      ELSE status
    END ,
    last_ledger_entry_id = COALESCE((
      SELECT MAX(entry.id) FROM reseller_ledger_entries entry
      WHERE entry.reseller_id = reseller_balance_accounts.reseller_id
        AND entry.currency = reseller_balance_accounts.currency
    ), last_ledger_entry_id),
    updated_at = CURRENT_TIMESTAMP;

INSERT INTO settings(key, value_json)
VALUES ('atomic_reseller_withdraw_enabled', 'true')
ON CONFLICT(key) DO UPDATE SET value_json='true', updated_at=CURRENT_TIMESTAMP;
