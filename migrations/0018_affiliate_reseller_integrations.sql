ALTER TABLE orders ADD COLUMN affiliate_profile_id INTEGER NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN affiliate_code TEXT NOT NULL DEFAULT '';
ALTER TABLE orders ADD COLUMN affiliate_visitor_key TEXT NOT NULL DEFAULT '';
ALTER TABLE orders ADD COLUMN reseller_id INTEGER NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN reseller_domain TEXT NOT NULL DEFAULT '';
ALTER TABLE orders ADD COLUMN reseller_base_amount REAL NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN reseller_profit_amount REAL NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN reseller_profit_status TEXT NOT NULL DEFAULT '';

CREATE TABLE IF NOT EXISTS user_oauth_identities (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  provider TEXT NOT NULL DEFAULT 'telegram',
  provider_user_id TEXT NOT NULL,
  username TEXT NOT NULL DEFAULT '',
  first_name TEXT NOT NULL DEFAULT '',
  last_name TEXT NOT NULL DEFAULT '',
  avatar_url TEXT NOT NULL DEFAULT '',
  auth_at TEXT,
  raw_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  UNIQUE(provider, provider_user_id)
);

CREATE TABLE IF NOT EXISTS affiliate_profiles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL UNIQUE,
  code TEXT NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'active',
  total_earnings REAL NOT NULL DEFAULT 0,
  pending_earnings REAL NOT NULL DEFAULT 0,
  confirmed_earnings REAL NOT NULL DEFAULT 0,
  withdrawn_earnings REAL NOT NULL DEFAULT 0,
  total_referrals INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS affiliate_clicks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  affiliate_profile_id INTEGER NOT NULL DEFAULT 0,
  affiliate_code TEXT NOT NULL DEFAULT '',
  visitor_key TEXT NOT NULL DEFAULT '',
  landing_path TEXT NOT NULL DEFAULT '',
  referrer TEXT NOT NULL DEFAULT '',
  client_ip TEXT NOT NULL DEFAULT '',
  user_agent TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS affiliate_commissions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  affiliate_profile_id INTEGER NOT NULL,
  order_id INTEGER NOT NULL,
  order_no TEXT NOT NULL DEFAULT '',
  commission_type TEXT NOT NULL DEFAULT 'order',
  base_amount REAL NOT NULL DEFAULT 0,
  rate_percent REAL NOT NULL DEFAULT 0,
  commission_amount REAL NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending_confirm',
  confirm_at TEXT,
  available_at TEXT,
  withdrawn_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (affiliate_profile_id) REFERENCES affiliate_profiles(id) ON DELETE CASCADE,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
  UNIQUE(affiliate_profile_id, order_id)
);

