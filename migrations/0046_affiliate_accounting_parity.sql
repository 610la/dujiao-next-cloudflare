DROP TRIGGER IF EXISTS trg_affiliate_withdraw_reserve_before_insert;

CREATE TABLE affiliate_commissions_v2 (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  affiliate_profile_id INTEGER NOT NULL,
  order_id INTEGER NOT NULL,
  order_item_id INTEGER,
  order_no TEXT NOT NULL DEFAULT '',
  commission_type TEXT NOT NULL DEFAULT 'order',
  base_amount REAL NOT NULL DEFAULT 0,
  rate_percent REAL NOT NULL DEFAULT 0,
  commission_amount REAL NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending_confirm',
  confirm_at TEXT,
  available_at TEXT,
  withdrawn_at TEXT,
  withdraw_request_id INTEGER,
  invalid_reason TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (affiliate_profile_id) REFERENCES affiliate_profiles(id) ON DELETE CASCADE,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  FOREIGN KEY (order_item_id) REFERENCES order_items(id) ON DELETE SET NULL,
  FOREIGN KEY (withdraw_request_id) REFERENCES affiliate_withdraws(id) ON DELETE SET NULL
);

INSERT INTO affiliate_commissions_v2 (
  id, affiliate_profile_id, order_id, order_no, commission_type,
  base_amount, rate_percent, commission_amount, status,
  confirm_at, available_at, withdrawn_at, created_at, updated_at
)
SELECT
  id, affiliate_profile_id, order_id, order_no, commission_type,
  base_amount, rate_percent, commission_amount, status,
  confirm_at, available_at, withdrawn_at, created_at, updated_at
FROM affiliate_commissions;

DROP TABLE affiliate_commissions;
ALTER TABLE affiliate_commissions_v2 RENAME TO affiliate_commissions;

UPDATE affiliate_commissions
SET confirm_at = available_at, available_at = NULL, updated_at = CURRENT_TIMESTAMP
WHERE status = 'pending_confirm'
  AND available_at IS NOT NULL
  AND (confirm_at IS NULL OR available_at > confirm_at);

CREATE UNIQUE INDEX idx_affiliate_commission_unique
  ON affiliate_commissions(affiliate_profile_id, order_id, commission_type);
CREATE INDEX idx_affiliate_commissions_profile
  ON affiliate_commissions(affiliate_profile_id);
CREATE INDEX idx_affiliate_commissions_status
  ON affiliate_commissions(status);
CREATE INDEX idx_affiliate_commissions_confirm
  ON affiliate_commissions(status, confirm_at);
CREATE INDEX idx_affiliate_commissions_withdraw
  ON affiliate_commissions(withdraw_request_id);

DROP TRIGGER IF EXISTS trg_affiliate_withdraw_reserve_before_insert;
CREATE TRIGGER trg_affiliate_withdraw_reserve_before_insert
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
          AND status = 'pending_review'
      ), 0),
      2
    ) THEN RAISE(ABORT, 'affiliate_withdraw_insufficient')
  END;
END;

