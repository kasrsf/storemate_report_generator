#!/bin/bash
# Deployment script for Cloud Function

set -e  # Exit on error

# Configuration
FUNCTION_NAME="storemate-etl"
REGION="${GCP_LOCATION:-us-central1}"
RUNTIME="python311"
MEMORY="512MB"
TIMEOUT="540s"  # 9 minutes (max for Cloud Functions Gen 2)
MAX_INSTANCES="1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== StoreMate ETL Cloud Function Deployment ===${NC}\n"

# Check required environment variables
if [ -z "$GCP_PROJECT_ID" ]; then
    echo -e "${RED}Error: GCP_PROJECT_ID environment variable not set${NC}"
    exit 1
fi

if [ -z "$GCP_STORAGE_BUCKET" ]; then
    echo -e "${RED}Error: GCP_STORAGE_BUCKET environment variable not set${NC}"
    exit 1
fi

echo -e "${YELLOW}Project ID:${NC} $GCP_PROJECT_ID"
echo -e "${YELLOW}Region:${NC} $REGION"
echo -e "${YELLOW}GCS Bucket:${NC} $GCP_STORAGE_BUCKET"
echo ""

# Prompt for deployment type
echo "Select deployment type:"
echo "  1) HTTP trigger (for Cloud Scheduler)"
echo "  2) Storage trigger (for GCS uploads)"
read -p "Enter choice [1-2]: " DEPLOY_TYPE

# Copy source code to cloud_function directory
echo -e "\n${YELLOW}Copying source code...${NC}"
rm -rf storemate_report_generator
cp -r ../src/storemate_report_generator .

# Update requirements.txt to use local package
cat > requirements.txt << EOF
# Cloud Functions framework
functions-framework==3.*

# Google Cloud libraries
google-cloud-bigquery==3.11.0
google-cloud-storage==2.10.0

# Data processing
pandas==2.0.0
db-dtypes==1.1.1
dbfread==2.0.7
EOF

if [ "$DEPLOY_TYPE" = "1" ]; then
    echo -e "\n${YELLOW}Deploying HTTP-triggered function...${NC}"

    gcloud functions deploy "$FUNCTION_NAME" \
        --gen2 \
        --runtime="$RUNTIME" \
        --region="$REGION" \
        --source=. \
        --entry-point=sync_data_http \
        --trigger-http \
        --allow-unauthenticated \
        --memory="$MEMORY" \
        --timeout="$TIMEOUT" \
        --max-instances="$MAX_INSTANCES" \
        --set-env-vars="GCP_PROJECT_ID=$GCP_PROJECT_ID,GCP_DATASET_NAME=${GCP_DATASET_NAME:-storemate_data},GCP_LOCATION=${GCP_LOCATION:-US},GCP_STORAGE_BUCKET=$GCP_STORAGE_BUCKET"

    echo -e "\n${GREEN}✓ Function deployed successfully!${NC}"
    echo -e "\nFunction URL:"
    gcloud functions describe "$FUNCTION_NAME" --region="$REGION" --gen2 --format="value(serviceConfig.uri)"

    echo -e "\n${YELLOW}To set up Cloud Scheduler:${NC}"
    echo "  gcloud scheduler jobs create http storemate-daily-sync \\"
    echo "    --schedule=\"0 2 * * *\" \\"
    echo "    --uri=\$(gcloud functions describe $FUNCTION_NAME --region=$REGION --gen2 --format='value(serviceConfig.uri)') \\"
    echo "    --http-method=POST \\"
    echo "    --location=$REGION"

elif [ "$DEPLOY_TYPE" = "2" ]; then
    echo -e "\n${YELLOW}Deploying Storage-triggered function...${NC}"

    gcloud functions deploy "$FUNCTION_NAME-storage" \
        --gen2 \
        --runtime="$RUNTIME" \
        --region="$REGION" \
        --source=. \
        --entry-point=sync_data_storage_trigger \
        --trigger-bucket="$GCP_STORAGE_BUCKET" \
        --memory="$MEMORY" \
        --timeout="$TIMEOUT" \
        --max-instances="$MAX_INSTANCES" \
        --set-env-vars="GCP_PROJECT_ID=$GCP_PROJECT_ID,GCP_DATASET_NAME=${GCP_DATASET_NAME:-storemate_data},GCP_LOCATION=${GCP_LOCATION:-US},GCP_STORAGE_BUCKET=$GCP_STORAGE_BUCKET"

    echo -e "\n${GREEN}✓ Function deployed successfully!${NC}"
    echo -e "\nFunction will be triggered when DBF files are uploaded to:"
    echo "  gs://$GCP_STORAGE_BUCKET/data/"

else
    echo -e "${RED}Invalid choice${NC}"
    exit 1
fi

# Cleanup
echo -e "\n${YELLOW}Cleaning up...${NC}"
rm -rf storemate_report_generator

echo -e "\n${GREEN}=== Deployment Complete ===${NC}"
