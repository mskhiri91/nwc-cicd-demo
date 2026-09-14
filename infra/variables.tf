variable "project_id" {
  type        = string
  description = "GCP project id"
}

variable "env" {
  type        = string
  description = "Environment name, dev or prod"
  validation {
    condition     = contains(["dev", "prod"], var.env)
    error_message = "env must be dev or prod."
  }
}

variable "region" {
  type        = string
  default     = "me-central2"
  description = "Region for buckets and the Data Fusion instance (me-central2 is Dammam)"
}

variable "bq_location" {
  type        = string
  default     = "me-central2"
  description = "BigQuery dataset location. Keep it equal to var.region so buckets and datasets are co-located"
}

variable "df_edition" {
  type        = string
  default     = "BASIC"
  description = "Data Fusion edition. BASIC gets 120 free instance hours per month per account, which covers this lab. DEVELOPER is $0.35/hour with no free allowance."
}

variable "create_datafusion" {
  type        = bool
  default     = true
  description = "Set to false to skip the Data Fusion instance and save cost"
}