CREATE TRIGGER trg_affiliate_refund_rollback
AFTER INSERT ON order_refunds
WHEN EXISTS (
  SELECT 1
  FROM affiliate_commissions commission
  WHERE commission.order_id = NEW.order_id
    AND commission.status IN ('pending_confirm', 'available')
    AND commission.withdraw_request_id IS NULL
)
BEGIN
  UPDATE affiliate_commissions
  SET base_amount = ROUND(base_amount * MAX(0, (
        (SELECT total_amount FROM orders WHERE id = NEW.order_id)
        - COALESCE((
          SELECT SUM(refund.amount)
          FROM order_refunds refund
          WHERE refund.order_id = NEW.order_id
            AND refund.id <> NEW.id
        ), 0)
        - NEW.amount
      )) / MAX(0.01, (
        (SELECT total_amount FROM orders WHERE id = NEW.order_id)
        - COALESCE((
          SELECT SUM(refund.amount)
          FROM order_refunds refund
          WHERE refund.order_id = NEW.order_id
            AND refund.id <> NEW.id
        ), 0)
      )), 2),
      commission_amount = ROUND(commission_amount * MAX(0, (
        (SELECT total_amount FROM orders WHERE id = NEW.order_id)
        - COALESCE((
          SELECT SUM(refund.amount)
          FROM order_refunds refund
          WHERE refund.order_id = NEW.order_id
            AND refund.id <> NEW.id
        ), 0)
        - NEW.amount
      )) / MAX(0.01, (
        (SELECT total_amount FROM orders WHERE id = NEW.order_id)
        - COALESCE((
          SELECT SUM(refund.amount)
          FROM order_refunds refund
          WHERE refund.order_id = NEW.order_id
            AND refund.id <> NEW.id
        ), 0)
      )), 2),
      status = CASE
        WHEN ROUND(commission_amount * MAX(0, (
          (SELECT total_amount FROM orders WHERE id = NEW.order_id)
          - COALESCE((
            SELECT SUM(refund.amount)
            FROM order_refunds refund
            WHERE refund.order_id = NEW.order_id
              AND refund.id <> NEW.id
          ), 0)
          - NEW.amount
        )) / MAX(0.01, (
          (SELECT total_amount FROM orders WHERE id = NEW.order_id)
          - COALESCE((
            SELECT SUM(refund.amount)
            FROM order_refunds refund
            WHERE refund.order_id = NEW.order_id
              AND refund.id <> NEW.id
          ), 0)
        )), 2) <= 0 THEN 'rejected'
        ELSE status
      END ,
      invalid_reason = CASE
        WHEN ROUND(commission_amount * MAX(0, (
          (SELECT total_amount FROM orders WHERE id = NEW.order_id)
          - COALESCE((
            SELECT SUM(refund.amount)
            FROM order_refunds refund
            WHERE refund.order_id = NEW.order_id
              AND refund.id <> NEW.id
          ), 0)
          - NEW.amount
        )) / MAX(0.01, (
          (SELECT total_amount FROM orders WHERE id = NEW.order_id)
          - COALESCE((
            SELECT SUM(refund.amount)
            FROM order_refunds refund
            WHERE refund.order_id = NEW.order_id
              AND refund.id <> NEW.id
          ), 0)
        )), 2) <= 0 THEN 'order_refunded'
        ELSE invalid_reason
      END ,
      confirm_at = CASE WHEN status = 'rejected' THEN NULL ELSE confirm_at END ,
      available_at = CASE WHEN status = 'rejected' THEN NULL ELSE available_at END ,
      updated_at = CURRENT_TIMESTAMP
  WHERE order_id = NEW.order_id
    AND status IN ('pending_confirm', 'available')
    AND withdraw_request_id IS NULL;

  UPDATE affiliate_commissions
  SET confirm_at = NULL, available_at = NULL, updated_at = CURRENT_TIMESTAMP
  WHERE order_id = NEW.order_id
    AND status = 'rejected'
    AND withdraw_request_id IS NULL;

  UPDATE affiliate_profiles
  SET total_earnings = ROUND(COALESCE((
        SELECT SUM(commission_amount)
        FROM affiliate_commissions
        WHERE affiliate_profile_id = affiliate_profiles.id
          AND status <> 'rejected'
      ), 0), 2),
      pending_earnings = ROUND(COALESCE((
        SELECT SUM(commission_amount)
        FROM affiliate_commissions
        WHERE affiliate_profile_id = affiliate_profiles.id
          AND status = 'pending_confirm'
      ), 0), 2),
      confirmed_earnings = ROUND(COALESCE((
        SELECT SUM(commission_amount)
        FROM affiliate_commissions
        WHERE affiliate_profile_id = affiliate_profiles.id
          AND status = 'available'
          AND withdraw_request_id IS NULL
      ), 0), 2),
      total_referrals = COALESCE((
        SELECT COUNT(DISTINCT order_id)
        FROM affiliate_commissions
        WHERE affiliate_profile_id = affiliate_profiles.id
          AND status <> 'rejected'
      ), 0),
      updated_at = CURRENT_TIMESTAMP
  WHERE id IN (
    SELECT affiliate_profile_id
    FROM affiliate_commissions
    WHERE order_id = NEW.order_id
  );
END;

CREATE TRIGGER trg_affiliate_order_canceled
AFTER UPDATE OF status ON orders
WHEN NEW.status = 'canceled' AND OLD.status <> 'canceled'
BEGIN
  UPDATE affiliate_commissions
  SET status = 'rejected', invalid_reason = 'order_canceled',
      confirm_at = NULL, available_at = NULL, updated_at = CURRENT_TIMESTAMP
  WHERE order_id = NEW.id
    AND status IN ('pending_confirm', 'available')
    AND withdraw_request_id IS NULL;

  UPDATE affiliate_profiles
  SET total_earnings = ROUND(COALESCE((
        SELECT SUM(commission_amount)
        FROM affiliate_commissions
        WHERE affiliate_profile_id = affiliate_profiles.id
          AND status <> 'rejected'
      ), 0), 2),
      pending_earnings = ROUND(COALESCE((
        SELECT SUM(commission_amount)
        FROM affiliate_commissions
        WHERE affiliate_profile_id = affiliate_profiles.id
          AND status = 'pending_confirm'
      ), 0), 2),
      confirmed_earnings = ROUND(COALESCE((
        SELECT SUM(commission_amount)
        FROM affiliate_commissions
        WHERE affiliate_profile_id = affiliate_profiles.id
          AND status = 'available'
          AND withdraw_request_id IS NULL
      ), 0), 2),
      total_referrals = COALESCE((
        SELECT COUNT(DISTINCT order_id)
        FROM affiliate_commissions
        WHERE affiliate_profile_id = affiliate_profiles.id
          AND status <> 'rejected'
      ), 0),
      updated_at = CURRENT_TIMESTAMP
  WHERE id IN (
    SELECT affiliate_profile_id
    FROM affiliate_commissions
    WHERE order_id = NEW.id
  );
END;
