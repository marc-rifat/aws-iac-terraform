#!/bin/bash

# Full-Stack AWS Lambda App Deployment Script
# This script deploys the entire infrastructure and applications

set -e

ENVIRONMENT=${1:-dev}
PROJECT_NAME="iac-test"

echo "Starting deployment for environment: $ENVIRONMENT"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "ERROR: AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

# Get the script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Project root: $PROJECT_ROOT"

# Navigate to terraform directory
cd "$PROJECT_ROOT/terraform"

echo "Initializing Terraform..."
terraform init

echo "Planning Terraform deployment..."
terraform plan -var-file="environments/$ENVIRONMENT/terraform.tfvars"

echo "Applying Terraform configuration..."
terraform apply -var-file="environments/$ENVIRONMENT/terraform.tfvars" -auto-approve

# Get outputs
LAMBDA_FUNCTION_NAME=$(terraform output -raw lambda_function_name 2>/dev/null || echo "")
CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_distribution_domain 2>/dev/null || echo "")
API_GATEWAY_URL=$(terraform output -raw api_gateway_url 2>/dev/null || echo "")
ECS_SERVICE_URL=$(terraform output -raw ecs_service_url 2>/dev/null || echo "")

echo "Infrastructure deployed successfully!"

# Build Spring Boot backend with robust fallback system
echo ""
echo "Building Spring Boot backend..."
cd "$PROJECT_ROOT/backend"

# Build with Gradle (wrapper first, then system Gradle as fallback)
BUILD_SUCCESS=false

# Strategy 1: Try Gradle wrapper
if [ -f "./gradlew" ] || [ -f "./gradlew.bat" ]; then
    echo "Using Gradle wrapper to build Spring Boot application..."
    
    # Determine which wrapper to use (Windows .bat vs Unix shell script)
    GRADLE_WRAPPER="./gradlew"
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$WINDIR" ]]; then
        if [ -f "./gradlew.bat" ]; then
            GRADLE_WRAPPER="./gradlew.bat"
        fi
    fi
    
    # Fix potential wrapper permissions for Unix wrapper
    chmod +x ./gradlew 2>/dev/null || true
    
    # Build the application
    if $GRADLE_WRAPPER clean build -x test; then
        # Prefer the executable JAR (without -plain suffix) for Spring Boot
        JAR_FILE=$(find build/libs -name "*.jar" -not -name "*sources.jar" -not -name "*javadoc.jar" -not -name "*plain.jar" | head -n1)
        if [ -z "$JAR_FILE" ]; then
            # Fallback to any JAR if fat JAR not found
            JAR_FILE=$(find build/libs -name "*.jar" -not -name "*sources.jar" -not -name "*javadoc.jar" | head -n1)
        fi
        if [ -n "$JAR_FILE" ] && [ -f "$JAR_FILE" ]; then
            echo "Gradle wrapper build successful: $JAR_FILE"
            BUILD_SUCCESS=true
        fi
    fi
fi

# Strategy 2: Try system Gradle as fallback
if [ "$BUILD_SUCCESS" = "false" ] && command -v gradle >/dev/null 2>&1; then
    echo "Using system Gradle to build Spring Boot application..."
    if gradle clean build -x test; then
        # Prefer the executable JAR (without -plain suffix) for Spring Boot
        JAR_FILE=$(find build/libs -name "*.jar" -not -name "*sources.jar" -not -name "*javadoc.jar" -not -name "*plain.jar" | head -n1)
        if [ -z "$JAR_FILE" ]; then
            # Fallback to any JAR if fat JAR not found
            JAR_FILE=$(find build/libs -name "*.jar" -not -name "*sources.jar" -not -name "*javadoc.jar" | head -n1)
        fi
        if [ -n "$JAR_FILE" ] && [ -f "$JAR_FILE" ]; then
            echo "System Gradle build successful: $JAR_FILE"
            BUILD_SUCCESS=true
        fi
    fi
fi

# Exit if build failed
if [ "$BUILD_SUCCESS" = "false" ]; then
    echo "ERROR: Gradle build failed. Please ensure:"
    echo "  1. Gradle is installed (wrapper preferred)"
    echo "  2. build.gradle is configured correctly"
    echo "  3. Java 17+ is available"
    exit 1
fi

echo "Build completed. Using JAR: $JAR_FILE"

# Get ECR repository URL from Terraform output
cd "$PROJECT_ROOT/terraform"
ECR_REPO_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || echo "")

echo "ECR Repository URL: $ECR_REPO_URL"

