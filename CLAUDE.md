# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

StoreMate Report Generator is a dual-mode data analytics solution for dry cleaning businesses:
- **Local Mode**: Converts legacy POS DBF files → CSV → DuckDB → Excel reports
- **Cloud Mode**: Automated ETL pipeline from DBF files → BigQuery dimensional model → Looker Studio dashboards

The project supports migration from manual monthly Excel reports to real-time cloud dashboards.

## Development Commands

### Setup and Environment
```bash
# Initial setup (creates venv and installs dependencies)
make setup

# Install package in editable mode
make install
uv pip install -e .

# Install with development dependencies
uv pip install -e ".[dev]"
```

### Testing and Code Quality
```bash
# Run tests with coverage
make test
uv run pytest tests/ -v --cov=src/storemate_report_generator

# Run single test file
uv run pytest tests/test_dbf_processor.py -v

# Lint code (auto-fix issues)
make lint
uv run ruff check . --fix

# Format code
make format
uv run ruff format .
```

### Local Excel Reporting
```bash
# Process DBF files to CSV
make process-data
uv run storemate-cli process-data

# Generate Excel reports for specific month
make generate-reports MONTH=11 YEAR=2024
uv run storemate-cli generate-reports --month 11 --year 2024

# Backup data directory
make backup-data
uv run storemate-cli backup-data

# Run complete local pipeline
make run-all
```

### Cloud BigQuery Integration
```bash
# Test GCP connectivity and configuration
uv run storemate-cli test-gcp

# Initialize GCP resources (one-time setup)
uv run storemate-cli init-gcp

# Sync data to BigQuery with dimensional transformations
uv run storemate-cli sync-to-bigquery

# Skip DBF processing (use existing CSVs)
uv run storemate-cli sync-to-bigquery --skip-dbf

# Skip dimensional transformations (only load raw data)
uv run storemate-cli sync-to-bigquery --skip-transform

# Run only dimensional transformations (on existing raw data)
uv run storemate-cli run-transformations

# Show dimensional model table statistics
uv run storemate-cli show-table-stats
```

### Terraform Infrastructure
```bash
# Initialize Terraform
cd terraform
terraform init

# Plan infrastructure changes
terraform plan -var="project_id=your-project-id"

# Apply infrastructure (creates BigQuery, GCS, Cloud Function, Scheduler)
terraform apply -var="project_id=your-project-id"

# Destroy infrastructure
terraform destroy -var="project_id=your-project-id"
```

### Cloud Function Deployment
```bash
cd cloud_function
./deploy.sh
```

## Architecture

### Two-Mode System

**Local Mode (Original):**
1. DBF files placed in `data/raw/`
2. `DBFProcessor` converts DBF → CSV in `data/processed/`
3. `Database` loads CSVs into DuckDB (`data/processed/store.db`)
4. `ReportGenerator` runs YAML queries → Excel reports in `data/reports/`

**Cloud Mode (New):**
1. DBF files → CSV conversion (same as local)
2. `ETLPipeline.run_local_to_bigquery()` uploads CSVs to BigQuery **raw dataset** (`storemate_raw`)
3. `DataTransformations` builds dimensional star schema in **analytics dataset** (`storemate_analytics`)
4. Looker Studio dashboards query dimensional model from analytics dataset
5. Optional: Cloud Function automates this pipeline on schedule

### BigQuery Dataset Organization

Following best practices, data is separated into two datasets:

**Raw Dataset (`storemate_raw`):**
- Direct 1:1 copy of DBF files converted to CSV
- Tables: `claim`, `invoice`, `custlist`, `emplist`, `pricelist`, etc.
- Purpose: Staging layer for raw data ingestion
- Never queried by end users

**Analytics Dataset (`storemate_analytics`):**
- Dimensional model (star schema) optimized for analytics
- Tables: `dim_*`, `fact_*`, `agg_*`
- Purpose: Consumption layer for reporting and dashboards
- Queried by Looker Studio and analysts

This separation provides:
- Clear data lineage (raw → transformed)
- Independent access controls
- Easier to manage lifecycle policies
- Better query performance (no mixing raw and transformed tables)

### Core Components

