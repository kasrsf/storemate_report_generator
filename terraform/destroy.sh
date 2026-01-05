#!/bin/bash
# Terraform Destroy Script for StoreMate Infrastructure

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_warning() {
    echo -e "${YELLOW}$1${NC}"
}

print_error() {
    echo -e "${RED}$1${NC}"
}

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_header "StoreMate Infrastructure Destruction"

print_warning "⚠️  WARNING ⚠️"
echo ""
print_error "This will PERMANENTLY DELETE:"
echo "  • BigQuery dataset and ALL data"
echo "  • Cloud Storage bucket and ALL files"
echo "  • Cloud Function"
echo "  • Cloud Scheduler job"
echo "  • Service Account"
echo ""
print_warning "This action CANNOT be undone!"
echo ""
print_warning "Make sure you have backups of any important data!"
echo ""

# Ask for confirmation
read -p "Type 'yes' to confirm destruction: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Destruction cancelled."
    exit 0
fi

# Double check
echo ""
read -p "Are you ABSOLUTELY SURE? Type 'destroy' to proceed: " CONFIRM2

if [ "$CONFIRM2" != "destroy" ]; then
    echo "Destruction cancelled."
    exit 0
fi

# Show what will be destroyed
print_header "Planning Destruction"
terraform plan -destroy

echo ""
read -p "Proceed with destruction? (yes/no): " FINAL_CONFIRM

if [ "$FINAL_CONFIRM" != "yes" ]; then
    echo "Destruction cancelled."
    exit 0
fi

# Destroy
print_header "Destroying Infrastructure"
terraform destroy -auto-approve

print_header "Cleanup Complete"
echo "All infrastructure has been destroyed."
echo ""
echo "State files preserved in case you need to recover."
echo "To completely remove Terraform state:"
echo "  rm -rf .terraform terraform.tfstate*"
