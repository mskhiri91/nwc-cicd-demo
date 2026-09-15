-- Delta load for the sales fact. Same three concerns as the customer merge:
--   1. deduplicate inside the batch, otherwise MERGE raises
--      "UPDATE/MERGE must match at most one source row for each target row"
--   2. only apply a change newer than what is already in ODS, so a replayed
--      batch cannot move the table backwards (idempotency)
--   3. advance the watermark in the same script

DECLARE v_watermark TIMESTAMP;

SET v_watermark = (
  SELECT last_watermark
  FROM `${BQ_PROJECT}.${BQ_ODS}.etl_watermark`
  WHERE table_name = 'sales'
);

MERGE `${BQ_PROJECT}.${BQ_ODS}.sales` T
USING (
  SELECT * EXCEPT(rn)
  FROM (
    SELECT
      sale_id,
      customer_id,
      sale_date,
      CAST(amount AS NUMERIC) AS amount,
      quantity,
      last_modified_ts,
      is_deleted,
      ROW_NUMBER() OVER (
        PARTITION BY sale_id
        ORDER BY last_modified_ts DESC
      ) AS rn
    FROM `${BQ_PROJECT}.${BQ_LANDING}.sales_delta`
    WHERE last_modified_ts > v_watermark
  )
  WHERE rn = 1
) S
ON T.sale_id = S.sale_id

WHEN MATCHED AND S.last_modified_ts > T.last_modified_ts THEN UPDATE SET
  customer_id      = S.customer_id,
  sale_date        = S.sale_date,
  amount           = S.amount,
  quantity         = S.quantity,
  last_modified_ts = S.last_modified_ts,
  is_deleted       = S.is_deleted,
  dwh_loaded_ts    = CURRENT_TIMESTAMP()

WHEN NOT MATCHED THEN INSERT
  (sale_id, customer_id, sale_date, amount, quantity,
   last_modified_ts, is_deleted, dwh_loaded_ts)
VALUES
  (S.sale_id, S.customer_id, S.sale_date, S.amount, S.quantity,
   S.last_modified_ts, S.is_deleted, CURRENT_TIMESTAMP());

UPDATE `${BQ_PROJECT}.${BQ_ODS}.etl_watermark`
SET last_watermark = GREATEST(
      last_watermark,
      IFNULL((SELECT MAX(last_modified_ts)
              FROM `${BQ_PROJECT}.${BQ_LANDING}.sales_delta`), last_watermark)
    ),
    updated_ts = CURRENT_TIMESTAMP()
WHERE table_name = 'sales';