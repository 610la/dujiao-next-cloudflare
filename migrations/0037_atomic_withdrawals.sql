UPDATE reseller_withdraws
SET status = 'pending', updated_at = CURRENT_TIMESTAMP
WHERE status = 'pending_review';

CREATE UNIQUE INDEX IF NOT EXISTS idx_reseller_ledger_idempotency_once
ON reseller_ledger_entries(idempotency_key)
WHERE idempotency_key <> '';

CREATE TRIGGER IF NOT EXISTS trg_affiliate_withdraw_reserve_before_insert
BEFORE INSERT ON affiliate_withdraws
WHEN NEW.status = 'pending_review'
BEGIN
  SELECT CASE
    WHEN ROUND(NEW.amount, 2) <= 0 THEN RAISE(ABORT, 'affiliate_withdraw_amount_invalid')
    WHEN ROUND(NEW.amount, 2) > ROUND(
      COALESCE((
        SELECT SUM(commission_amount)
        FROM affiliate_commissions
        WHERE affiliate_profile_id = NEW.affiliate_profile_id
          AND status = 'available'
      ), 0) - COALESCE((
        SELECT SUM(amount)
        FROM affiliate_withdraws
        WHERE affiliate_profile_id = NEW.affiliate_profile_id
          AND status IN ('pending_review', 'paid')
      ), 0),
      2
    ) THEN RAISE(ABORT, 'affiliate_withdraw_insufficient')
  END;
END;

CREATE TRIGGER IF NOT EXISTS trg_reseller_withdraw_reserve_before_insert
BEFORE INSERT ON reseller_withdraws
WHEN NEW.status = 'pending'
BEGIN
  SELECT CASE
    WHEN ROUND(NEW.amount, 2) <= 0 THEN RAISE(ABORT, 'reseller_withdraw_amount_invalid')
    WHEN ROUND(NEW.amount, 2) > ROUND(
      COALESCE((
        SELECT available_amount_cache
        FROM reseller_balance_accounts
        WHERE reseller_id = NEW.reseller_id
          AND currency = NEW.currency
      ), 0) - COALESCE((
        SELECT SUM(amount)
        FROM reseller_withdraws
        WHERE reseller_id = NEW.reseller_id
          AND currency = NEW.currency
          AND status = 'pending'
      ), 0),
      2
    ) THEN RAISE(ABORT, 'reseller_withdraw_insufficient')
  END;
END;

CREATE TRIGGER IF NOT EXISTS trg_reseller_withdraw_paid_before_update
BEFORE UPDATE OF status ON reseller_withdraws
WHEN OLD.status = 'pending'
  AND NEW.status = 'paid'
  AND COALESCE((
    SELECT value_json
    FROM settings
    WHERE key = 'atomic_reseller_withdraw_enabled'
  ), 'false') = 'true'
BEGIN
  SELECT CASE
    WHEN ROUND(OLD.amount, 2) > ROUND(COALESCE((
      SELECT available_amount_cache
      FROM reseller_balance_accounts
      WHERE reseller_id = OLD.reseller_id
        AND currency = OLD.currency
    ), 0), 2) THEN RAISE(ABORT, 'reseller_withdraw_insufficient')
  END;
END;

CREATE TRIGGER IF NOT EXISTS trg_reseller_withdraw_paid_after_update
AFTER UPDATE OF status ON reseller_withdraws
WHEN OLD.status = 'pending'
  AND NEW.status = 'paid'
  AND COALESCE((
    SELECT value_json
    FROM settings
    WHERE key = 'atomic_reseller_withdraw_enabled'
  ), 'false') = 'true'
BEGIN
  UPDATE reseller_balance_accounts
  SET available_amount_cache = ROUND(available_amount_cache - OLD.amount, 2),
      updated_at = CURRENT_TIMESTAMP
  WHERE reseller_id = OLD.reseller_id
    AND currency = OLD.currency;

  INSERT INTO reseller_ledger_entries (
    reseller_id,
    withdraw_request_id,
    type,
    amount,
    currency,
    idempotency_key,
    status,
    remark
  ) VALUES (
    OLD.reseller_id,
    OLD.id,
    'withdraw_paid',
    ROUND(-OLD.amount, 2),
    OLD.currency,
    'withdraw:' || OLD.id || ':paid',
    'withdrawn',
    '提现打款 #' || OLD.id
  );
END;

INSERT INTO settings(key, value_json)
VALUES ('atomic_reseller_withdraw_enabled', 'false')
ON CONFLICT(key) DO NOTHING;
