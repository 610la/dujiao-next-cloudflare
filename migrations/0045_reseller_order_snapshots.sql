CREATE TABLE IF NOT EXISTS reseller_order_snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL UNIQUE,
  reseller_id INTEGER NOT NULL,
  domain TEXT NOT NULL DEFAULT '',
  currency TEXT NOT NULL DEFAULT 'CNY',
  reseller_user_id INTEGER NOT NULL,
  buyer_user_id INTEGER NOT NULL DEFAULT 0,
  base_amount REAL NOT NULL DEFAULT 0,
  reseller_amount REAL NOT NULL DEFAULT 0,
  profit_amount REAL NOT NULL DEFAULT 0,
  profit_eligible INTEGER NOT NULL DEFAULT 1,
  profit_block_reason TEXT NOT NULL DEFAULT '',
  pricing_snapshot_json TEXT NOT NULL DEFAULT '{}',
  risk_snapshot_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  FOREIGN KEY (reseller_id) REFERENCES reseller_profiles(id) ON DELETE CASCADE,
  FOREIGN KEY (reseller_user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS reseller_related_accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reseller_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  relation_type TEXT NOT NULL DEFAULT 'manual',
  source TEXT NOT NULL DEFAULT 'admin',
  status TEXT NOT NULL DEFAULT 'active',
  remark TEXT NOT NULL DEFAULT '',
  created_by INTEGER,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (reseller_id) REFERENCES reseller_profiles(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (created_by) REFERENCES admins(id) ON DELETE SET NULL,
  UNIQUE(reseller_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_reseller_snapshot_reseller_created
  ON reseller_order_snapshots(reseller_id, created_at);
CREATE INDEX IF NOT EXISTS idx_reseller_snapshot_profit_risk
  ON reseller_order_snapshots(profit_eligible, profit_block_reason, created_at);
CREATE INDEX IF NOT EXISTS idx_reseller_related_accounts_lookup
  ON reseller_related_accounts(reseller_id, user_id, status);

CREATE TRIGGER IF NOT EXISTS trg_reseller_refund_deduct
AFTER INSERT ON order_refunds
WHEN EXISTS (
  SELECT 1
  FROM reseller_order_snapshots snapshot
  WHERE snapshot.order_id = NEW.order_id
    AND snapshot.profit_eligible = 1
    AND ROUND(snapshot.profit_amount, 2) > 0
    AND ROUND( CASE
      WHEN snapshot.reseller_amount > 0 THEN snapshot.reseller_amount
      ELSE (SELECT total_amount FROM orders WHERE id = NEW.order_id)
    END , 2) > 0
)
BEGIN
  INSERT OR IGNORE INTO reseller_balance_accounts (reseller_id, currency, status)
  SELECT reseller_id, currency, 'normal'
  FROM reseller_order_snapshots
  WHERE order_id = NEW.order_id;

  INSERT OR IGNORE INTO reseller_ledger_entries (
    reseller_id, order_id, type, amount, currency, idempotency_key,
    metadata_json, status, available_at, remark
  )
  SELECT
    snapshot.reseller_id,
    NEW.order_id,
    'refund_deduct',
    -ROUND(MIN(
      ROUND(snapshot.profit_amount - ABS(COALESCE((
        SELECT SUM(entry.amount)
        FROM reseller_ledger_entries entry
        WHERE entry.order_id = NEW.order_id
          AND entry.type = 'refund_deduct'
          AND entry.status <> 'canceled'
      ), 0)), 2),
      CASE
        WHEN ROUND(COALESCE((
          SELECT SUM(refund.amount)
          FROM order_refunds refund
          WHERE refund.order_id = NEW.order_id
        ), 0), 2) >= ROUND( CASE
          WHEN snapshot.reseller_amount > 0 THEN snapshot.reseller_amount
          ELSE order_row.total_amount
        END , 2)
        THEN ROUND(snapshot.profit_amount - ABS(COALESCE((
          SELECT SUM(entry.amount)
          FROM reseller_ledger_entries entry
          WHERE entry.order_id = NEW.order_id
            AND entry.type = 'refund_deduct'
            AND entry.status <> 'canceled'
        ), 0)), 2)
        ELSE ROUND(
          snapshot.profit_amount * NEW.amount / CASE
            WHEN snapshot.reseller_amount > 0 THEN snapshot.reseller_amount
            ELSE order_row.total_amount
          END ,
          2
        )
      END
    ), 2),
    COALESCE(NULLIF(TRIM(snapshot.currency), ''), NULLIF(TRIM(NEW.currency), ''), NULLIF(TRIM(order_row.currency), ''), 'CNY'),
    'refund_deduct:' || NEW.id,
    json_object(
      'refund_record_id', NEW.id,
      'refund_type', NEW.type,
      'refund_amount', printf('%.2f', NEW.amount),
      'refunded_before', printf('%.2f', MAX(0, COALESCE((
        SELECT SUM(refund.amount)
        FROM order_refunds refund
        WHERE refund.order_id = NEW.order_id
          AND refund.id <> NEW.id
      ), 0))),
      'snapshot_id', snapshot.id
    ),
    COALESCE((
      SELECT CASE WHEN profit_entry.status = 'pending_confirm' THEN 'pending_confirm' ELSE 'available' END
      FROM reseller_ledger_entries profit_entry
      WHERE profit_entry.order_id = NEW.order_id
        AND profit_entry.type = 'order_profit'
      ORDER BY profit_entry.id ASC
      LIMIT 1
    ), 'available'),
    (
      SELECT CASE WHEN profit_entry.status = 'pending_confirm' THEN profit_entry.available_at ELSE NULL END
      FROM reseller_ledger_entries profit_entry
      WHERE profit_entry.order_id = NEW.order_id
        AND profit_entry.type = 'order_profit'
      ORDER BY profit_entry.id ASC
      LIMIT 1
    ),
    '分站订单退款利润扣回 ' || order_row.order_no
  FROM reseller_order_snapshots snapshot
  JOIN orders order_row ON order_row.id = snapshot.order_id
  WHERE snapshot.order_id = NEW.order_id
    AND snapshot.profit_eligible = 1
    AND ROUND(snapshot.profit_amount, 2) > 0
    AND ROUND(snapshot.profit_amount - ABS(COALESCE((
      SELECT SUM(entry.amount)
      FROM reseller_ledger_entries entry
      WHERE entry.order_id = NEW.order_id
        AND entry.type = 'refund_deduct'
        AND entry.status <> 'canceled'
    ), 0)), 2) > 0
    AND ROUND( CASE
      WHEN snapshot.reseller_amount > 0 THEN snapshot.reseller_amount
      ELSE order_row.total_amount
    END , 2) > 0
    AND (
      ROUND(COALESCE((
        SELECT SUM(refund.amount)
        FROM order_refunds refund
        WHERE refund.order_id = NEW.order_id
      ), 0), 2) >= ROUND( CASE
        WHEN snapshot.reseller_amount > 0 THEN snapshot.reseller_amount
        ELSE order_row.total_amount
      END , 2)
      OR ROUND(
        snapshot.profit_amount * NEW.amount / CASE
          WHEN snapshot.reseller_amount > 0 THEN snapshot.reseller_amount
          ELSE order_row.total_amount
        END ,
        2
      ) > 0
    );

  UPDATE reseller_balance_accounts
  SET available_amount_cache = ROUND(available_amount_cache + COALESCE((
        SELECT amount
        FROM reseller_ledger_entries
        WHERE idempotency_key = 'refund_deduct:' || NEW.id
          AND status = 'available'
      ), 0), 2),
      negative_amount_cache = CASE
        WHEN ROUND(available_amount_cache + COALESCE((
          SELECT amount
          FROM reseller_ledger_entries
          WHERE idempotency_key = 'refund_deduct:' || NEW.id
            AND status = 'available'
        ), 0), 2) < 0
        THEN ABS(ROUND(available_amount_cache + COALESCE((
          SELECT amount
          FROM reseller_ledger_entries
          WHERE idempotency_key = 'refund_deduct:' || NEW.id
            AND status = 'available'
        ), 0), 2))
        ELSE 0
      END ,
      status = CASE
        WHEN ROUND(available_amount_cache + COALESCE((
          SELECT amount
          FROM reseller_ledger_entries
          WHERE idempotency_key = 'refund_deduct:' || NEW.id
            AND status = 'available'
        ), 0), 2) < 0 THEN 'negative_balance'
        WHEN status = 'negative_balance' THEN 'normal'
        ELSE status
      END ,
      last_ledger_entry_id = COALESCE((
        SELECT id FROM reseller_ledger_entries WHERE idempotency_key = 'refund_deduct:' || NEW.id
      ), last_ledger_entry_id),
      updated_at = CURRENT_TIMESTAMP
  WHERE reseller_id = (
      SELECT reseller_id FROM reseller_order_snapshots WHERE order_id = NEW.order_id
    )
    AND currency = COALESCE((
      SELECT NULLIF(TRIM(currency), '') FROM reseller_order_snapshots WHERE order_id = NEW.order_id
    ), NULLIF(TRIM(NEW.currency), ''), 'CNY')
    AND changes() = 1
    AND EXISTS (
      SELECT 1
      FROM reseller_ledger_entries
      WHERE idempotency_key = 'refund_deduct:' || NEW.id
        AND status = 'available'
    );

  UPDATE orders
  SET reseller_profit_status = 'unavailable', updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.order_id
    AND EXISTS (
      SELECT 1
      FROM reseller_order_snapshots snapshot
      WHERE snapshot.order_id = NEW.order_id
        AND snapshot.profit_eligible = 1
        AND snapshot.profit_amount > 0
    );
END;
