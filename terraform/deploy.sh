#!/bin/bash
# Terraform Deployment Script for StoreMate Infrastructure

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check prerequisites
print_header "Checking Prerequisites"

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed"
    echo "Install Terraform from: https://www.terraform.io/downloads"
    exit 1
fi
print_success "Terraform $(terraform version | head -n1 | cut -d'v' -f2) installed"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    print_error "gcloud CLI is not installed"
    echo "Install gcloud from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi
print_success "gcloud CLI installed"

# Check if logged in to gcloud
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" &> /dev/null; then
    print_warning "Not logged in to gcloud"
    echo "Running: gcloud auth login"
    gcloud auth login
fi
print_success "Authenticated with gcloud"

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    print_error "terraform.tfvars not found"
    echo "Copy terraform.tfvars.example to terraform.tfvars and fill in your values:"
    echo "  cp terraform.tfvars.example terraform.tfvars"
    echo "  vim terraform.tfvars"
    exit 1
fi
print_success "terraform.tfvars found"

# Extract project_id from terraform.tfvars
PROJECT_ID=$(grep 'project_id' terraform.tfvars | cut -d'"' -f2)
if [ -z "$PROJECT_ID" ]; then
    print_error "project_id not set in terraform.tfvars"
    exit 1
fi
print_success "Project ID: $PROJECT_ID"

# Set gcloud project
gcloud config set project "$PROJECT_ID" &> /dev/null
print_success "gcloud project set to $PROJECT_ID"

# Check if billing is enabled (optional check, Terraform will fail if not enabled)
print_header "Checking Billing"

# Try to check billing with a timeout
if command -v timeout &> /dev/null; then
    BILLING_ENABLED=$(timeout 5 gcloud beta billing projects describe "$PROJECT_ID" \
        --format="value(billingEnabled)" 2>/dev/null || echo "unknown")
else
    # macOS doesn't have timeout by default, use perl
    BILLING_ENABLED=$(perl -e 'alarm 5; exec @ARGV' -- \
        gcloud beta billing projects describe "$PROJECT_ID" \
        --format="value(billingEnabled)" 2>/dev/null || echo "unknown")
fi

if [ "$BILLING_ENABLED" = "unknown" ]; then
    print_warning "Unable to check billing status (this is OK, continuing...)"
    print_warning "If billing is not enabled, Terraform will fail with a clear error"
    print_warning "Enable billing at: https://console.cloud.google.com/billing/linkedaccount?project=$PROJECT_ID"
    echo ""
elif [ "$BILLING_ENABLED" != "True" ]; then
    print_warning "Billing is not enabled for project $PROJECT_ID"
    echo "Enable billing at: https://console.cloud.google.com/billing/linkedaccount?project=$PROJECT_ID"
    echo ""
    read -p "Press Enter once billing is enabled, or Ctrl+C to exit..."
else
    print_success "Billing is enabled"
fi

# Initialize Terraform
print_header "Initializing Terraform"
terraform init
print_success "Terraform initialized"

# Validate configuration
print_header "Validating Configuration"
terraform validate
print_success "Configuration is valid"

# Format check
terraform fmt -check || {
    print_warning "Terraform files need formatting"
    terraform fmt
    print_success "Formatted Terraform files"
}

# Plan
print_header "Planning Infrastructure Changes"
terraform plan -out=tfplan
print_success "Plan created successfully"

# Ask for confirmation
echo ""
read -p "Do you want to apply these changes? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_warning "Deployment cancelled"
    rm -f tfplan
    exit 0
fi

# Apply
print_header "Applying Infrastructure Changes"
terraform apply tfplan
rm -f tfplan
print_success "Infrastructure deployed successfully!"

# Show outputs
print_header "Deployment Summary"
terraform output -json | python3 -m json.tool

# Next steps
print_header "Next Steps"
echo "1. Download service account key:"
SA_EMAIL=$(terraform output -raw service_account_email)
echo "   gcloud iam service-accounts keys create ~/.config/gcloud/storemate-key.json \\"
echo "     --iam-account=$SA_EMAIL"
echo ""
echo "2. Set environment variables (add to ~/.zshrc or ~/.bashrc):"
terraform output -raw environment_variables
echo ""
echo "3. Test GCP connection:"
echo "   uv run storemate-cli test-gcp"
echo ""
echo "4. Run initial data sync:"
echo "   uv run storemate-cli sync-to-bigquery"
echo ""
echo "5. View BigQuery console:"
echo "   https://console.cloud.google.com/bigquery?project=$PROJECT_ID"
echo ""
print_success "Setup complete!"
