UPDATE coupons
SET used_count = (
  SELECT COUNT(*) FROM coupon_usages WHERE coupon_usages.coupon_id = coupons.id
),
updated_at = CURRENT_TIMESTAMP;

CREATE TRIGGER IF NOT EXISTS trg_coupon_usages_validate
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
    WHEN NEW.user_id = 0 AND NEW.guest_email <> '' AND EXISTS (
      SELECT 1
      FROM coupons c
      WHERE c.id = NEW.coupon_id
        AND c.per_user_limit > 0
        AND (
          SELECT COUNT(*)
          FROM coupon_usages cu
          WHERE cu.coupon_id = NEW.coupon_id
            AND cu.user_id = 0
            AND lower(cu.guest_email) = lower(NEW.guest_email)
        ) >= c.per_user_limit
    ) THEN RAISE(ABORT, 'coupon_user_limit_reached')
  END;
END;

CREATE TRIGGER IF NOT EXISTS trg_coupon_usages_increment
AFTER INSERT ON coupon_usages
BEGIN
  UPDATE coupons
  SET used_count = (
        SELECT COUNT(*) FROM coupon_usages WHERE coupon_id = NEW.coupon_id
      ),
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.coupon_id;
END;

CREATE TRIGGER IF NOT EXISTS trg_coupon_usages_decrement
AFTER DELETE ON coupon_usages
BEGIN
  UPDATE coupons
  SET used_count = (
        SELECT COUNT(*) FROM coupon_usages WHERE coupon_id = OLD.coupon_id
      ),
      updated_at = CURRENT_TIMESTAMP
  WHERE id = OLD.coupon_id;
END;
