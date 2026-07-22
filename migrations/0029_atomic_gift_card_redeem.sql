CREATE TRIGGER IF NOT EXISTS trg_gift_cards_validate_redeem
BEFORE UPDATE OF status, redeemed_at, redeemed_user_id ON gift_cards
WHEN OLD.status = 'active' AND NEW.status = 'redeemed'
BEGIN
  SELECT CASE
    WHEN NEW.redeemed_at IS NULL THEN RAISE(ABORT, 'gift_card_redeemed_at_missing')
    WHEN NEW.redeemed_user_id IS NULL OR NEW.redeemed_user_id <= 0 THEN RAISE(ABORT, 'gift_card_user_invalid')
    WHEN NOT EXISTS (SELECT 1 FROM users WHERE id = NEW.redeemed_user_id AND status = 'active') THEN RAISE(ABORT, 'gift_card_user_invalid')
    WHEN NEW.amount <= 0 THEN RAISE(ABORT, 'gift_card_amount_invalid')
  END;
END;

CREATE TRIGGER IF NOT EXISTS trg_gift_cards_apply_redeem
AFTER UPDATE OF status, redeemed_at, redeemed_user_id ON gift_cards
WHEN OLD.status = 'active' AND NEW.status = 'redeemed'
BEGIN
  INSERT OR IGNORE INTO user_wallets (user_id, balance, currency)
  VALUES (NEW.redeemed_user_id, 0, NEW.currency);

  UPDATE user_wallets
  SET balance = ROUND(balance + NEW.amount, 2),
      updated_at = CURRENT_TIMESTAMP
  WHERE user_id = NEW.redeemed_user_id;

  INSERT INTO wallet_transactions (
    user_id, order_id, type, direction, amount,
    balance_before, balance_after, currency,
    reference, remark, related_type, related_id
  )
  SELECT
    NEW.redeemed_user_id,
    NULL,
    'gift_card',
    'in',
    ROUND(NEW.amount, 2),
    ROUND(balance - NEW.amount, 2),
    ROUND(balance, 2),
    NEW.currency,
    'GIFT:' || NEW.id,
    '礼品卡兑换 ' || NEW.code,
    'gift_card',
    NEW.id
  FROM user_wallets
  WHERE user_id = NEW.redeemed_user_id;

  UPDATE gift_cards
  SET wallet_txn_id = last_insert_rowid(),
      updated_at = CURRENT_TIMESTAMP
  WHERE id = NEW.id;
END;

CREATE UNIQUE INDEX IF NOT EXISTS idx_wallet_transactions_atomic_gift_card
ON wallet_transactions(reference)
WHERE type = 'gift_card' AND reference LIKE 'GIFT:%';
