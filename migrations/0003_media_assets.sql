CREATE TABLE IF NOT EXISTS media_assets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  filename TEXT NOT NULL,
  path TEXT NOT NULL UNIQUE,
  storage_key TEXT NOT NULL UNIQUE,
  storage TEXT NOT NULL DEFAULT 'kv',
  mime_type TEXT NOT NULL,
  size INTEGER NOT NULL DEFAULT 0,
  scene TEXT NOT NULL DEFAULT 'common',
  width INTEGER NOT NULL DEFAULT 0,
  height INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_media_assets_scene ON media_assets(scene);
CREATE INDEX IF NOT EXISTS idx_media_assets_created_at ON media_assets(created_at);