if [ -n "$ECR_REPO_URL" ]; then
    # Login to ECR
    echo "Logging into ECR..."
    aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(echo $ECR_REPO_URL | cut -d'/' -f1)
    
    # Build and push Docker image
    cd "$PROJECT_ROOT/backend"
    echo "Building Docker image with JAR: $JAR_FILE"
    docker build --build-arg JAR_FILE="$JAR_FILE" -t $PROJECT_NAME-$ENVIRONMENT-backend .
    docker tag $PROJECT_NAME-$ENVIRONMENT-backend:latest $ECR_REPO_URL:latest
    
    echo "Pushing Docker image to ECR..."
    docker push $ECR_REPO_URL:latest
    
    # Update ECS service
    echo "Updating ECS service..."
    ECS_CLUSTER="$PROJECT_NAME-$ENVIRONMENT-cluster"
    ECS_SERVICE="$PROJECT_NAME-$ENVIRONMENT-backend-service"
    echo "Cluster: $ECS_CLUSTER"
    echo "Service: $ECS_SERVICE"
    aws ecs update-service --cluster "$ECS_CLUSTER" --service "$ECS_SERVICE" --force-new-deployment --no-cli-pager > /dev/null
    echo "ECS service update initiated successfully"
else
    echo "WARNING: ECR repository URL not found. Skipping backend deployment."
fi

# Build and deploy Angular frontend
echo ""
echo "Building and deploying Angular frontend..."
cd "$PROJECT_ROOT/frontend"

# Check if package.json exists
if [ ! -f "package.json" ]; then
    echo "ERROR: package.json not found in frontend directory."
    exit 1
fi

# Install dependencies
echo "Installing Node.js dependencies..."
npm install

# Update environment file with actual API URL
if [ -n "$API_GATEWAY_URL" ]; then
    echo "Updating environment configuration..."
    # Create a backup first
    cp src/environments/environment.prod.ts src/environments/environment.prod.ts.backup
    # Update the API URL
    sed -i.bak "s|apiUrl: 'https://your-api-domain.com'|apiUrl: '$API_GATEWAY_URL'|g" src/environments/environment.prod.ts
    # Remove backup file created by sed on macOS/BSD
    rm -f src/environments/environment.prod.ts.bak
fi

# Build for production
echo "Building Angular application for production..."
npm run build:prod

# Deploy to S3
if [ -n "$CLOUDFRONT_DOMAIN" ]; then
    # Get S3 bucket name from Terraform output
    cd "$PROJECT_ROOT/terraform"
    S3_BUCKET=$(terraform output -raw frontend_s3_bucket_name 2>/dev/null || echo "")
    
    if [ -z "$S3_BUCKET" ]; then
        # Try to find the frontend bucket
        S3_BUCKET=$(aws s3 ls | grep $PROJECT_NAME-$ENVIRONMENT-frontend | awk '{print $3}' | head -1)
    fi
    
    if [ -n "$S3_BUCKET" ]; then
        echo "Deploying to S3 bucket: $S3_BUCKET"
        cd "$PROJECT_ROOT/frontend"
        
        # Check if build output exists
        if [ -d "dist/iac-test-frontend" ]; then
            aws s3 sync dist/iac-test-frontend/ s3://$S3_BUCKET --delete
        else
            echo "ERROR: Build output not found in dist/iac-test-frontend"
            echo "Available directories in dist/:"
            ls -la dist/ 2>/dev/null || echo "dist/ directory not found"
            exit 1
        fi
        
        # Invalidate CloudFront cache
        cd "$PROJECT_ROOT/terraform"
        CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
        if [ -n "$CLOUDFRONT_ID" ]; then
            echo "Invalidating CloudFront cache..."
            aws cloudfront create-invalidation --distribution-id $CLOUDFRONT_ID --paths "/*"
        fi
    else
        echo "ERROR: Could not find S3 bucket for frontend deployment"
    fi
fi

echo ""
echo "Deployment completed successfully!"
echo ""
echo "Your application is now live:"
if [ -n "$CLOUDFRONT_DOMAIN" ]; then
    echo "   Frontend: https://$CLOUDFRONT_DOMAIN"
fi
if [ -n "$API_GATEWAY_URL" ]; then
    echo "   API Gateway: $API_GATEWAY_URL"
fi

# Display final deployment summary
echo ""
echo "================================================"
echo "              DEPLOYMENT SUMMARY"
echo "================================================"
echo "- Environment: $ENVIRONMENT"
echo "- Lambda Function: $LAMBDA_FUNCTION_NAME"
echo "- API Gateway URL: $API_GATEWAY_URL"
echo "- CloudFront Domain: https://$CLOUDFRONT_DOMAIN"
if [ -n "$ECS_SERVICE_URL" ]; then
    echo "- ECS Service URL: http://$ECS_SERVICE_URL"
fi
echo "================================================"