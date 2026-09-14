-- Landing to ODS. TRUNCATE plus INSERT rather than CREATE OR REPLACE,
-- because the table itself is managed by Terraform and must keep its
-- declared schema, clustering and partitioning.
TRUNCATE TABLE `${BQ_PROJECT}.${BQ_ODS}.customer`;

INSERT INTO `${BQ_PROJECT}.${BQ_ODS}.customer`
  (customer_id, customer_name, city, segment, last_modified_ts, is_deleted, dwh_loaded_ts)
SELECT
  customer_id,
  customer_name,
  city,
  segment,
  last_modified_ts,
  FALSE,
  CURRENT_TIMESTAMP()
FROM `${BQ_PROJECT}.${BQ_LANDING}.customer_full`;
