#!/usr/bin/env bash
# The whole release, in dependency order. This is what both the
# CI runner and a human rollback call.
set -euo pipefail
ENVIRONMENT="${1:?usage: deploy_all.sh <dev|prod>}"

echo "=============================================="
echo " Deploying to ${ENVIRONMENT}"
echo "=============================================="

set -a; source "config/${ENVIRONMENT}.env"; set +a

echo ">>> 1/4 infrastructure"
( cd infra
  rm -rf .terraform
  terraform init -input=false \
    -backend-config="bucket=${PROJECT_ID}-tfstate" \
    -backend-config="prefix=demo/${ENVIRONMENT}"
  terraform apply -input=false -auto-approve -var-file="${ENVIRONMENT}.tfvars" )

echo ">>> 2/4 BigQuery"
./scripts/deploy_bigquery.sh "${ENVIRONMENT}"

echo ">>> 3/4 Data Fusion"
./scripts/deploy_datafusion.sh "${ENVIRONMENT}"

echo ">>> 4/4 AtScale"
./scripts/deploy_atscale.sh "${ENVIRONMENT}"

echo ">>> post deploy checks"
bq --project_id="${BQ_PROJECT}" query --use_legacy_sql=false --format=prettyjson \
  "SELECT * FROM \`${BQ_PROJECT}.${BQ_MART}.vw_load_control\`"

echo "Release to ${ENVIRONMENT} completed"
chmod +x scripts/*.sh
