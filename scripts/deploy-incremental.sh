#!/bin/bash

# Valley Ridge Inventory Sync - Incremental Import System Deployment
# This script deploys the incremental processing Lambda function

set -e

echo "🚀 Deploying Valley Ridge Inventory Sync - Incremental Import System"
echo "=================================================================="

# Configuration
STACK_NAME="valleyridge-inventory-sync-incremental"
FUNCTION_DIR="functions/process-inventory"
CONFIG_FILE="samconfig-incremental.toml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is configured
check_aws_config() {
    print_status "Checking AWS configuration..."
    
    if ! aws sts get-caller-identity > /dev/null 2>&1; then
        print_error "AWS CLI not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "AWS CLI configured"
}

# Check if SAM CLI is installed
check_sam_cli() {
    print_status "Checking SAM CLI installation..."
    
    if ! command -v sam &> /dev/null; then
        print_error "SAM CLI not found. Please install AWS SAM CLI first."
        print_status "Installation guide: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html"
        exit 1
    fi
    
    print_success "SAM CLI found"
}

# Validate configuration files
validate_config() {
    print_status "Validating configuration files..."
    
    if [ ! -f "$FUNCTION_DIR/$CONFIG_FILE" ]; then
        print_error "Configuration file not found: $FUNCTION_DIR/$CONFIG_FILE"
        exit 1
    fi
    
    if [ ! -f "$FUNCTION_DIR/template-incremental.yaml" ]; then
        print_error "SAM template not found: $FUNCTION_DIR/template-incremental.yaml"
        exit 1
    fi
    
    if [ ! -f "$FUNCTION_DIR/incremental-processor.js" ]; then
        print_error "Lambda function not found: $FUNCTION_DIR/incremental-processor.js"
        exit 1
    fi
    
    print_success "Configuration files validated"
}

# Build the SAM application
build_sam() {
    print_status "Building SAM application..."
    
    cd "$FUNCTION_DIR"
    
    if sam build --template-file template-incremental.yaml; then
        print_success "SAM build completed"
    else
        print_error "SAM build failed"
        exit 1
    fi
}

# Deploy the SAM application
deploy_sam() {
    print_status "Deploying SAM application..."
    
    if sam deploy --config-file "$CONFIG_FILE"; then
        print_success "SAM deployment completed"
    else
        print_error "SAM deployment failed"
        exit 1
    fi
}

# Verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    # Check if CloudFormation stack exists
    if aws cloudformation describe-stacks --stack-name "$STACK_NAME" > /dev/null 2>&1; then
        print_success "CloudFormation stack created successfully"
    else
        print_error "CloudFormation stack verification failed"
        exit 1
    fi
    
    # Check if Lambda function exists
    if aws lambda get-function --function-name "valleyridge-process-inventory-incremental" > /dev/null 2>&1; then
        print_success "Lambda function deployed successfully"
    else
        print_error "Lambda function verification failed"
        exit 1
    fi
}

# Create S3 folder structure
create_s3_structure() {
    print_status "Creating S3 folder structure..."
    
    BUCKET_NAME="valleyridge-inventory-sync"
    
    # Create baseline folder
    aws s3api put-object --bucket "$BUCKET_NAME" --key "baseline/" > /dev/null 2>&1 || true
    
    # Create delta folder
    aws s3api put-object --bucket "$BUCKET_NAME" --key "processed/delta/" > /dev/null 2>&1 || true
    
    print_success "S3 folder structure created"
}

# Display deployment summary
show_summary() {
    echo ""
    echo "🎉 Deployment Summary"
    echo "===================="
    echo "Stack Name: $STACK_NAME"
    echo "Lambda Function: valleyridge-process-inventory-incremental"
    echo "S3 Bucket: valleyridge-inventory-sync"
    echo ""
    echo "📁 S3 Structure:"
    echo "  - incoming/ (vendor uploads)"
    echo "  - processed/delta/ (delta files)"
    echo "  - processed/latest/ (latest delta for Matrixify)"
    echo "  - baseline/ (baseline data for comparison)"
    echo ""
    echo "🔧 Next Steps:"
    echo "  1. Test with a sample inventory file"
    echo "  2. Verify delta file generation"
    echo "  3. Test Matrixify import with delta file"
    echo "  4. Monitor CloudWatch logs and metrics"
    echo ""
    echo "📚 Documentation: docs/incremental-import-system.md"
}

# Main deployment process
main() {
    echo "Starting deployment process..."
    echo ""
    
    check_aws_config
    check_sam_cli
    validate_config
    build_sam
    deploy_sam
    verify_deployment
    create_s3_structure
    show_summary
    
    print_success "Incremental import system deployment completed successfully!"
}

# Run main function
main "$@" 