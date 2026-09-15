-- The delta landing tables are normally created by the Data Fusion pipeline
-- on its first run. Declaring them here means a brand new environment can be
-- deployed before any data has ever arrived in it.
CREATE TABLE IF NOT EXISTS `${BQ_PROJECT}.${BQ_LANDING}.customer_delta` (
  customer_id      INT64,
  customer_name    STRING,
  city             STRING,
  segment          STRING,
  last_modified_ts TIMESTAMP,
  is_deleted       BOOL
);

CREATE TABLE IF NOT EXISTS `${BQ_PROJECT}.${BQ_LANDING}.sales_delta` (
  sale_id          INT64,
  customer_id      INT64,
  sale_date        DATE,
  amount           FLOAT64,
  quantity         INT64,
  last_modified_ts TIMESTAMP,
  is_deleted       BOOL
);