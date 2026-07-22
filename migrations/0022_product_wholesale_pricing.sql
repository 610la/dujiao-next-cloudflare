ALTER TABLE products ADD COLUMN wholesale_prices_json TEXT NOT NULL DEFAULT '[]';

ALTER TABLE order_items ADD COLUMN promotion_discount_amount REAL NOT NULL DEFAULT 0;
ALTER TABLE order_items ADD COLUMN wholesale_discount_amount REAL NOT NULL DEFAULT 0;
ALTER TABLE order_items ADD COLUMN member_discount_amount REAL NOT NULL DEFAULT 0;
