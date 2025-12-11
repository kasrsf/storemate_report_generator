# StoreMate Report Generator

A comprehensive data analytics solution for dry cleaning businesses, transforming legacy POS data into modern, real-time dashboards. Supports both local Excel reports and cloud-based Google Looker Studio dashboards.

## 🎯 Features

### Local Reporting (Excel)
* Automatic processing of DBF files to CSV format
* Report generation using configurable SQL queries
* Excel output with multiple worksheets
* Automatic backup of data directory
* Command-line interface for easy operation

### Cloud Reporting (Google Looker Studio)
* **Real-time dashboards** with Google Looker Studio
* **Automated ETL pipeline** to BigQuery
* **Scheduled data sync** with Cloud Scheduler
* **Scalable data warehouse** with BigQuery
* **Secure cloud storage** with Google Cloud Storage

## 🏗️ Architecture

### Option 1: Local Workflow (Current)
```
DBF Files → CSV → DuckDB → Excel Reports
```

### Option 2: Cloud Workflow (New)
```
DBF Files → Cloud Storage → Cloud Function → BigQuery → Looker Studio
                                ↑
                          Cloud Scheduler
                          (automated sync)
```

## 📋 Prerequisites

### For Local Use
* Python 3.9 or higher
* UV Package manager (or pip)

### For Cloud Use (Optional)
* Google Cloud Platform account
* gcloud CLI installed
* See [GCP Setup Guide](docs/GCP_SETUP_GUIDE.md) for detailed instructions

## Installation
1. Clone the repository:
```bash
git clone https://github.com/kasrsf/storemate_report_generator.git
cd storemate_report_generator 
```

2. Set up the development environment
```bash
make setup 
```

## 🚀 Quick Start

### Local Excel Reports

1. **Place DBF files** in `data/raw/` directory
2. **Process and generate reports**:
   ```bash
   make run-all
   ```
3. **Find reports** in `data/reports/reports_YYYYMMDD_HHMMSS.xlsx`

### Cloud Looker Studio Dashboards

1. **Set up GCP** (one-time):
   - Follow [GCP Setup Guide](docs/GCP_SETUP_GUIDE.md)
   - Set environment variables
   - Initialize GCP resources:
     ```bash
     uv run storemate-cli init-gcp
     ```

2. **Sync data to BigQuery**:
   ```bash
   uv run storemate-cli sync-to-bigquery
   ```

3. **Create dashboards**:
   - Follow [Looker Studio Guide](docs/LOOKER_STUDIO_GUIDE.md)
   - Connect to BigQuery
   - Build visualizations

