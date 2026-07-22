CREATE TABLE IF NOT EXISTS authz_roles (
  role TEXT PRIMARY KEY,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS authz_policies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  role TEXT NOT NULL,
  object TEXT NOT NULL,
  action TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(role, object, action),
  FOREIGN KEY (role) REFERENCES authz_roles(role) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS authz_admin_roles (
  admin_id INTEGER NOT NULL,
  role TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY(admin_id, role),
  FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE,
  FOREIGN KEY (role) REFERENCES authz_roles(role) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS authz_audit_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  operator_admin_id INTEGER NOT NULL DEFAULT 0,
  operator_username TEXT NOT NULL DEFAULT '',
  target_admin_id INTEGER NOT NULL DEFAULT 0,
  target_username TEXT NOT NULL DEFAULT '',
  action TEXT NOT NULL DEFAULT '',
  role TEXT NOT NULL DEFAULT '',
  object TEXT NOT NULL DEFAULT '',
  method TEXT NOT NULL DEFAULT '',
  request_id TEXT NOT NULL DEFAULT '',
  detail_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_authz_policies_role ON authz_policies(role);
CREATE INDEX IF NOT EXISTS idx_authz_admin_roles_admin_id ON authz_admin_roles(admin_id);
CREATE INDEX IF NOT EXISTS idx_authz_admin_roles_role ON authz_admin_roles(role);
CREATE INDEX IF NOT EXISTS idx_authz_audit_logs_action ON authz_audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_authz_audit_logs_created_at ON authz_audit_logs(created_at);

INSERT OR IGNORE INTO authz_roles (role) VALUES ('role:super_admin');
INSERT OR IGNORE INTO authz_policies (role, object, action) VALUES ('role:super_admin', '/*', '*');
