# StoreMate Infrastructure as Code (Terraform)

This directory contains Terraform configuration for deploying all StoreMate cloud infrastructure to Google Cloud Platform.

## What Gets Deployed

### Infrastructure Components
- ✅ **BigQuery Dataset** - Data warehouse for analytics
- ✅ **Cloud Storage Bucket** - Data lake and backups
- ✅ **Service Account** - Automated ETL operations
- ✅ **Cloud Function** - Serverless ETL pipeline
- ✅ **Cloud Scheduler** - Automated daily runs
- ✅ **IAM Permissions** - Least-privilege access control

### Architecture
```
Cloud Scheduler (daily trigger)
        ↓
Cloud Function (ETL)
        ↓
    ┌───┴────┐
    ↓        ↓
BigQuery  Cloud Storage
(warehouse) (data lake)
```

## Prerequisites

1. **Google Cloud Account** with billing enabled
2. **gcloud CLI** installed ([Install Guide](https://cloud.google.com/sdk/docs/install))
3. **Terraform** >= 1.0 installed ([Install Guide](https://www.terraform.io/downloads))
4. **Project created** in GCP Console

## Quick Start

### 1. Authenticate with Google Cloud
```bash
gcloud auth login
gcloud auth application-default login
```

### 2. Configure Variables
```bash
# Copy example file
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

**Required variables**:
- `project_id` - Your GCP project ID
- `storage_bucket_name` - Globally unique bucket name (e.g., `yourproject-storemate-data`)

### 3. Deploy Infrastructure
```bash
./deploy.sh
```

That's it! The script will:
- ✅ Check prerequisites
- ✅ Initialize Terraform
- ✅ Validate configuration
- ✅ Show you the plan
- ✅ Deploy infrastructure
- ✅ Display next steps

## Manual Deployment

If you prefer manual control:

```bash
# Initialize
terraform init

# Plan
terraform plan -out=tfplan

# Apply
terraform apply tfplan

# Show outputs
terraform output
```

## Configuration

### Basic Configuration (terraform.tfvars)
```hcl
project_id          = "my-project-123"
storage_bucket_name = "my-project-storemate-data"
```

### Advanced Configuration
```hcl
# Custom region
region = "us-west1"

# Custom dataset name
dataset_name = "storemate_prod"

# Different schedule (hourly)
scheduler_schedule = "0 * * * *"

# Different timezone
scheduler_timezone = "America/New_York"

# Labels for organization
labels = {
  application = "storemate"
  environment = "production"
  team        = "data-engineering"
}
```

## Module Structure

```
terraform/
├── main.tf                  # Main configuration
├── variables.tf             # Variable definitions
├── outputs.tf               # Output definitions
├── terraform.tfvars         # Your values (gitignored)
├── terraform.tfvars.example # Example values
├── deploy.sh                # Deployment script
├── destroy.sh               # Cleanup script
└── modules/
    ├── iam/                 # Service account & permissions
    ├── bigquery/            # Data warehouse
    ├── storage/             # Cloud storage
    ├── cloud_function/      # ETL function
    └── scheduler/           # Automated triggers
```

## Outputs

After deployment, Terraform provides these outputs:

```bash
# View all outputs
terraform output

# View specific output
terraform output cloud_function_url

# View as JSON
terraform output -json
```

**Key Outputs**:
- `cloud_function_url` - HTTP endpoint for manual triggers
- `service_account_email` - For downloading credentials
- `dataset_id` - BigQuery dataset identifier
- `bucket_name` - Cloud Storage bucket name

## Scheduler Configuration

The Cloud Scheduler runs your ETL pipeline automatically.

### Common Schedules
```hcl
# Hourly
scheduler_schedule = "0 * * * *"

# Every 6 hours
scheduler_schedule = "0 */6 * * *"

# Daily at 2 AM
scheduler_schedule = "0 2 * * *"

# Twice daily (2 AM and 2 PM)
scheduler_schedule = "0 2,14 * * *"

# Weekdays only at 6 AM
scheduler_schedule = "0 6 * * 1-5"
```

### Update Schedule
```bash
# Edit terraform.tfvars
vim terraform.tfvars

# Apply changes
terraform apply

# Or update just the scheduler
terraform apply -target=module.scheduler
```

## State Management

### Local State (Default)
State is stored in `terraform.tfstate` (gitignored).

**Pros**: Simple, no setup
**Cons**: Not shared, no locking

### Remote State (Recommended for Teams)

Uncomment in `main.tf`:
```hcl
terraform {
  backend "gcs" {
    bucket = "your-terraform-state-bucket"
    prefix = "storemate/state"
  }
}
```

Create state bucket:
```bash
gsutil mb -p your-project-id gs://your-terraform-state-bucket
gsutil versioning set on gs://your-terraform-state-bucket
```

## Cost Estimation

### Expected Monthly Costs
- BigQuery: ~$0-5 (free tier covers typical usage)
- Cloud Storage: ~$1 (first 5 GB free)
- Cloud Functions: ~$0 (2M invocations free)
- Cloud Scheduler: ~$0.10 (3 jobs free)

**Total**: ~$1-10/month for typical dry cleaning business

### View Current Costs
```bash
# Open billing dashboard
gcloud alpha billing accounts list
gcloud beta billing budgets list --billing-account=YOUR-BILLING-ACCOUNT

# Or visit GCP Console
https://console.cloud.google.com/billing
```

## Updating Infrastructure

### Update Function Code
```bash
# Make changes to cloud_function/main.py
vim ../cloud_function/main.py

# Deploy update
terraform apply
```

### Update Configuration
```bash
# Edit variables
vim terraform.tfvars

# Preview changes
terraform plan

# Apply changes
terraform apply
```

## Destroying Infrastructure

### Complete Teardown
```bash
./destroy.sh
```

Or manually:
```bash
terraform destroy
```

⚠️ **Warning**: This will delete:
- All BigQuery tables and data
- Cloud Storage bucket and files
- Cloud Function
- Scheduler job
- Service account

Data in BigQuery is **not recoverable** after deletion!

### Partial Teardown
```bash
# Destroy just the scheduler
terraform destroy -target=module.scheduler

# Destroy function but keep data
terraform destroy -target=module.cloud_function
```

## Troubleshooting

### "API not enabled" Error
```bash
# Enable required APIs manually
gcloud services enable bigquery.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudscheduler.googleapis.com
```

### "Bucket name already exists" Error
Bucket names are globally unique. Change `storage_bucket_name` in `terraform.tfvars`.

### "Permission denied" Error
Ensure you have Owner or Editor role:
```bash
gcloud projects get-iam-policy YOUR-PROJECT-ID
```

### "Backend initialization error"
```bash
# Re-initialize
rm -rf .terraform
terraform init
```

### View Terraform State
```bash
# List resources
terraform state list

# Show specific resource
terraform state show google_bigquery_dataset.storemate_dataset
```

## Best Practices

### 1. Use Workspaces for Environments
```bash
# Create dev workspace
terraform workspace new dev
terraform apply -var-file=dev.tfvars

# Create prod workspace
terraform workspace new prod
terraform apply -var-file=prod.tfvars

# List workspaces
terraform workspace list

# Switch workspace
terraform workspace select prod
```

### 2. Version Control
```bash
# .gitignore already includes:
terraform.tfstate
terraform.tfstate.backup
.terraform/
*.tfvars  # Except .example
```

### 3. Plan Before Apply
```bash
# Always review plan
terraform plan

# Save plan for review
terraform plan -out=tfplan
# Review plan
terraform show tfplan
# Apply reviewed plan
terraform apply tfplan
```

### 4. Use Remote State for Teams
```hcl
# In main.tf
terraform {
  backend "gcs" {
    bucket = "your-state-bucket"
    prefix = "storemate/state"
  }
}
```

## Security

### Service Account Key
Download and secure the service account key:
```bash
# Download key
gcloud iam service-accounts keys create ~/.config/gcloud/storemate-key.json \
  --iam-account=$(terraform output -raw service_account_email)

# Secure permissions
chmod 600 ~/.config/gcloud/storemate-key.json

# Never commit to git!
```

### IAM Permissions
The service account has least-privilege permissions:
- `bigquery.dataEditor` - Create/modify tables
- `bigquery.jobUser` - Run queries
- `storage.objectAdmin` - Manage bucket files
- `cloudfunctions.invoker` - Invoke function
- `iam.serviceAccountUser` - Use service account

### Secrets Management
For sensitive values, use Google Secret Manager:
```hcl
# In terraform
data "google_secret_manager_secret_version" "db_password" {
  secret = "db-password"
}
```

## Support

- **Terraform Docs**: https://www.terraform.io/docs
- **GCP Provider Docs**: https://registry.terraform.io/providers/hashicorp/google/latest/docs
- **Issues**: Check `../docs/GCP_SETUP_GUIDE.md` troubleshooting section

## Migration from Manual Setup

If you previously set up infrastructure manually:

1. **Import existing resources**:
```bash
# Import BigQuery dataset
terraform import module.bigquery.google_bigquery_dataset.storemate_dataset projects/PROJECT_ID/datasets/DATASET_ID

# Import storage bucket
terraform import module.storage.google_storage_bucket.storemate_bucket BUCKET_NAME
```

2. **Or start fresh**: Destroy manual resources and deploy with Terraform

---

**Infrastructure as Code Benefits**:
- ✅ Reproducible deployments
- ✅ Version controlled configuration
- ✅ Easy environment replication
- ✅ Documented infrastructure
- ✅ Automated deployment
- ✅ Consistent team setup
