-- Dujiao stores manual_stock_total as the currently available quantity.
-- Older Worker builds stored the original capacity and subtracted locked/sold at read time.
UPDATE product_skus
SET manual_stock_total = MAX(0, manual_stock_total - manual_stock_locked - manual_stock_sold),
    updated_at = CURRENT_TIMESTAMP
WHERE manual_stock_total >= 0
  AND product_id IN (
    SELECT id FROM products WHERE fulfillment_type = 'manual'
  );

UPDATE products
SET manual_stock_total = MAX(0, manual_stock_total - manual_stock_locked - manual_stock_sold),
    updated_at = CURRENT_TIMESTAMP
WHERE manual_stock_total >= 0
  AND fulfillment_type = 'manual';

CREATE UNIQUE INDEX IF NOT EXISTS idx_coupon_usages_order_unique
ON coupon_usages(order_id);
