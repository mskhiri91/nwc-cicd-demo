#!/usr/bin/env bash
# One shot historical load: Parquet in GCS straight into the landing layer.
# Parquet carries its own schema, so no schema definition is needed.
set -euo pipefail
ENVIRONMENT="${1:?usage: load_full.sh <dev|prod>}"
set -a; source "config/${ENVIRONMENT}.env"; set +a

for T in customer sales; do
  echo "==> full load ${T}"
  bq --project_id="${BQ_PROJECT}" --location="${BQ_LOCATION}" \
     load --source_format=PARQUET --replace \
     "${BQ_PROJECT}:${BQ_LANDING}.${T}_full" \
     "gs://${LANDING_BUCKET}/full/${T}/*.parquet"
done

bq --project_id="${BQ_PROJECT}" query --use_legacy_sql=false \
  "SELECT '${BQ_LANDING}.customer_full' t, COUNT(*) n FROM \`${BQ_PROJECT}.${BQ_LANDING}.customer_full\`
   UNION ALL
   SELECT '${BQ_LANDING}.sales_full', COUNT(*) FROM \`${BQ_PROJECT}.${BQ_LANDING}.sales_full\`"
