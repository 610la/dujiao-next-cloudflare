ALTER TABLE orders ADD COLUMN guest_password_salt TEXT NOT NULL DEFAULT '';
ALTER TABLE orders ADD COLUMN guest_password_hash TEXT NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS idx_orders_guest_lookup ON orders(user_id, guest_email, order_no);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_admin_id ON admin_sessions(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_sessions_expires_at ON admin_sessions(expires_at);

CREATE TABLE IF NOT EXISTS admin_login_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  admin_id INTEGER NOT NULL DEFAULT 0,
  username TEXT NOT NULL DEFAULT '',
  client_ip TEXT NOT NULL DEFAULT '',
  user_agent TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'success',
  fail_reason TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_admin_login_logs_username ON admin_login_logs(username);
CREATE INDEX IF NOT EXISTS idx_admin_login_logs_client_ip ON admin_login_logs(client_ip);
CREATE INDEX IF NOT EXISTS idx_admin_login_logs_status ON admin_login_logs(status);
CREATE INDEX IF NOT EXISTS idx_admin_login_logs_created_at ON admin_login_logs(created_at);
