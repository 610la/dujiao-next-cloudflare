UPDATE card_secret_batches
SET batch_no = 'CS-MIG-' || id
WHERE TRIM(batch_no) = '';

WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (PARTITION BY batch_no ORDER BY id ASC) AS duplicate_rank
  FROM card_secret_batches
)
UPDATE card_secret_batches
SET batch_no = batch_no || '-MIG-' || LOWER(HEX(RANDOMBLOB(6)))
WHERE id IN (SELECT id FROM ranked WHERE duplicate_rank > 1);

CREATE UNIQUE INDEX IF NOT EXISTS idx_card_secret_batches_batch_no_unique
ON card_secret_batches(batch_no);
