ALTER TABLE order_processing_state ADD COLUMN manual_stock_claimed_at TEXT;

UPDATE order_processing_state
SET manual_stock_claimed_at = manual_stock_consumed_at
WHERE manual_stock_consumed_at IS NOT NULL;

CREATE TRIGGER IF NOT EXISTS trg_order_processing_validate_manual_stock
BEFORE UPDATE OF manual_stock_claimed_at ON order_processing_state
WHEN OLD.manual_stock_claimed_at IS NULL AND NEW.manual_stock_claimed_at IS NOT NULL
BEGIN
  SELECT CASE
    WHEN EXISTS (
      SELECT 1
      FROM order_items oi
      LEFT JOIN product_skus s ON s.id = oi.sku_id
      WHERE oi.order_id = NEW.order_id
        AND oi.sku_id > 0
        AND COALESCE(NULLIF(oi.fulfillment_type, ''), 'manual') = 'manual'
        AND s.id IS NULL
    ) THEN RAISE(ABORT, 'manual_stock_sku_missing')
    WHEN EXISTS (
      SELECT 1
      FROM product_skus s
      WHERE s.manual_stock_total >= 0
        AND (
          SELECT COALESCE(SUM(oi.quantity), 0)
          FROM order_items oi
          WHERE oi.order_id = NEW.order_id
            AND oi.sku_id = s.id
            AND COALESCE(NULLIF(oi.fulfillment_type, ''), 'manual') = 'manual'
        ) > 0
        AND NOT (
          s.manual_stock_locked >= (
            SELECT COALESCE(SUM(oi.quantity), 0)
            FROM order_items oi
            WHERE oi.order_id = NEW.order_id
              AND oi.sku_id = s.id
              AND COALESCE(NULLIF(oi.fulfillment_type, ''), 'manual') = 'manual'
          )
          OR s.manual_stock_total >= (
            SELECT COALESCE(SUM(oi.quantity), 0)
            FROM order_items oi
            WHERE oi.order_id = NEW.order_id
              AND oi.sku_id = s.id
              AND COALESCE(NULLIF(oi.fulfillment_type, ''), 'manual') = 'manual'
          ) - s.manual_stock_locked
        )
    ) THEN RAISE(ABORT, 'manual_stock_consume_insufficient')
  END;
END;

CREATE TRIGGER IF NOT EXISTS trg_order_processing_apply_manual_stock
AFTER UPDATE OF manual_stock_claimed_at ON order_processing_state
WHEN OLD.manual_stock_claimed_at IS NULL AND NEW.manual_stock_claimed_at IS NOT NULL
BEGIN
  UPDATE product_skus
  SET manual_stock_total = manual_stock_total - CASE
        WHEN manual_stock_locked >= (
          SELECT COALESCE(SUM(oi.quantity), 0)
          FROM order_items oi
          WHERE oi.order_id = NEW.order_id
            AND oi.sku_id = product_skus.id
            AND COALESCE(NULLIF(oi.fulfillment_type, ''), 'manual') = 'manual'
        ) THEN 0
        ELSE (
          SELECT COALESCE(SUM(oi.quantity), 0)
          FROM order_items oi
          WHERE oi.order_id = NEW.order_id
            AND oi.sku_id = product_skus.id
            AND COALESCE(NULLIF(oi.fulfillment_type, ''), 'manual') = 'manual'
        ) - manual_stock_locked
      END ,
      manual_stock_locked = CASE
        WHEN manual_stock_locked >= (
          SELECT COALESCE(SUM(oi.quantity), 0)
          FROM order_items oi
          WHERE oi.order_id = NEW.order_id
            AND oi.sku_id = product_skus.id
            AND COALESCE(NULLIF(oi.fulfillment_type, ''), 'manual') = 'manual'
        ) THEN manual_stock_locked - (
          SELECT COALESCE(SUM(oi.quantity), 0)
          FROM order_items oi
          WHERE oi.order_id = NEW.order_id
            AND oi.sku_id = product_skus.id
            AND COALESCE(NULLIF(oi.fulfillment_type, ''), 'manual') = 'manual'
        )
        ELSE 0
      END ,
      manual_stock_sold = manual_stock_sold + (
        SELECT COALESCE(SUM(oi.quantity), 0)
        FROM order_items oi
        WHERE oi.order_id = NEW.order_id
          AND oi.sku_id = product_skus.id
          AND COALESCE(NULLIF(oi.fulfillment_type, ''), 'manual') = 'manual'
      ),
      updated_at = CURRENT_TIMESTAMP
  WHERE manual_stock_total >= 0
    AND id IN (
      SELECT oi.sku_id
      FROM order_items oi
      WHERE oi.order_id = NEW.order_id
        AND oi.sku_id > 0
        AND COALESCE(NULLIF(oi.fulfillment_type, ''), 'manual') = 'manual'
    );
END;
