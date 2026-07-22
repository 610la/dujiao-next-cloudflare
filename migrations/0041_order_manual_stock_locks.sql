CREATE TABLE IF NOT EXISTS order_manual_stock_locks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL,
  sku_id INTEGER NOT NULL,
  quantity INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'reserved',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(order_id, sku_id),
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  FOREIGN KEY (sku_id) REFERENCES product_skus(id) ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS idx_order_manual_stock_locks_status
ON order_manual_stock_locks(status, order_id);

INSERT OR IGNORE INTO order_manual_stock_locks (order_id, sku_id, quantity, status)
SELECT oi.order_id, oi.sku_id, SUM(oi.quantity), 'reserved'
FROM order_items oi
JOIN orders o ON o.id = oi.order_id
WHERE o.status = 'pending_payment'
  AND COALESCE(NULLIF(oi.fulfillment_type, ''), 'manual') = 'manual'
GROUP BY oi.order_id, oi.sku_id;

UPDATE product_skus
SET manual_stock_total = manual_stock_total + manual_stock_locked - COALESCE((
      SELECT SUM(quantity)
      FROM order_manual_stock_locks l
      WHERE l.sku_id = product_skus.id AND l.status = 'reserved'
    ), 0),
    manual_stock_locked = COALESCE((
      SELECT SUM(quantity)
      FROM order_manual_stock_locks l
      WHERE l.sku_id = product_skus.id AND l.status = 'reserved'
    ), 0),
    updated_at = CURRENT_TIMESTAMP
WHERE manual_stock_total >= 0;

CREATE TRIGGER IF NOT EXISTS trg_manual_stock_locks_validate_insert
BEFORE INSERT ON order_manual_stock_locks
BEGIN
  SELECT CASE
    WHEN NEW.quantity <= 0 OR NEW.status <> 'reserved'
      THEN RAISE(ABORT, 'manual_stock_reserve_invalid')
    WHEN NOT EXISTS (SELECT 1 FROM orders WHERE id = NEW.order_id)
      THEN RAISE(ABORT, 'manual_stock_reserve_invalid')
    WHEN NOT EXISTS (SELECT 1 FROM product_skus WHERE id = NEW.sku_id)
      THEN RAISE(ABORT, 'manual_stock_reserve_invalid')
    WHEN EXISTS (
      SELECT 1 FROM product_skus
      WHERE id = NEW.sku_id
        AND manual_stock_total >= 0
        AND manual_stock_total < NEW.quantity
    ) THEN RAISE(ABORT, 'manual_stock_reserve_insufficient')
  END;
END;

CREATE TRIGGER IF NOT EXISTS trg_manual_stock_locks_apply_insert
AFTER INSERT ON order_manual_stock_locks
BEGIN
  UPDATE product_skus
  SET manual_stock_total = manual_stock_total - NEW.quantity,
      manual_stock_locked = manual_stock_locked + NEW.quantity,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.sku_id AND manual_stock_total >= 0;
END;

CREATE TRIGGER IF NOT EXISTS trg_manual_stock_locks_apply_release
AFTER UPDATE OF status ON order_manual_stock_locks
WHEN OLD.status = 'reserved' AND NEW.status = 'released'
BEGIN
  UPDATE product_skus
  SET manual_stock_total = manual_stock_total + OLD.quantity,
      manual_stock_locked = manual_stock_locked - OLD.quantity,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = OLD.sku_id AND manual_stock_total >= 0 AND manual_stock_locked >= OLD.quantity;
END;

CREATE TRIGGER IF NOT EXISTS trg_manual_stock_locks_apply_consume
AFTER UPDATE OF status ON order_manual_stock_locks
WHEN OLD.status = 'reserved' AND NEW.status = 'consumed'
BEGIN
  UPDATE product_skus
  SET manual_stock_locked = manual_stock_locked - OLD.quantity,
      manual_stock_sold = manual_stock_sold + OLD.quantity,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = OLD.sku_id AND manual_stock_total >= 0 AND manual_stock_locked >= OLD.quantity;
END;

CREATE TRIGGER IF NOT EXISTS trg_manual_stock_locks_release_on_delete
BEFORE DELETE ON order_manual_stock_locks
WHEN OLD.status = 'reserved'
BEGIN
  UPDATE product_skus
  SET manual_stock_total = manual_stock_total + OLD.quantity,
      manual_stock_locked = manual_stock_locked - OLD.quantity,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = OLD.sku_id AND manual_stock_total >= 0 AND manual_stock_locked >= OLD.quantity;
END;

DROP TRIGGER IF EXISTS trg_order_processing_validate_manual_stock;
DROP TRIGGER IF EXISTS trg_order_processing_apply_manual_stock;

CREATE TRIGGER trg_order_processing_validate_manual_stock
BEFORE UPDATE OF manual_stock_claimed_at ON order_processing_state
WHEN OLD.manual_stock_claimed_at IS NULL AND NEW.manual_stock_claimed_at IS NOT NULL
BEGIN
  SELECT CASE
    WHEN EXISTS (
      SELECT 1
      FROM order_items oi
      LEFT JOIN order_manual_stock_locks l
        ON l.order_id = oi.order_id AND l.sku_id = oi.sku_id
      WHERE oi.order_id = NEW.order_id
        AND COALESCE(NULLIF(oi.fulfillment_type, ''), 'manual') = 'manual'
      GROUP BY oi.sku_id
      HAVING l.id IS NULL
        OR l.status NOT IN ('reserved', 'consumed')
        OR l.quantity <> SUM(oi.quantity)
    ) THEN RAISE(ABORT, 'manual_stock_lock_missing')
  END;
END;

CREATE TRIGGER trg_order_processing_apply_manual_stock
AFTER UPDATE OF manual_stock_claimed_at ON order_processing_state
WHEN OLD.manual_stock_claimed_at IS NULL AND NEW.manual_stock_claimed_at IS NOT NULL
BEGIN
  UPDATE order_manual_stock_locks
  SET status = 'consumed', updated_at = CURRENT_TIMESTAMP
  WHERE order_id = NEW.order_id AND status = 'reserved';
END;
