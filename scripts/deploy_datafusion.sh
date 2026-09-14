#!/usr/bin/env bash
# Deploys namespace preferences first, then every pipeline in the repo.
# Order matters: a pipeline that starts before its macros exist fails at run time
# with "Argument 'bq_project' is not defined".
set -euo pipefail
ENVIRONMENT="${1:?usage: deploy_datafusion.sh <dev|prod>}"
set -a; source "config/${ENVIRONMENT}.env"; set +a

TOKEN=$(gcloud auth print-access-token)

ENDPOINT=$(curl -sfS -H "Authorization: Bearer ${TOKEN}" \
  "https://datafusion.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/instances/${DF_INSTANCE}" \
  | jq -r '.apiEndpoint')

if [[ -z "${ENDPOINT}" || "${ENDPOINT}" == "null" ]]; then
  echo "Could not resolve the Data Fusion endpoint. Is ${DF_INSTANCE} running in ${REGION}?"
  exit 1
fi
echo "Endpoint: ${ENDPOINT}"

# 1. namespace (harmless if it already exists)
curl -sS -o /dev/null -X PUT \
  "${ENDPOINT}/v3/namespaces/${DF_NAMESPACE}" \
  -H "Authorization: Bearer ${TOKEN}" || true

# 2. environment values, before the pipelines
echo "==> preferences"
curl -sfS -X PUT \
  "${ENDPOINT}/v3/namespaces/${DF_NAMESPACE}/preferences" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d @"datafusion/preferences/${ENVIRONMENT}.json"

# 3. pipelines
shopt -s nullglob
for f in datafusion/pipelines/*.json; do
  APP=$(basename "$f" .json)
  echo "==> pipeline ${APP}"
  curl -sfS -X PUT \
    "${ENDPOINT}/v3/namespaces/${DF_NAMESPACE}/apps/${APP}" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d @"$f"
done

echo "Data Fusion deploy finished for ${ENVIRONMENT}"