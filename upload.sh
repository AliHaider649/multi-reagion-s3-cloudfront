#!/bin/bash
# Upload website content to S3

BASE=$1
REGION=${2:-us-east-1}  # Optional second argument for region, default us-east-1

if [ -z "$BASE" ]; then
  echo "Usage: ./upload.sh <base-name> [region]"
  exit 1
fi

BUCKET_NAME="${BASE}-primary-${REGION}"

# Check if folder exists
if [ ! -d "examples/website" ]; then
  echo "❌ Directory examples/website does not exist"
  exit 1
fi

# Sync files
aws s3 sync examples/website s3://$BUCKET_NAME/ --delete --region $REGION

if [ $? -eq 0 ]; then
  echo "✅ Website uploaded to S3 bucket: $BUCKET_NAME"
else
  echo "❌ Failed to upload website. Check AWS CLI credentials and bucket name."
fi
