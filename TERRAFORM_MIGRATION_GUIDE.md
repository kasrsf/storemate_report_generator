# Infrastructure Migration: Manual Commands → Terraform

## 🎉 What Changed

Your StoreMate infrastructure can now be deployed with **one command** using Terraform (Infrastructure as Code) instead of running dozens of manual `gcloud` commands.

## Benefits of Terraform

### Before (Manual CLI Commands)
```bash
# Enable 7 different APIs manually
gcloud services enable bigquery.googleapis.com
gcloud services enable storage.googleapis.com
# ... 5 more commands

# Create service account
gcloud iam service-accounts create storemate-etl...
# Grant 5 different permissions manually
gcloud projects add-iam-policy-binding...
# ... 4 more commands

# Create BigQuery dataset
bq mk --dataset...

# Create storage bucket
gsutil mb...

# Deploy Cloud Function
gcloud functions deploy...
# ... lots of parameters

# Create Cloud Scheduler
gcloud scheduler jobs create...

# Total: ~30 commands to run manually
```

### After (Terraform)
```bash
cd terraform
./deploy.sh

# That's it! One command deploys everything.
```

## What Terraform Manages

### Complete Infrastructure
- ✅ **API Enablement** - All 7 required GCP APIs
- ✅ **IAM** - Service account with least-privilege permissions
- ✅ **BigQuery** - Dataset with proper configuration
- ✅ **Cloud Storage** - Bucket with lifecycle rules
- ✅ **Cloud Function** - ETL pipeline (Gen 2)
- ✅ **Cloud Scheduler** - Automated triggers
- ✅ **Networking** - All required permissions

### Infrastructure as Code Benefits
1. **Reproducible** - Deploy identical infrastructure anywhere
2. **Version Controlled** - Track changes in git
3. **Documented** - Configuration is self-documenting
4. **Automated** - No manual clicking or commands
5. **Safe** - Preview changes before applying
6. **Team-Friendly** - Everyone uses same config

## Quick Start with Terraform

### 1. Install Prerequisites

**macOS**:
```bash
# Install Terraform
brew install terraform

# gcloud CLI (if not already installed)
brew install --cask google-cloud-sdk
```

**Linux**:
```bash
# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# gcloud CLI
curl https://sdk.cloud.google.com | bash
```

**Windows**:
```powershell
# Install Terraform
choco install terraform

# Install gcloud CLI
choco install gcloudsdk
```

### 2. Authenticate
```bash
gcloud auth login
gcloud auth application-default login
```

### 3. Configure
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
vim terraform.tfvars
```

**Minimum required**:
```hcl
project_id          = "your-project-id"
storage_bucket_name = "your-project-id-storemate-data"
```

### 4. Deploy
```bash
./deploy.sh
```

**That's it!** ☕ Grab coffee while Terraform deploys everything.

## What Gets Created

### Resources (Automatically)
```
✓ 7 APIs enabled
✓ 1 Service Account created
✓ 6 IAM permissions granted
✓ 1 BigQuery dataset
✓ 1 Cloud Storage bucket (with lifecycle rules)
✓ 1 Cloud Function (Gen 2)
✓ 1 Cloud Scheduler job
```

### Time Savings
- **Manual**: 30-60 minutes (and error-prone)
- **Terraform**: 5-10 minutes (automated, consistent)

## Terraform File Structure

```
terraform/
├── main.tf                    # Main configuration
├── variables.tf               # Variable definitions
├── outputs.tf                 # Output values
├── terraform.tfvars           # Your values (gitignored)
├── terraform.tfvars.example   # Example template
├── deploy.sh                  # Deployment script
├── destroy.sh                 # Cleanup script
├── README.md                  # Full documentation
└── modules/                   # Modular components
    ├── iam/                   # Service account & permissions
    ├── bigquery/              # Data warehouse
    ├── storage/               # Cloud storage
    ├── cloud_function/        # ETL function
    └── scheduler/             # Automated triggers
```

## Common Operations

### Deploy Infrastructure
```bash
cd terraform
./deploy.sh
```

### View What's Deployed
```bash
terraform output
```

### Update Configuration
```bash
# Edit terraform.tfvars
vim terraform.tfvars

# Preview changes
terraform plan

# Apply changes
terraform apply
```

### Change Schedule
```bash
# Edit terraform.tfvars
scheduler_schedule = "0 * * * *"  # Change to hourly

# Apply
terraform apply
```

### Destroy Everything
```bash
./destroy.sh
```

⚠️ **Warning**: This deletes all data!

## Migration from Manual Setup

### If You Already Have Manual Resources

**Option 1: Import** (Keep existing data)
```bash
# Import existing BigQuery dataset
terraform import module.bigquery.google_bigquery_dataset.storemate_dataset \
  projects/YOUR-PROJECT/datasets/storemate_data

# Import existing bucket
terraform import module.storage.google_storage_bucket.storemate_bucket \
  YOUR-BUCKET-NAME