CREATE TABLE IF NOT EXISTS affiliate_withdraws (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  affiliate_profile_id INTEGER NOT NULL,
  amount REAL NOT NULL DEFAULT 0,
  channel TEXT NOT NULL DEFAULT '',
  account_info TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending_review',
  reject_reason TEXT NOT NULL DEFAULT '',
  processed_by INTEGER,
  processed_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (affiliate_profile_id) REFERENCES affiliate_profiles(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS reseller_profiles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL UNIQUE,
  status TEXT NOT NULL DEFAULT 'pending_review',
  apply_reason TEXT NOT NULL DEFAULT '',
  reject_reason TEXT NOT NULL DEFAULT '',
  default_markup_percent REAL NOT NULL DEFAULT 0,
  max_markup_percent REAL NOT NULL DEFAULT 0,
  settlement_status TEXT NOT NULL DEFAULT 'normal',
  reviewed_by INTEGER,
  reviewed_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS reseller_domains (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reseller_id INTEGER NOT NULL,
  domain TEXT NOT NULL UNIQUE,
  type TEXT NOT NULL DEFAULT 'custom',
  verification_token TEXT NOT NULL DEFAULT '',
  verification_status TEXT NOT NULL DEFAULT 'pending',
  status TEXT NOT NULL DEFAULT 'pending_review',
  is_primary INTEGER NOT NULL DEFAULT 0,
  verified_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (reseller_id) REFERENCES reseller_profiles(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS reseller_site_configs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reseller_id INTEGER NOT NULL UNIQUE,
  site_name TEXT NOT NULL DEFAULT '',
  logo TEXT NOT NULL DEFAULT '',
  favicon TEXT NOT NULL DEFAULT '',
  announcement_json TEXT NOT NULL DEFAULT '{}',
  support_json TEXT NOT NULL DEFAULT '{}',
  seo_json TEXT NOT NULL DEFAULT '{}',
  footer_links_json TEXT NOT NULL DEFAULT '[]',
  nav_config_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (reseller_id) REFERENCES reseller_profiles(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS reseller_product_settings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reseller_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  sku_id INTEGER NOT NULL DEFAULT 0,
  is_listed INTEGER NOT NULL DEFAULT 1,
  pricing_mode TEXT NOT NULL DEFAULT 'inherit',
  markup_percent REAL NOT NULL DEFAULT 0,
  fixed_markup_amount REAL NOT NULL DEFAULT 0,
  fixed_price_amount REAL NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (reseller_id) REFERENCES reseller_profiles(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
  UNIQUE(reseller_id, product_id, sku_id)
);

CREATE TABLE IF NOT EXISTS reseller_balance_accounts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reseller_id INTEGER NOT NULL,
  currency TEXT NOT NULL DEFAULT 'CNY',
  status TEXT NOT NULL DEFAULT 'normal',
  available_amount_cache REAL NOT NULL DEFAULT 0,
  locked_amount_cache REAL NOT NULL DEFAULT 0,
  negative_amount_cache REAL NOT NULL DEFAULT 0,
  last_ledger_entry_id INTEGER NOT NULL DEFAULT 0,
  risk_note TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (reseller_id) REFERENCES reseller_profiles(id) ON DELETE CASCADE,
  UNIQUE(reseller_id, currency)
);

CREATE TABLE IF NOT EXISTS reseller_ledger_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reseller_id INTEGER NOT NULL,
  order_id INTEGER,
  type TEXT NOT NULL DEFAULT 'order_profit',
  amount REAL NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'CNY',
  idempotency_key TEXT NOT NULL DEFAULT '',
  metadata_json TEXT NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'available',
  available_at TEXT,
  withdraw_request_id INTEGER,
  remark TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (reseller_id) REFERENCES reseller_profiles(id) ON DELETE CASCADE,
  FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS reseller_withdraws (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  reseller_id INTEGER NOT NULL,
  amount REAL NOT NULL DEFAULT 0,
  currency TEXT NOT NULL DEFAULT 'CNY',
  channel TEXT NOT NULL DEFAULT '',
  account TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending_review',
  reject_reason TEXT NOT NULL DEFAULT '',
  processed_by INTEGER,
  processed_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (reseller_id) REFERENCES reseller_profiles(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS channel_clients (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL DEFAULT '',
  channel_type TEXT NOT NULL DEFAULT 'telegram_bot',
  description TEXT NOT NULL DEFAULT '',
  bot_token_hash TEXT NOT NULL DEFAULT '',
  bot_token_tail TEXT NOT NULL DEFAULT '',
  callback_url TEXT NOT NULL DEFAULT '',
  client_secret_hash TEXT NOT NULL DEFAULT '',
  client_secret_tail TEXT NOT NULL DEFAULT '',
  status INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS telegram_broadcasts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL DEFAULT '',
  recipient_type TEXT NOT NULL DEFAULT 'all',
  filters_json TEXT NOT NULL DEFAULT '{}',
  attachment_url TEXT NOT NULL DEFAULT '',
  attachment_name TEXT NOT NULL DEFAULT '',
  message_html TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'draft',
  total_recipients INTEGER NOT NULL DEFAULT 0,
  sent_count INTEGER NOT NULL DEFAULT 0,
  failed_count INTEGER NOT NULL DEFAULT 0,
  created_by INTEGER,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS telegram_broadcast_targets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  broadcast_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL DEFAULT 0,
  telegram_user_id TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending',
  error_message TEXT NOT NULL DEFAULT '',
  sent_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (broadcast_id) REFERENCES telegram_broadcasts(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_oauth_user ON user_oauth_identities(user_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_clicks_code ON affiliate_clicks(affiliate_code);
CREATE INDEX IF NOT EXISTS idx_affiliate_clicks_created_at ON affiliate_clicks(created_at);
CREATE INDEX IF NOT EXISTS idx_affiliate_commissions_profile ON affiliate_commissions(affiliate_profile_id);
CREATE INDEX IF NOT EXISTS idx_affiliate_commissions_status ON affiliate_commissions(status);
CREATE INDEX IF NOT EXISTS idx_affiliate_withdraws_profile ON affiliate_withdraws(affiliate_profile_id);
CREATE INDEX IF NOT EXISTS idx_reseller_profiles_status ON reseller_profiles(status);
CREATE INDEX IF NOT EXISTS idx_reseller_domains_reseller ON reseller_domains(reseller_id);
CREATE INDEX IF NOT EXISTS idx_reseller_product_settings_reseller ON reseller_product_settings(reseller_id);
CREATE INDEX IF NOT EXISTS idx_reseller_ledger_reseller ON reseller_ledger_entries(reseller_id);
CREATE INDEX IF NOT EXISTS idx_reseller_withdraws_reseller ON reseller_withdraws(reseller_id);
CREATE INDEX IF NOT EXISTS idx_channel_clients_type ON channel_clients(channel_type);
CREATE INDEX IF NOT EXISTS idx_telegram_broadcasts_status ON telegram_broadcasts(status);