4. **Automate (optional)**:
   - Deploy Cloud Function for automated sync
   - Set up Cloud Scheduler for periodic updates
   - See [GCP Setup Guide](docs/GCP_SETUP_GUIDE.md#cloud-scheduler-setup)

## 📂 Directory Structure

```
storemate_report_generator/
├── data/
│   ├── raw/              # Place your DBF files here
│   ├── processed/        # Converted CSV files and DuckDB database
│   ├── reports/          # Generated Excel report files
│   └── queries/          # YAML files with report queries (for local)
├── bigquery_queries/     # SQL queries for BigQuery/Looker Studio
├── cloud_function/       # Cloud Function for automated ETL
├── docs/                 # Documentation
│   ├── GCP_SETUP_GUIDE.md       # Complete GCP setup instructions
│   └── LOOKER_STUDIO_GUIDE.md   # Dashboard building guide
└── src/                  # Application source code
```

## 💻 CLI Commands

### Local Commands

```bash
# Process DBF files to CSV
make process-data
# or: uv run storemate-cli process-data

# Generate Excel reports
make generate-reports MONTH=11 YEAR=2024
# or: uv run storemate-cli generate-reports --month 11 --year 2024

# Backup data directory
make backup-data
# or: uv run storemate-cli backup-data

# Run complete local pipeline
make run-all
```

### Cloud Commands

```bash
# Test GCP connection
uv run storemate-cli test-gcp

# Initialize GCP resources (one-time setup)
uv run storemate-cli init-gcp

# Sync data to BigQuery
uv run storemate-cli sync-to-bigquery

# Skip DBF processing if CSVs already exist
uv run storemate-cli sync-to-bigquery --skip-dbf
```

### Cloud Function Deployment

```bash
cd cloud_function
./deploy.sh
```

## 📊 Available Reports

### Local Excel Reports (YAML Queries)

| Report | Description | Metrics |
|--------|-------------|---------|
| **Daily Orders** | Order statistics by date | Count, average, total sales |
| **Sales Breakdown** | Payment method analysis | Cash, debit, credit totals |
| **Drops vs Pickups** | Compare dropped vs picked orders | Orders, items, revenue |
| **Item Analysis** | Item-level breakdown | Quantity, revenue by category |
| **Customer Analysis** | Customer behavior insights | Lifetime value, visit frequency |

### BigQuery/Looker Studio Reports (SQL Queries)

All local reports have been converted to BigQuery SQL format in `bigquery_queries/`:
- `1_report_orders_daily.sql` - Daily order statistics
- `2_sales_breakdown_daily.sql` - Payment method breakdown
- `3_order_drops_pickups.sql` - Drops vs pickups comparison
- `4_item_drops.sql` - Item-level analysis
- `5_customer_drops.sql` - Customer behavior analysis

See [bigquery_queries/README.md](bigquery_queries/README.md) for usage in Looker Studio.

## 📖 Documentation

| Guide | Description |
|-------|-------------|
| [GCP Setup Guide](docs/GCP_SETUP_GUIDE.md) | Complete walkthrough for setting up Google Cloud Platform |
| [Looker Studio Guide](docs/LOOKER_STUDIO_GUIDE.md) | Dashboard templates and best practices |
| [Cloud Function README](cloud_function/README.md) | Deployment and monitoring of automated ETL |
| [BigQuery Queries README](bigquery_queries/README.md) | SQL queries for Looker Studio |

## 🔄 Migration Path

### Current State: Manual Monthly Excel Reports
- Run commands manually once a month
- Download Excel file
- Email to stakeholders

### Migrated State: Real-time Cloud Dashboards
- Automatic daily (or hourly) data sync
- Live dashboards accessible via URL
- No manual intervention required
- Always up-to-date insights

**Migration Steps**:
1. Follow [GCP Setup Guide](docs/GCP_SETUP_GUIDE.md) (1-2 hours)
2. Run initial data sync
3. Create Looker Studio dashboards
4. Deploy Cloud Function for automation
5. Set up Cloud Scheduler
6. Share dashboard links with team

**Estimated Time**: 2-3 hours total
**Monthly Cost**: $10-30 (mostly covered by free tier)

## 🛠️ Development

### Running Tests
```bash
make test
```

### Code Quality
```bash
make lint      # Check code style
make format    # Auto-format code
```

### Adding New Local Reports

Create a YAML file in `data/queries/`:

```yaml
name: custom_report
description: "Description of your report"
query: |
  SELECT
    column1,
    SUM(column2) AS total
  FROM table_name
  WHERE date BETWEEN '$FIRST_DAY' AND '$LAST_DAY'
  GROUP BY column1
output_file: custom_report.csv
```

### Adding New BigQuery Reports

Create a SQL file in `bigquery_queries/`:

```sql
-- Report Description
-- Parameters: @DS_START_DATE, @DS_END_DATE

SELECT
    column1,
    SUM(column2) AS total
FROM `${project_id}.${dataset_name}.table_name`
WHERE date BETWEEN @DS_START_DATE AND @DS_END_DATE
GROUP BY column1
```

Then use in Looker Studio as a custom query.

## 💰 Cost Estimation

### Local Usage
- **Free** - All processing done locally

### Cloud Usage (Monthly)

| Service | Free Tier | Typical Usage | Est. Cost |
|---------|-----------|---------------|-----------|
| BigQuery | 1 TB queries, 10 GB storage | ~5 GB storage, 100 GB queries | $0-5 |
| Cloud Storage | 5 GB | ~2 GB | $0-1 |
| Cloud Functions | 2M invocations | ~700 invocations | $0-1 |
| Cloud Scheduler | 3 jobs | 1 job | $0.10 |
| **Total** | - | - | **$1-10/month** |

*Costs are estimates for a single-location dry cleaning business. Actual costs may vary.*

## 🔒 Security

- Service account credentials stored securely
- BigQuery data encrypted at rest and in transit
- Access control via Google Cloud IAM
- No sensitive data in version control (`.env` in `.gitignore`)

## 📞 Support

- **Issues**: Open an issue on GitHub
- **Documentation**: Check the `docs/` directory
- **GCP Help**: [Google Cloud Console](https://console.cloud.google.com/)
- **Looker Studio Help**: [Looker Studio Support](https://support.google.com/looker-studio)

## 📝 License

MIT License

## 🎉 What's New

**Version 0.2.0** - Cloud Integration
- ✅ Google BigQuery integration
- ✅ Cloud Function for automated ETL
- ✅ Cloud Scheduler support
- ✅ Looker Studio compatible SQL queries
- ✅ Comprehensive setup guides
- ✅ Real-time dashboard templates

**Version 0.1.0** - Initial Release
- DBF to CSV conversion
- DuckDB local database
- Excel report generation
- Command-line interface
