TRUNCATE TABLE `${BQ_PROJECT}.${BQ_ODS}.sales`;

INSERT INTO `${BQ_PROJECT}.${BQ_ODS}.sales`
  (sale_id, customer_id, sale_date, amount, quantity,
   last_modified_ts, is_deleted, dwh_loaded_ts)
SELECT
  sale_id,
  customer_id,
  sale_date,
  CAST(amount AS NUMERIC),
  quantity,
  last_modified_ts,
  FALSE,
  CURRENT_TIMESTAMP()
FROM `${BQ_PROJECT}.${BQ_LANDING}.sales_full`;
