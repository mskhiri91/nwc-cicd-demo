#!/usr/bin/env bash
# Pulls a pipeline out of the Studio and writes it as a Git artifact.
# From this point the JSON is the source of truth, not the Studio.
set -euo pipefail
ENVIRONMENT="${1:?usage: export_datafusion.sh <dev|prod> <pipeline_name>}"
APP="${2:?pipeline name required}"
set -a; source "config/${ENVIRONMENT}.env"; set +a

TOKEN=$(gcloud auth print-access-token)

ENDPOINT=$(curl -sfS -H "Authorization: Bearer ${TOKEN}" \
  "https://datafusion.googleapis.com/v1/projects/${PROJECT_ID}/locations/${REGION}/instances/${DF_INSTANCE}" \
  | jq -r '.apiEndpoint')

mkdir -p datafusion/pipelines

curl -sfS "${ENDPOINT}/v3/namespaces/${DF_NAMESPACE}/apps/${APP}" \
     -H "Authorization: Bearer ${TOKEN}" \
  | jq '{artifact: .artifact, config: (.configuration | fromjson)}' \
  > "datafusion/pipelines/${APP}.json"

echo "Exported to datafusion/pipelines/${APP}.json"
echo "Macros found:"
grep -o '\${[a-z_]*}' "datafusion/pipelines/${APP}.json" | sort -u \
  || echo "WARNING: no macros found, the pipeline is probably hardcoded"