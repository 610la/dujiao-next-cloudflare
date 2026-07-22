ALTER TABLE admins ADD COLUMN totp_secret TEXT NOT NULL DEFAULT '';
ALTER TABLE admins ADD COLUMN totp_enabled_at TEXT;

CREATE TABLE IF NOT EXISTS admin_totp_setups (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  admin_id INTEGER NOT NULL,
  secret TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS admin_recovery_codes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  admin_id INTEGER NOT NULL,
  code_hash TEXT NOT NULL UNIQUE,
  used_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS admin_login_challenges (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  admin_id INTEGER NOT NULL,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_admin_totp_setups_admin_id ON admin_totp_setups(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_totp_setups_expires_at ON admin_totp_setups(expires_at);
CREATE INDEX IF NOT EXISTS idx_admin_recovery_codes_admin_id ON admin_recovery_codes(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_recovery_codes_used_at ON admin_recovery_codes(used_at);
CREATE INDEX IF NOT EXISTS idx_admin_login_challenges_admin_id ON admin_login_challenges(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_login_challenges_expires_at ON admin_login_challenges(expires_at);
