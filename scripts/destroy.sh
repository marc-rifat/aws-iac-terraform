#!/bin/bash

# Destroy script for Full-Stack AWS Lambda App
# This script destroys all infrastructure created by Terraform

set -e

ENVIRONMENT=${1:-dev}
PROJECT_NAME="iac-test"

echo "WARNING: This will destroy all infrastructure for environment: $ENVIRONMENT"
echo "This action cannot be undone!"
echo ""
read -p "Are you sure you want to continue? (type 'yes' to confirm): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment destruction cancelled."
    exit 1
fi

echo "Starting infrastructure destruction for environment: $ENVIRONMENT"

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Navigate to terraform directory
cd "$PROJECT_ROOT/terraform"

# Empty S3 buckets before destroying (Terraform can't destroy non-empty buckets)
echo "Emptying S3 buckets..."

# Get bucket names from Terraform state
MAIN_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
FRONTEND_S3_BUCKET=$(terraform output -raw frontend_s3_bucket_name 2>/dev/null || echo "")

# Function to empty an S3 bucket (versioning disabled - much simpler)
empty_s3_bucket() {
    local bucket_name=$1
    echo "Emptying S3 bucket: $bucket_name"
    
    # Check if bucket exists
    if ! aws s3api head-bucket --bucket "$bucket_name" 2>/dev/null; then
        echo "Bucket $bucket_name does not exist or is not accessible"
        return 0
    fi
    
    # Simple recursive delete (no versioning to worry about)
    echo "Removing all objects from bucket..."
    aws s3 rm s3://$bucket_name --recursive 2>/dev/null || true
    
    echo "Bucket $bucket_name emptied"
}

if [ -n "$MAIN_BUCKET" ]; then
    empty_s3_bucket "$MAIN_BUCKET"
fi

if [ -n "$FRONTEND_S3_BUCKET" ]; then
    empty_s3_bucket "$FRONTEND_S3_BUCKET"
fi

# Also try to find buckets by naming pattern if Terraform outputs fail
for bucket in $(aws s3 ls | grep "$PROJECT_NAME-$ENVIRONMENT" | awk '{print $3}' 2>/dev/null || echo ""); do
    if [ -n "$bucket" ]; then
        empty_s3_bucket "$bucket"
    fi
done

# ECR repository will be automatically cleaned up by Terraform (force_delete = true)
echo "ECR repository cleanup will be handled by Terraform..."

echo "Destroying Terraform infrastructure..."
terraform destroy -var-file="environments/$ENVIRONMENT/terraform.tfvars" -auto-approve

echo ""
echo "Infrastructure destroyed successfully!"

# Clean up temporary and sensitive files in Terraform directory
echo ""
echo "Cleaning up temporary and sensitive files..."
cd "$PROJECT_ROOT/terraform"

# Remove Terraform state files
echo "Removing Terraform state files..."
rm -f terraform.tfstate
rm -f terraform.tfstate.backup
rm -f .terraform.lock.hcl

# Remove Terraform cache directory
echo "Removing Terraform cache..."
rm -rf .terraform/

# Remove any crash log files
echo "Removing crash logs..."
rm -f crash.log
rm -f terraform-crash.log

# Remove any temporary files
echo "Removing temporary files..."
find . -name "*.tmp" -delete 2>/dev/null || true
find . -name "*.bak" -delete 2>/dev/null || true
find . -name "*~" -delete 2>/dev/null || true

# Remove Lambda ZIP files from modules
echo "Cleaning up Lambda artifacts..."
find modules/ -name "*.zip" -delete 2>/dev/null || true

# Remove any generated plan files
echo "Removing plan files..."
rm -f *.tfplan
rm -f tfplan

# Clean up backend build artifacts
echo "Cleaning up backend build artifacts..."
cd "$PROJECT_ROOT/backend"
rm -rf build/ 2>/dev/null || true
rm -rf target/ 2>/dev/null || true
rm -rf .gradle/classes/ 2>/dev/null || true

# Clean up frontend build artifacts
echo "Cleaning up frontend build artifacts..."
cd "$PROJECT_ROOT/frontend"
rm -rf dist/ 2>/dev/null || true
rm -rf .angular/cache/ 2>/dev/null || true

# Remove a specific S3 bucket
SPECIFIC_BUCKET="iac-testing-440225444492340"
SPECIFIC_REGION="us-east-1"

echo "Emptying and deleting specific S3 bucket: $SPECIFIC_BUCKET in region $SPECIFIC_REGION..."
if aws s3api head-bucket --bucket "$SPECIFIC_BUCKET" --region "$SPECIFIC_REGION" 2>/dev/null; then
    aws s3 rm "s3://$SPECIFIC_BUCKET" --recursive --region "$SPECIFIC_REGION" || true
    aws s3api delete-bucket --bucket "$SPECIFIC_BUCKET" --region "$SPECIFIC_REGION" || true
    echo "Bucket $SPECIFIC_BUCKET deleted."
else
    echo "Bucket $SPECIFIC_BUCKET does not exist or is not accessible."
fi

echo ""
echo "Cleanup completed for environment: $ENVIRONMENT"
echo "All AWS resources have been removed."
echo "All temporary and sensitive files have been cleaned up."