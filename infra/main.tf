terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.0.0"
    }
  }

  # bucket and prefix are supplied at init time with -backend-config,
  # which is how one code base serves two environments
  backend "gcs" {}
}

provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "this" {}

locals {
  labels = {
    env       = var.env
    managedby = "terraform"
    project   = "nwc-migration-demo"
  }

  # the service account the Dataproc workers run as when a pipeline executes
  compute_sa = "${data.google_project.this.number}-compute@developer.gserviceaccount.com"

  # the Google managed agent that creates those Dataproc clusters
  df_agent = "service-${data.google_project.this.number}@gcp-sa-datafusion.iam.gserviceaccount.com"
}

########################################
# Storage: landing zone and temp bucket
########################################

resource "google_storage_bucket" "landing" {
  name                        = "${var.project_id}-landing-${var.env}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true # lab only, never in production
  labels                      = local.labels
}

resource "google_storage_bucket" "temp" {
  name                        = "${var.project_id}-temp-${var.env}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
  labels                      = local.labels

  # Data Fusion staging files are disposable, expire them
  lifecycle_rule {
    condition { age = 7 }
    action { type = "Delete" }
  }
}

########################################
# BigQuery datasets: landing, ods, mart
########################################

resource "google_bigquery_dataset" "layer" {
  for_each = toset(["landing", "ods", "mart"])

  dataset_id                 = "${each.value}_${var.env}"
  location                   = var.bq_location
  labels                     = local.labels
  delete_contents_on_destroy = true # lab only
  description                = "${each.value} layer for ${var.env}"
}

########################################
# ODS tables, declared so the schema is reviewed code
########################################
resource "google_bigquery_table" "customer" {
  dataset_id          = google_bigquery_dataset.layer["ods"].dataset_id
  table_id            = "customer"
  deletion_protection = false
  clustering          = ["customer_id"]
  labels              = local.labels

  schema = jsonencode([
    { name = "customer_id", type = "INTEGER", mode = "REQUIRED" },
    { name = "customer_name", type = "STRING", mode = "NULLABLE" },
    { name = "city", type = "STRING", mode = "NULLABLE" },
    { name = "segment", type = "STRING", mode = "NULLABLE" },
    { name = "last_modified_ts", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "is_deleted", type = "BOOLEAN", mode = "NULLABLE" },
    { name = "dwh_loaded_ts", type = "TIMESTAMP", mode = "NULLABLE" },
  ])
}

resource "google_bigquery_table" "sales" {
  dataset_id          = google_bigquery_dataset.layer["ods"].dataset_id
  table_id            = "sales"
  deletion_protection = false
  clustering          = ["customer_id"]
  labels              = local.labels

  time_partitioning {
    type  = "DAY"
    field = "sale_date"
  }

  schema = jsonencode([
    { name = "sale_id", type = "INTEGER", mode = "REQUIRED" },
    { name = "customer_id", type = "INTEGER", mode = "NULLABLE" },
    { name = "sale_date", type = "DATE", mode = "NULLABLE" },
    { name = "amount", type = "NUMERIC", mode = "NULLABLE" },
    { name = "quantity", type = "INTEGER", mode = "NULLABLE" },
    { name = "last_modified_ts", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "is_deleted", type = "BOOLEAN", mode = "NULLABLE" },
    { name = "dwh_loaded_ts", type = "TIMESTAMP", mode = "NULLABLE" },
  ])
}

# control table, the GCP equivalent of the SQL Server watermark tables
resource "google_bigquery_table" "etl_watermark" {
  dataset_id          = google_bigquery_dataset.layer["ods"].dataset_id
  table_id            = "etl_watermark"
  deletion_protection = false
  labels              = local.labels

  schema = jsonencode([
    { name = "table_name", type = "STRING", mode = "REQUIRED" },
    { name = "last_watermark", type = "TIMESTAMP", mode = "NULLABLE" },
    { name = "updated_ts", type = "TIMESTAMP", mode = "NULLABLE" },
  ])
}

# deploy history, so schema migrations run once and only once
resource "google_bigquery_table" "deploy_history" {
  dataset_id          = google_bigquery_dataset.layer["ods"].dataset_id
  table_id            = "_deploy_history"
  deletion_protection = false
  labels              = local.labels

  schema = jsonencode([
    { name = "script_name", type = "STRING", mode = "REQUIRED" },
    { name = "git_sha", type = "STRING", mode = "NULLABLE" },
    { name = "applied_ts", type = "TIMESTAMP", mode = "NULLABLE" },
  ])
}

########################################
# Cloud Data Fusion
########################################

resource "google_data_fusion_instance" "df" {
  count = var.create_datafusion ? 1 : 0

  name                          = "df-${var.env}"
  region                        = var.region
  type                          = var.df_edition
  description                   = "Data Fusion ${var.env}"
  enable_stackdriver_logging    = true
  enable_stackdriver_monitoring = true
  labels                        = local.labels
}

########################################
# IAM
########################################

# the account the pipelines actually run as
resource "google_project_iam_member" "pipeline_runtime" {
  for_each = toset([
    "roles/bigquery.dataEditor",
    "roles/bigquery.jobUser",
    "roles/storage.objectAdmin",
    "roles/dataproc.worker",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${local.compute_sa}"
}

# Data Fusion needs to impersonate that account to launch Dataproc clusters
resource "google_service_account_iam_member" "df_agent_act_as" {
  count = var.create_datafusion ? 1 : 0

  service_account_id = "projects/${var.project_id}/serviceAccounts/${local.compute_sa}"
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${local.df_agent}"
}
