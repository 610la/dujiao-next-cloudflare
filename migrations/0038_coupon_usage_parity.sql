-- One order can consume at most one coupon usage record. The upstream
-- per-user limit applies to authenticated users; guest email is not a user ID.
DELETE FROM coupon_usages
WHERE id NOT IN (
  SELECT MIN(id)
  FROM coupon_usages
  GROUP BY order_id
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_coupon_usages_order_unique
ON coupon_usages(order_id);

DROP TRIGGER IF EXISTS trg_coupon_usages_validate;

CREATE TRIGGER trg_coupon_usages_validate
BEFORE INSERT ON coupon_usages
BEGIN
  SELECT CASE
    WHEN NOT EXISTS (
      SELECT 1 FROM coupons WHERE id = NEW.coupon_id AND is_active = 1
    ) THEN RAISE(ABORT, 'coupon_unavailable')
    WHEN EXISTS (
      SELECT 1
      FROM coupons
      WHERE id = NEW.coupon_id
        AND usage_limit > 0
        AND (
          SELECT COUNT(*) FROM coupon_usages WHERE coupon_id = NEW.coupon_id
        ) >= usage_limit
    ) THEN RAISE(ABORT, 'coupon_usage_limit_reached')
    WHEN NEW.user_id > 0 AND EXISTS (
      SELECT 1
      FROM coupons c
      WHERE c.id = NEW.coupon_id
        AND c.per_user_limit > 0
        AND (
          SELECT COUNT(*)
          FROM coupon_usages cu
          WHERE cu.coupon_id = NEW.coupon_id AND cu.user_id = NEW.user_id
        ) >= c.per_user_limit
    ) THEN RAISE(ABORT, 'coupon_user_limit_reached')
  END;
END;
