# BigQuery Module - Data Warehouse

resource "google_bigquery_dataset" "storemate_dataset" {
  dataset_id    = var.dataset_name
  friendly_name = "StoreMate Data Warehouse"
  description   = var.description
  location      = var.location

  # Data retention (optional)
  default_table_expiration_ms = var.default_table_expiration_ms

  # Access control - Use default project access
  # BigQuery automatically grants appropriate permissions to project owners/editors

  # Labels for organization
  labels = merge(
    var.labels,
    {
      dataset_type = "analytics"
      data_source  = "storemate_pos"
    }
  )

  # Delete protection
  delete_contents_on_destroy = var.delete_contents_on_destroy
}

# Note: The dimensional model tables (dim_*, fact_*, agg_*) are created
# by the ETL transformation process, not by Terraform.
# Run `uv run storemate-cli sync-to-bigquery` after infrastructure deployment
# to create the dimensional model tables.
