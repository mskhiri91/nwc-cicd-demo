-- Seed the control table. MERGE so it is safe to re-run on every deploy.
MERGE `${BQ_PROJECT}.${BQ_ODS}.etl_watermark` T
USING (
  SELECT 'customer' AS table_name, TIMESTAMP('2026-01-01 00:00:00') AS last_watermark
  UNION ALL
  SELECT 'sales',                  TIMESTAMP('2026-01-01 00:00:00')
) S
ON T.table_name = S.table_name
WHEN NOT MATCHED THEN
  INSERT (table_name, last_watermark, updated_ts)
  VALUES (S.table_name, S.last_watermark, CURRENT_TIMESTAMP());
