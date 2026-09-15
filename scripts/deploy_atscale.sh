#!/usr/bin/env bash
# Deploys the SML semantic models to one AtScale environment.
# Skips cleanly if no AtScale instance is configured, so the rest of the
# pipeline still demonstrates end to end even without a licence.
set -euo pipefail
ENVIRONMENT="${1:?usage: deploy_atscale.sh <dev|prod>}"

if [[ -z "${ATSCALE_API_URL:-}" || -z "${ATSCALE_API_TOKEN:-}" ]]; then
  echo "ATSCALE_API_URL or ATSCALE_API_TOKEN not set, skipping AtScale deploy"
  exit 0
fi

command -v sml-cli >/dev/null || npm install -g sml-cli

cd atscale
sml-cli atscale-deploy
cd ..

echo "AtScale deploy finished for ${ENVIRONMENT}"