```

**Option 2: Fresh Start** (Recommended)
1. Backup your data:
   ```bash
   # Backup BigQuery
   bq extract your-dataset.table gs://your-backup-bucket/table.csv

   # Backup GCS
   gsutil -m cp -r gs://old-bucket gs://backup-bucket
   ```

2. Delete manual resources:
   ```bash
   # Delete scheduler
   gcloud scheduler jobs delete old-job

   # Delete function
   gcloud functions delete old-function

   # etc.
   ```

3. Deploy with Terraform:
   ```bash
   cd terraform
   ./deploy.sh
   ```

4. Restore data:
   ```bash
   uv run storemate-cli sync-to-bigquery
   ```

## Customization Examples

### Multi-Environment Setup

**Dev Environment** (`terraform/environments/dev/terraform.tfvars`):
```hcl
project_id          = "storemate-dev"
storage_bucket_name = "storemate-dev-data"
environment         = "dev"
scheduler_schedule  = "0 6 * * *"  # Once daily
```

**Prod Environment** (`terraform/environments/prod/terraform.tfvars`):
```hcl
project_id          = "storemate-prod"
storage_bucket_name = "storemate-prod-data"
environment         = "prod"
scheduler_schedule  = "0 */6 * * *"  # Every 6 hours
```

Deploy each:
```bash
# Deploy dev
cd terraform
terraform workspace new dev
terraform apply -var-file=environments/dev/terraform.tfvars

# Deploy prod
terraform workspace new prod
terraform apply -var-file=environments/prod/terraform.tfvars
```

### Custom Regions
```hcl
region            = "us-west1"
bigquery_location = "us-west1"
storage_location  = "us-west1"
```

### Custom Labels
```hcl
labels = {
  application = "storemate"
  environment = "production"
  team        = "data-engineering"
  cost_center = "ops"
  managed_by  = "terraform"
}
```

### Resource Sizing
```hcl
# Larger function for more data
function_memory    = "1024Mi"
function_timeout   = 540  # 9 minutes
function_max_instances = 3
```

## Troubleshooting

### "Terraform not found"
```bash
# Install Terraform
brew install terraform  # macOS
# or download from https://www.terraform.io/downloads
```

### "API not enabled"
```bash
# Terraform should enable these automatically, but if not:
gcloud services enable cloudfunctions.googleapis.com
```

### "Bucket name already taken"
Bucket names are globally unique. Change `storage_bucket_name` in `terraform.tfvars`.

### "Permission denied"
```bash
# Ensure you're an Owner or Editor
gcloud projects get-iam-policy YOUR-PROJECT-ID
```

### "State lock error"
```bash
# If using remote state and it's locked:
terraform force-unlock LOCK_ID
```

## Comparison: Manual vs Terraform

| Aspect | Manual CLI | Terraform |
|--------|-----------|-----------|
| **Setup Time** | 30-60 min | 5-10 min |
| **Commands** | ~30 commands | 1 command |
| **Reproducibility** | ❌ Hard | ✅ Easy |
| **Version Control** | ❌ No | ✅ Yes |
| **Team Sharing** | ❌ Hard | ✅ Easy |
| **Documentation** | ❌ Manual | ✅ Automatic |
| **Error Prone** | ❌ Yes | ✅ Validated |
| **State Tracking** | ❌ Manual | ✅ Automatic |
| **Drift Detection** | ❌ No | ✅ Yes |

## Best Practices

### 1. Use Version Control
```bash
git add terraform/*.tf
git commit -m "Add Terraform infrastructure configuration"
git push
```

### 2. Review Plans
```bash
# Always review before applying
terraform plan

# Save plan for review
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
```

### 3. Use Remote State (For Teams)
```hcl
# In main.tf
terraform {
  backend "gcs" {
    bucket = "your-terraform-state-bucket"
    prefix = "storemate/state"
  }
}
```

### 4. Tag Releases
```bash
git tag -a v1.0.0 -m "Production infrastructure v1.0.0"
git push --tags
```

## Cost Implications

**Terraform itself**: FREE

**GCP Resources**: Same cost whether deployed manually or with Terraform.

## Documentation

- **Terraform README**: [terraform/README.md](terraform/README.md)
- **Original Manual Guide**: [docs/GCP_SETUP_GUIDE.md](docs/GCP_SETUP_GUIDE.md)
- **Module Documentation**: Each module has its own README

## Support

### Terraform Issues
- **Terraform Docs**: https://www.terraform.io/docs
- **GCP Provider**: https://registry.terraform.io/providers/hashicorp/google/latest/docs

### Project Issues
- Check [terraform/README.md](terraform/README.md) for detailed troubleshooting
- See [docs/GCP_SETUP_GUIDE.md](docs/GCP_SETUP_GUIDE.md) for GCP-specific issues

## Next Steps After Deployment

1. **Download Service Account Key**:
   ```bash
   SA_EMAIL=$(terraform output -raw service_account_email)
   gcloud iam service-accounts keys create ~/.config/gcloud/storemate-key.json \
     --iam-account=$SA_EMAIL
   ```

2. **Set Environment Variables**:
   ```bash
   terraform output environment_variables >> ~/.zshrc
   source ~/.zshrc
   ```

3. **Test Connection**:
   ```bash
   uv run storemate-cli test-gcp
   ```

4. **Run Initial Sync**:
   ```bash
   uv run storemate-cli sync-to-bigquery
   ```

5. **Build Looker Dashboards**:
   - Follow [docs/LOOKER_STUDIO_GUIDE.md](docs/LOOKER_STUDIO_GUIDE.md)

---

**Congratulations!** 🎉 You now have professional, Infrastructure-as-Code deployment for your StoreMate analytics platform!
