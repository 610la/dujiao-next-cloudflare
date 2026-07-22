CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  password_salt TEXT NOT NULL DEFAULT '',
  password_hash TEXT NOT NULL DEFAULT '',
  nickname TEXT NOT NULL DEFAULT '',
  display_name TEXT NOT NULL DEFAULT '',
  locale TEXT NOT NULL DEFAULT 'zh-CN',
  status TEXT NOT NULL DEFAULT 'active',
  email_verified_at TEXT,
  member_level_id INTEGER NOT NULL DEFAULT 0,
  total_recharged REAL NOT NULL DEFAULT 0,
  total_spent REAL NOT NULL DEFAULT 0,
  admin_note TEXT NOT NULL DEFAULT '',
  last_login_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);
CREATE INDEX IF NOT EXISTS idx_users_last_login_at ON users(last_login_at);

CREATE TABLE IF NOT EXISTS user_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at ON user_sessions(expires_at);

CREATE TABLE IF NOT EXISTS user_login_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL DEFAULT 0,
  email TEXT NOT NULL DEFAULT '',
  client_ip TEXT NOT NULL DEFAULT '',
  user_agent TEXT NOT NULL DEFAULT '',
  login_source TEXT NOT NULL DEFAULT 'web',
  status TEXT NOT NULL DEFAULT 'success',
  fail_reason TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_user_login_logs_user_id ON user_login_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_user_login_logs_email ON user_login_logs(email);
CREATE INDEX IF NOT EXISTS idx_user_login_logs_status ON user_login_logs(status);
CREATE INDEX IF NOT EXISTS idx_user_login_logs_created_at ON user_login_logs(created_at);

CREATE TABLE IF NOT EXISTS user_wallets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL UNIQUE,
  balance REAL NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'CNY',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS wallet_transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  order_id INTEGER,
  type TEXT NOT NULL DEFAULT 'adjust',
  direction TEXT NOT NULL DEFAULT 'in',
  amount REAL NOT NULL DEFAULT 0,
  balance_before REAL NOT NULL DEFAULT 0,
  balance_after REAL NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'CNY',
  reference TEXT NOT NULL DEFAULT '',
  remark TEXT NOT NULL DEFAULT '',
  related_type TEXT NOT NULL DEFAULT '',
  related_id INTEGER,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_wallet_transactions_user_id ON wallet_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_type ON wallet_transactions(type);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created_at ON wallet_transactions(created_at);

CREATE TABLE IF NOT EXISTS wallet_recharges (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  recharge_no TEXT NOT NULL UNIQUE,
  user_id INTEGER NOT NULL,
  payment_id INTEGER NOT NULL DEFAULT 0,
  channel_id INTEGER NOT NULL DEFAULT 0,
  channel_name TEXT NOT NULL DEFAULT '',
  provider_type TEXT NOT NULL DEFAULT 'manual',
  channel_type TEXT NOT NULL DEFAULT 'balance',
  interaction_mode TEXT NOT NULL DEFAULT 'none',
  amount REAL NOT NULL DEFAULT 0,
  payable_amount REAL NOT NULL DEFAULT 0,
  fee_rate REAL NOT NULL DEFAULT 0,
  fee_amount REAL NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'CNY',
  status TEXT NOT NULL DEFAULT 'pending',
  remark TEXT NOT NULL DEFAULT '',
  paid_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_wallet_recharges_user_id ON wallet_recharges(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_recharges_status ON wallet_recharges(status);
CREATE INDEX IF NOT EXISTS idx_wallet_recharges_created_at ON wallet_recharges(created_at);
CREATE INDEX IF NOT EXISTS idx_wallet_recharges_paid_at ON wallet_recharges(paid_at);
