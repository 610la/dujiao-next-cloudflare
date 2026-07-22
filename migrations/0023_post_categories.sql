CREATE TABLE IF NOT EXISTS post_categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  parent_id INTEGER,
  slug TEXT NOT NULL UNIQUE,
  name_json TEXT NOT NULL DEFAULT '{}',
  icon TEXT NOT NULL DEFAULT '',
  is_active INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (parent_id) REFERENCES post_categories(id) ON DELETE SET NULL
);

ALTER TABLE posts ADD COLUMN category_id INTEGER;

CREATE INDEX IF NOT EXISTS idx_post_categories_parent ON post_categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_post_categories_active ON post_categories(is_active);
CREATE INDEX IF NOT EXISTS idx_post_categories_sort ON post_categories(sort_order, id);
CREATE INDEX IF NOT EXISTS idx_posts_category ON posts(category_id);
