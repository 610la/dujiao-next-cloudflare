DROP TRIGGER IF EXISTS trg_gift_cards_apply_redeem;

CREATE TRIGGER trg_gift_cards_apply_redeem
AFTER UPDATE OF status, redeemed_at, redeemed_user_id ON gift_cards
WHEN OLD.status = 'active'
  AND NEW.status = 'redeemed'
  AND EXISTS (
    SELECT 1
    FROM settings
    WHERE key = 'atomic_gift_card_redeem_enabled'
      AND value_json = 'true'
  )
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

INSERT INTO settings (key, value_json)
VALUES ('atomic_gift_card_redeem_enabled', 'false')
ON CONFLICT(key) DO NOTHING;
