# StoreMate ETL Cloud Function

This directory contains the Google Cloud Function for automated ETL pipeline that syncs DBF data to BigQuery.

## Overview

The Cloud Function can be deployed in two modes:

1. **HTTP Trigger (Scheduled)**: Triggered by Cloud Scheduler for periodic syncs (e.g., hourly, daily)
2. **Storage Trigger (Event-driven)**: Triggered automatically when DBF files are uploaded to GCS

## Architecture

```
DBF Files → GCS Bucket → Cloud Function → BigQuery
                ↓
         Cloud Scheduler (optional)
```

## Prerequisites

1. **GCP Project** with billing enabled
2. **APIs Enabled**:
   ```bash
   gcloud services enable cloudfunctions.googleapis.com
   gcloud services enable cloudscheduler.googleapis.com
   gcloud services enable bigquery.googleapis.com
   gcloud services enable storage.googleapis.com
   ```

3. **Environment Variables**:
   ```bash
   export GCP_PROJECT_ID="your-project-id"
   export GCP_STORAGE_BUCKET="your-bucket-name"
   export GCP_DATASET_NAME="storemate_data"  # optional
   export GCP_LOCATION="US"  # optional
   ```

4. **GCS Bucket** created:
   ```bash
   gsutil mb -p $GCP_PROJECT_ID -l us-central1 gs://$GCP_STORAGE_BUCKET
   ```

## Deployment

### Quick Deploy

```bash
cd cloud_function
./deploy.sh
```

The script will prompt you to choose between HTTP or Storage trigger.

### Manual Deployment

#### Option 1: HTTP Trigger (for Cloud Scheduler)

```bash
# Copy source code
cp -r ../src/storemate_report_generator .

# Deploy function
gcloud functions deploy storemate-etl \
  --gen2 \
  --runtime=python311 \
  --region=us-central1 \
  --source=. \
  --entry-point=sync_data_http \
  --trigger-http \
  --allow-unauthenticated \
  --memory=512MB \
  --timeout=540s \
  --set-env-vars="GCP_PROJECT_ID=$GCP_PROJECT_ID,GCP_STORAGE_BUCKET=$GCP_STORAGE_BUCKET"

# Get function URL
FUNCTION_URL=$(gcloud functions describe storemate-etl --region=us-central1 --gen2 --format='value(serviceConfig.uri)')

# Create Cloud Scheduler job (daily at 2 AM)
gcloud scheduler jobs create http storemate-daily-sync \
  --schedule="0 2 * * *" \
  --uri=$FUNCTION_URL \
  --http-method=POST \
  --location=us-central1
```

#### Option 2: Storage Trigger (for GCS uploads)

```bash
# Copy source code
cp -r ../src/storemate_report_generator .

# Deploy function
gcloud functions deploy storemate-etl-storage \
  --gen2 \
  --runtime=python311 \
  --region=us-central1 \
  --source=. \
  --entry-point=sync_data_storage_trigger \
  --trigger-bucket=$GCP_STORAGE_BUCKET \
  --memory=512MB \
  --timeout=540s \
  --set-env-vars="GCP_PROJECT_ID=$GCP_PROJECT_ID,GCP_STORAGE_BUCKET=$GCP_STORAGE_BUCKET"
```

## Usage

### HTTP Trigger

Manually trigger the function:
```bash
curl -X POST $FUNCTION_URL
```

Or wait for Cloud Scheduler to trigger it automatically.

### Storage Trigger

Upload DBF files to trigger automatic processing:
```bash
gsutil cp data/*.dbf gs://$GCP_STORAGE_BUCKET/data/
```

The function will automatically detect the upload and start processing.

## Monitoring

### View logs

```bash
# HTTP trigger
gcloud functions logs read storemate-etl --region=us-central1 --gen2

# Storage trigger
gcloud functions logs read storemate-etl-storage --region=us-central1 --gen2
```

### Check BigQuery tables

```bash
bq ls $GCP_PROJECT_ID:storemate_data
```

## Scheduler Configuration

Common cron schedules:

- **Hourly**: `0 * * * *`
- **Every 6 hours**: `0 */6 * * *`
- **Daily at 2 AM**: `0 2 * * *`
- **Twice daily** (2 AM and 2 PM): `0 2,14 * * *`
- **Every Monday at 3 AM**: `0 3 * * 1`

Update scheduler:
```bash
gcloud scheduler jobs update http storemate-daily-sync \
  --schedule="0 */6 * * *" \
  --location=us-central1
```

## Troubleshooting

### Function timeout

If processing takes > 9 minutes, consider:
1. Using Cloud Run instead (60 minute timeout)
2. Processing files incrementally
3. Optimizing DBF to CSV conversion

### Permission errors

Ensure the Cloud Function service account has:
- `roles/bigquery.dataEditor` on the dataset
- `roles/storage.objectViewer` on the GCS bucket

Grant permissions:
```bash
PROJECT_NUMBER=$(gcloud projects describe $GCP_PROJECT_ID --format='value(projectNumber)')
SERVICE_ACCOUNT="$PROJECT_NUMBER-compute@developer.gserviceaccount.com"

# Grant BigQuery permissions
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/bigquery.dataEditor"

# Grant Storage permissions
gsutil iam ch serviceAccount:$SERVICE_ACCOUNT:objectViewer \
  gs://$GCP_STORAGE_BUCKET
```

## Cost Optimization

- Set `--max-instances=1` to prevent concurrent executions
- Use `--memory=512MB` (increase if needed for large files)
- Consider using Cloud Run for longer-running jobs
- Set up budget alerts in GCP Console

## Testing Locally

```bash
python main.py test
```

Note: Requires local credentials (`gcloud auth application-default login`)
