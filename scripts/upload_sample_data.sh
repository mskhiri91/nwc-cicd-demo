#!/usr/bin/env bash
set -euo pipefail
ENVIRONMENT="${1:?usage: upload_sample_data.sh <dev|prod>}"
set -a; source "config/${ENVIRONMENT}.env"; set +a

DT="2026-09-13"

gcloud storage cp "sampledata/full/customer/"*.parquet \
  "gs://${LANDING_BUCKET}/full/customer/"
gcloud storage cp "sampledata/full/sales/"*.parquet \
  "gs://${LANDING_BUCKET}/full/sales/"

gcloud storage cp "sampledata/delta/customer/"*.parquet \
  "gs://${LANDING_BUCKET}/delta/customer/dt=${DT}/"
gcloud storage cp "sampledata/delta/sales/"*.parquet \
  "gs://${LANDING_BUCKET}/delta/sales/dt=${DT}/"

gcloud storage ls -r "gs://${LANDING_BUCKET}/**"
