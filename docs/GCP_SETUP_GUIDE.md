# Google Cloud Platform Setup Guide

Complete guide to migrating your StoreMate reporting from local Excel to Google Cloud with Looker Studio dashboards.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [GCP Project Setup](#gcp-project-setup)
3. [Service Account & Credentials](#service-account--credentials)
4. [BigQuery Setup](#bigquery-setup)
5. [Cloud Storage Setup](#cloud-storage-setup)
6. [Local Environment Configuration](#local-environment-configuration)
7. [Initial Data Sync](#initial-data-sync)
8. [Looker Studio Dashboard](#looker-studio-dashboard)
9. [Regular Data Updates](#regular-data-updates)
10. [Testing & Verification](#testing--verification)
11. [Troubleshooting](#troubleshooting)

---

## Prerequisites

- **Google Account** (your existing Gmail account works)
- **Credit Card** (required for GCP, but free tier covers most small business usage)
- **Local Machine** with:
  - Python 3.9+
  - gcloud CLI installed ([Install guide](https://cloud.google.com/sdk/docs/install))
  - Access to your DBF files

**Estimated Time**: 1-2 hours for initial setup

**Estimated Monthly Cost**: $0-10/month depending on data volume
- BigQuery: ~$0-5/month (first 1 TB queries free)
- Cloud Storage: ~$0-5/month (first 5 GB free)

---

## GCP Project Setup

### Step 1: Create a GCP Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Click "Select a project" → "New Project"
3. Enter project details:
   - **Project name**: `storemate-reporting` (or your preferred name)
   - **Organization**: Leave as "No organization" (unless you have one)
4. Click "Create"
5. **Note your Project ID** (e.g., `storemate-reporting-123456`)

### Step 2: Enable Billing

1. Go to [Billing](https://console.cloud.google.com/billing)
2. Click "Link a billing account" or "Create billing account"
3. Enter payment information
4. **Set up budget alerts** (recommended):
   - Go to Billing → Budgets & alerts
   - Create budget: $50/month
   - Set alert threshold: 50%, 90%, 100%

### Step 3: Enable Required APIs

Run these commands in your terminal (or use Cloud Console UI):

```bash
# Set your project ID
export PROJECT_ID="storemate-reporting-123456"  # Replace with your actual project ID

# Set active project
gcloud config set project $PROJECT_ID

# Enable APIs
gcloud services enable bigquery.googleapis.com
gcloud services enable storage.googleapis.com
```

---

## Service Account & Credentials

### Step 1: Create Service Account

```bash
# Create service account
gcloud iam service-accounts create storemate-etl \
    --display-name="StoreMate ETL Service Account" \
    --description="Service account for automated ETL pipeline"

# Get service account email
SA_EMAIL="storemate-etl@${PROJECT_ID}.iam.gserviceaccount.com"
echo "Service Account: $SA_EMAIL"
```

### Step 2: Grant Permissions

```bash
# BigQuery Data Editor (to create/update tables)
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/bigquery.dataEditor"

# BigQuery Job User (to run queries)
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/bigquery.jobUser"

# Storage Object Admin (to manage files in GCS)
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/storage.objectAdmin"
```

### Step 3: Download Credentials (for Local Use)

```bash
# Create credentials directory
mkdir -p ~/.config/gcloud

# Download key file
gcloud iam service-accounts keys create ~/.config/gcloud/storemate-key.json \
    --iam-account=$SA_EMAIL

# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/storemate-key.json"

# Add to your shell profile (.bashrc, .zshrc, etc.)
echo 'export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/storemate-key.json"' >> ~/.zshrc
```

**Security Note**: Keep this key file safe. Don't commit it to version control.

---

## BigQuery Setup

### Step 1: Create Dataset

```bash
# Set dataset name
export DATASET_NAME="storemate_data"

# Create dataset
bq --location=US mk \
    --dataset \
    --description="StoreMate POS data warehouse" \
    $PROJECT_ID:$DATASET_NAME
```

Or using the UI:
1. Go to [BigQuery Console](https://console.cloud.google.com/bigquery)
2. Click your project name
3. Click "Create Dataset"
   - Dataset ID: `storemate_data`
   - Location: `US` (multi-region)
   - Default table expiration: Never
4. Click "Create Dataset"

### Step 2: Verify Dataset

```bash
# List datasets
bq ls $PROJECT_ID

# Should show: storemate_data
```

---

## Cloud Storage Setup

### Step 1: Create Bucket

```bash
# Set bucket name (must be globally unique)
export BUCKET_NAME="${PROJECT_ID}-data"  # e.g., storemate-reporting-123456-data

# Create bucket
gsutil mb -p $PROJECT_ID -c STANDARD -l us-central1 gs://$BUCKET_NAME

# Verify
gsutil ls
```

### Step 2: Create Folder Structure

```bash
# Create folders for organization
gsutil mkdir gs://$BUCKET_NAME/data/
gsutil mkdir gs://$BUCKET_NAME/backups/
```

### Step 3: Grant Service Account Access

```bash
# Grant storage permissions to service account
gsutil iam ch serviceAccount:$SA_EMAIL:objectAdmin gs://$BUCKET_NAME
```

---

## Local Environment Configuration

### Step 1: Install Dependencies

```bash
cd /Users/kasra/dev/storemate_report_generator

# Install with uv (or pip)
uv pip install -e .

# Or with pip
pip install -e .
```

### Step 2: Set Environment Variables

Create a `.env` file in your project root:

```bash
cat > .env << 'EOF'
# GCP Configuration
export GCP_PROJECT_ID="storemate-reporting-123456"  # Replace with your project ID
export GCP_DATASET_NAME="storemate_data"
export GCP_LOCATION="US"
export GCP_STORAGE_BUCKET="storemate-reporting-123456-data"  # Replace with your bucket
export GOOGLE_APPLICATION_CREDENTIALS="$HOME/.config/gcloud/storemate-key.json"
EOF

# Load environment variables
source .env
```

**Add to `.gitignore`**:
```bash
echo ".env" >> .gitignore
```

### Step 3: Test GCP Connection

```bash
# Run connection test
uv run storemate-cli test-gcp
```

Expected output:
```
=== GCP Configuration Test ===

1. Environment Variables:
   GCP_PROJECT_ID: storemate-reporting-123456
   GCP_DATASET_NAME: storemate_data
   GCP_LOCATION: US
   GCP_STORAGE_BUCKET: storemate-reporting-123456-data
   GCP_CREDENTIALS_PATH: /Users/kasra/.config/gcloud/storemate-key.json

2. BigQuery Connection:
   ✓ Connected to project: storemate-reporting-123456
   ℹ Dataset exists but no tables yet

3. Cloud Storage Connection:
   ✓ Connected to bucket: storemate-reporting-123456-data
   Files in bucket: 0

=== Test Complete ===
```

---

## Initial Data Sync

### Step 1: Prepare Your Data

1. Copy your DBF files to the `data/raw` directory:
   ```bash
   # If your DBF files are currently in /data
   mv data/*.dbf data/raw/
   mv data/*.DBF data/raw/ 2>/dev/null || true
   ```

2. Verify files are present:
   ```bash
   ls -la data/raw/*.dbf
   ```

### Step 2: Initialize GCP Resources

```bash
# Create BigQuery dataset and verify GCS bucket
uv run storemate-cli init-gcp
```

### Step 3: Run Initial Sync

```bash
# Sync data to BigQuery
uv run storemate-cli sync-to-bigquery

# This will:
# 1. Convert DBF files to CSV
# 2. Upload CSVs to BigQuery
# 3. Create tables in BigQuery
```

Expected output:
```
Starting ETL pipeline to BigQuery...

=== ETL Pipeline Results ===
DBF files processed: 8
CSV files created: 8
BigQuery tables loaded: 8
Duration: 23.45 seconds

✓ Pipeline completed successfully!
```

### Step 4: Verify Data in BigQuery

```bash
# List tables
bq ls $PROJECT_ID:$DATASET_NAME

# Count rows in claim table
bq query --nouse_legacy_sql \
    "SELECT COUNT(*) as row_count FROM \`$PROJECT_ID.$DATASET_NAME.claim\`"

# Sample data
bq query --nouse_legacy_sql \
    "SELECT * FROM \`$PROJECT_ID.$DATASET_NAME.claim\` LIMIT 10"
```

---

## Looker Studio Dashboard

### Step 1: Access Looker Studio

1. Go to [Looker Studio](https://lookerstudio.google.com/)
2. Sign in with your Google account (same one as GCP)

### Step 2: Create Data Source

1. Click "Create" → "Data Source"
2. Select "BigQuery"
3. Choose:
   - **Project**: Your GCP project (e.g., `storemate-reporting-123456`)
   - **Dataset**: `storemate_data`
   - **Table**: Select one of your tables (e.g., `claim`)
4. Click "Connect"
5. Review fields and types
6. Click "Create Report"

### Step 3: Create Dashboard with Custom Queries

For more advanced dashboards using the pre-built queries:

1. Create new data source → BigQuery → "Custom Query"
2. Select your project
3. Copy SQL from `bigquery_queries/1_report_orders_daily.sql`
4. Replace `${project_id}` with your project ID
5. Replace `${dataset_name}` with `storemate_data`
6. Modify `DECLARE` statements or remove them to use Looker's date filter:
   ```sql
   -- Remove DECLARE statements and use:
   WHERE
       SAFE.PARSE_DATE('%Y%m%d', DATE_IN) BETWEEN @DS_START_DATE AND @DS_END_DATE
   ```
7. Click "Add" → "Add to Report"

### Step 4: Build Your Dashboard

Example dashboard layout:

**Page 1: Overview**
- Scorecard: Total Sales (this month)
- Scorecard: Number of Orders (this month)
- Scorecard: Average Order Value (this month)
- Time series chart: Daily sales trend
- Pie chart: Sales by payment method

**Page 2: Items Analysis**
- Table: Top items by revenue
- Bar chart: Items by category
- Time series: Item drops over time

**Page 3: Customer Analysis**
- Table: Top customers
- Scorecard: New vs returning customers
- Geographic map (if you have address data)

### Step 5: Share Dashboard

1. Click "Share" button
2. Add email addresses of people who should have access
3. Set permissions:
   - **View**: Can see dashboard
   - **Edit**: Can modify dashboard
4. Or get shareable link: Click "Get report link"

---

## Regular Data Updates

Since this setup uses manual data syncs, you'll need to run the sync command regularly to keep your BigQuery data and dashboards up to date.

### Recommended Sync Schedule

Choose a frequency that matches your business needs:

**Weekly Sync** (recommended for most businesses):
```bash
# Run every Monday morning
uv run storemate-cli sync-to-bigquery
```

**Monthly Sync**:
```bash
# Run at the end of each month
uv run storemate-cli sync-to-bigquery
```

**Ad-hoc Sync**:
```bash
# Run whenever you need updated data
uv run storemate-cli sync-to-bigquery
```

### Sync Workflow

1. **Ensure DBF files are current**:
   - Copy latest DBF files to `data/raw/` directory

2. **Run sync command**:
   ```bash
   uv run storemate-cli sync-to-bigquery
   ```

   This will:
   - Convert DBF files to CSV
   - Upload to BigQuery raw dataset
   - Run dimensional transformations
   - Update analytics dataset

3. **Verify in BigQuery**:
   ```bash
   bq query --nouse_legacy_sql \
       "SELECT MAX(DATE_IN) as latest_date FROM \`$PROJECT_ID.$DATASET_NAME.claim\`"
   ```

4. **Check Looker Studio**:
   - Open your dashboard
   - Data should automatically reflect the update
   - No manual refresh needed

### Skip Options

If you already have processed CSV files:
```bash
# Skip DBF to CSV conversion
uv run storemate-cli sync-to-bigquery --skip-dbf
```

If you only want to update raw data without transformations:
```bash
# Skip dimensional transformations
uv run storemate-cli sync-to-bigquery --skip-transform
```

If you only want to run transformations on existing raw data:
```bash
# Run transformations only
uv run storemate-cli run-transformations
```

---

## Testing & Verification

### End-to-End Test

1. **Prepare test data**:
   ```bash
   # Ensure fresh DBF files in data/raw/
   ls -lh data/raw/*.dbf
   ```

2. **Run manual sync**:
   ```bash
   uv run storemate-cli sync-to-bigquery
   ```

3. **Verify in BigQuery**:
   ```bash
   # Check latest data
   bq query --nouse_legacy_sql \
       "SELECT MAX(DATE_IN) as latest_date FROM \`$PROJECT_ID.$DATASET_NAME.claim\`"

   # Check dimensional model
   bq query --nouse_legacy_sql \
       "SELECT COUNT(*) as row_count FROM \`$PROJECT_ID.$DATASET_NAME.fact_orders\`"
   ```

4. **Check Looker Studio**:
   - Open your dashboard
   - Verify new data appears
   - Test date filters and drill-downs

### Monitoring Checklist

- [ ] Sync command completes without errors
- [ ] BigQuery raw tables update with new data
- [ ] Dimensional model tables are populated
- [ ] Looker Studio dashboard shows current data
- [ ] Costs are within budget

---

## Troubleshooting

### "Permission denied" errors

**Solution**: Check service account permissions
```bash
gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:storemate-etl@*"
```

### Sync command takes too long

**Solutions**:
1. Process smaller batches of DBF files
2. Use `--skip-dbf` flag if CSVs are already generated
3. Use `--skip-transform` to only load raw data, run transformations separately later

### "Table not found" in Looker Studio

**Solutions**:
1. Verify table exists: `bq ls $PROJECT_ID:$DATASET_NAME`
2. Check permissions: User needs `bigquery.dataViewer` role
3. Refresh Looker Studio data source

### High costs

**Solutions**:
1. Check [Billing Reports](https://console.cloud.google.com/billing)
2. Reduce sync frequency (e.g., monthly instead of weekly)
3. Use partitioned tables for large datasets
4. Set up spending limits

### Data not updating

**Check**:
1. Verify sync command completed successfully: check terminal output for errors
2. Check BigQuery Console → Query History for failed queries
3. Verify latest data in raw tables:
   ```bash
   bq query --nouse_legacy_sql \
       "SELECT MAX(DATE_IN) FROM \`$PROJECT_ID.$DATASET_NAME.claim\`"
   ```

---

## Next Steps

1. **Schedule regular syncs**: Set a reminder (weekly/monthly) to run sync command
2. **Create more dashboards**: Build custom reports for different audiences
3. **Automate DBF uploads**: Set up automatic file sync from POS system
4. **Add data validation**: Create data quality checks in BigQuery
5. **Document for team**: Share dashboard links and document usage

## Support Resources

- **GCP Documentation**: https://cloud.google.com/docs
- **BigQuery**: https://cloud.google.com/bigquery/docs
- **Looker Studio**: https://support.google.com/looker-studio
- **Community**: https://stackoverflow.com/questions/tagged/google-cloud-platform

---

**Congratulations!** 🎉 You now have a cloud-based reporting pipeline with dimensional modeling and interactive dashboards!