**src/storemate_report_generator/**
- `cli.py` - Click-based command-line interface with all commands
- `config.py` - Configuration using environment variables (.env support)
- `dbf_processor.py` - Converts DBF files to CSV using dbfread library
- `database.py` - DuckDB wrapper for local analytics
- `reporting.py` - Generates Excel reports from YAML query definitions
- `etl_pipeline.py` - Orchestrates full ETL: DBF → CSV → BigQuery raw → Transformations → Analytics
- `bigquery_client.py` - BigQuery operations with dataset type support ('raw' or 'analytics')
- `gcs_client.py` - Google Cloud Storage operations (upload, download, list)
- `transformations.py` - Dimensional model transformations (reads from raw, writes to analytics)

**Data Flow:**
1. DBF files (legacy POS format) → `DBFProcessor`
2. CSV files (normalized) → `Database` (local) OR `BigQueryClient(dataset_type='raw')` (cloud)
3. Raw tables (storemate_raw dataset) → `DataTransformations`
4. Dimensional model (storemate_analytics dataset) → Looker Studio (cloud) OR local queries

### Dimensional Model (Cloud Only)

The `transformations.py` module builds a star schema optimized for analytics:

**Dimension Tables:**
- `dim_dates` - Date dimension with calendar attributes
- `dim_customers` - Customer master data
- `dim_items` - Product/service catalog
- `dim_employees` - Employee master data

**Fact Tables:**
- `fact_orders` - Order-level metrics (grain: one row per order)
- `fact_order_items` - Order line items (grain: one row per item)

**Aggregate Tables:**
- `agg_daily_summary` - Pre-aggregated daily metrics
- `agg_monthly_summary` - Pre-aggregated monthly metrics

SQL transformations are stored as separate SQL files in `transformations/` directory and executed sequentially.

### Report Definitions

**Local (YAML in `data/queries/`):**
- Each YAML file defines a DuckDB SQL query
- Supports template variables: `$FIRST_DAY`, `$LAST_DAY`
- Executed by `ReportGenerator` → Excel worksheets

**Cloud (SQL in `bigquery_queries/`):**
- SQL queries compatible with Looker Studio parameters
- Uses `@DS_START_DATE`, `@DS_END_DATE` parameters
- Designed to query the dimensional model tables

## Environment Configuration

Required `.env` file (copy from `.env.example`):
```
GCP_PROJECT_ID=your-project-id
GCP_RAW_DATASET=storemate_raw           # Raw data (staging layer)
GCP_ANALYTICS_DATASET=storemate_analytics  # Dimensional model (consumption layer)
GCP_LOCATION=US
GCP_STORAGE_BUCKET=your-bucket-name
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json
```

Local-only usage doesn't require GCP variables.

**Backward Compatibility:** If `GCP_DATASET_NAME` is set (legacy), it will be used for both raw and analytics datasets.

## Key Design Patterns

### Configuration Management
- Single `Config` dataclass in `config.py`
- Loads from environment variables with python-dotenv
- Provides sensible defaults for local-only usage
- All paths are `pathlib.Path` objects
- Backward compatible with legacy `GCP_DATASET_NAME` environment variable

### Client Initialization
- GCP clients (`BigQueryClient`, `GCSClient`) gracefully handle missing credentials
- `BigQueryClient` takes optional `dataset_type` parameter ('raw' or 'analytics')
- ETL pipeline checks for client availability before cloud operations
- Local operations work without any GCP configuration
- Transformations use two clients: one for raw (reading), one for analytics (writing)

### Error Handling
- All ETL operations return results dictionaries with `errors` list
- Operations continue on non-critical errors
- Critical errors raise exceptions with context

### Logging
- Standard library logging throughout
- INFO level for normal operations
- ERROR level for failures
- Structured logging with timestamps

## Testing

- Test files in `tests/` mirror source structure
- `conftest.py` provides fixtures for config, temp directories
- Tests use pytest with coverage reporting
- Mock GCP clients for unit tests (no actual GCP calls)

## Cloud Function

The `cloud_function/main.py` provides two entry points:
1. `sync_data_http()` - HTTP trigger for Cloud Scheduler
2. `sync_data_storage_trigger()` - Storage trigger when DBF files uploaded

Both execute the same ETL logic: download from GCS → process DBF → load to BigQuery.

## Common Development Workflows

### Adding a New Local Report
1. Create YAML file in `data/queries/` with query and description
2. Use existing table names from DBF files (claim, invoice, custlist, emplist, pricelist)
3. Report automatically included in next `generate-reports` run

### Adding a New Cloud Report
1. Create SQL file in `bigquery_queries/` using dimensional model tables
2. Use Looker Studio parameters: `@DS_START_DATE`, `@DS_END_DATE`
3. Import as custom query in Looker Studio

### Extending Dimensional Model
1. Add new SQL transformation file in `transformations/` directory
2. Update `DataTransformations.run_all_transformations()` to include new file
3. Follow naming convention: dimensions (dim_*), facts (fact_*), aggregates (agg_*)

### Modifying Cloud Function
1. Edit `cloud_function/main.py`
2. Test locally: `python main.py test`
3. Deploy: `cd cloud_function && ./deploy.sh`

## Important Notes

- DBF files must be placed in `data/raw/` before processing
- CSV files in `data/processed/` match DBF filenames (claim.csv, invoice.csv, etc.)
- DuckDB database is created fresh each run (no persistence between runs)
- BigQuery raw tables are truncated and reloaded (full refresh, not incremental)
- BigQuery analytics tables are recreated from raw data each transformation run
- Two separate BigQuery datasets: `storemate_raw` (staging) and `storemate_analytics` (consumption)
- Cloud Function runs in `/tmp/` directory with limited disk space
- Terraform modules are in `terraform/modules/` (iam, bigquery, storage, cloud_function, scheduler)
- SQL transformation files use placeholders: `{project_id}`, `{raw_dataset}`, `{analytics_dataset}`
