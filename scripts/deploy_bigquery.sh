#!/usr/bin/env bash
# Deploys every SQL artifact, in file name order, against one environment.
# The SQL files contain no environment names, only ${BQ_*} placeholders
# that envsubst fills in from config/<env>.env.
set -euo pipefail
ENVIRONMENT="${1:?usage: deploy_bigquery.sh <dev|prod> [--dry-run]}"
DRY="${2:-}"

set -a; source "config/${ENVIRONMENT}.env"; set +a

for f in $(ls bigquery/sql/*.sql | sort); do
  echo "==> ${f}"
  RENDERED="/tmp/$(basename "$f")"
  envsubst < "$f" > "$RENDERED"

  if [[ "$DRY" == "--dry-run" ]]; then
    bq --project_id="${BQ_PROJECT}" --location="${BQ_LOCATION}" \
       query --use_legacy_sql=false --dry_run --format=none < "$RENDERED" \
       && echo "    valid"
  else
    bq --project_id="${BQ_PROJECT}" --location="${BQ_LOCATION}" \
       query --use_legacy_sql=false --format=none < "$RENDERED"
  fi
done

echo "BigQuery deploy finished for ${ENVIRONMENT}"
