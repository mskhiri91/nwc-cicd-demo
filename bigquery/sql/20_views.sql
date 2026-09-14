-- The semantic layer reads these views, never the raw ODS tables.
-- That gives you a contract: you can refactor ODS without breaking AtScale.
CREATE OR REPLACE VIEW `${BQ_PROJECT}.${BQ_MART}.vw_dim_customer` AS
SELECT
  customer_id,
  customer_name,
  city,
  segment
FROM `${BQ_PROJECT}.${BQ_ODS}.customer`
WHERE NOT IFNULL(is_deleted, FALSE);

CREATE OR REPLACE VIEW `${BQ_PROJECT}.${BQ_MART}.vw_fact_sales` AS
SELECT
  sale_id,
  customer_id,
  sale_date,
  amount,
  quantity
FROM `${BQ_PROJECT}.${BQ_ODS}.sales`
WHERE NOT IFNULL(is_deleted, FALSE);

-- reconciliation view, queried by the post deploy check
CREATE OR REPLACE VIEW `${BQ_PROJECT}.${BQ_MART}.vw_load_control` AS
SELECT 'customer' AS table_name, COUNT(*) AS row_count,
       COUNTIF(is_deleted) AS deleted_rows, MAX(dwh_loaded_ts) AS last_load
FROM `${BQ_PROJECT}.${BQ_ODS}.customer`
UNION ALL
SELECT 'sales', COUNT(*), COUNTIF(is_deleted), MAX(dwh_loaded_ts)
FROM `${BQ_PROJECT}.${BQ_ODS}.sales`;
