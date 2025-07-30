#!/bin/bash
# Valley Ridge Inventory Sync - Process Inventory Lambda Deployment Script

set -e  # Exit on any error

echo "Deploying Process Inventory Lambda Function..."
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    print_error "AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

print_status "AWS CLI is configured"

# Check if AWS SAM CLI is installed
if ! command -v sam &> /dev/null; then
    print_error "AWS SAM CLI is not installed. Please install it first."
    print_status "Installation guide: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html"
    exit 1
fi

print_status "AWS SAM CLI is available"

# Get AWS region
AWS_REGION=$(aws configure get region)
print_status "Using AWS region: $AWS_REGION"

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed. Please install Node.js 18+ first."
    exit 1
fi

NODE_VERSION=$(node --version)
print_status "Node.js version: $NODE_VERSION"

# Install dependencies
print_status "Installing Node.js dependencies..."
npm install

# Build the SAM application
print_status "Building SAM application..."
sam build

# Deploy the application
print_status "Deploying SAM application..."
sam deploy --guided

print_status "Deployment completed successfully!"

echo ""
echo "=============================================="
echo "Deployment Summary"
echo "=============================================="
echo ""
echo "Lambda Function: valleyridge-process-inventory"
echo "S3 Bucket: valleyridge-inventory-sync"
echo "Region: $AWS_REGION"
echo ""
echo "Next steps:"
echo "1. Test the Lambda function with a sample file"
echo "2. Configure Matrixify to read from s3://valleyridge-inventory-sync/processed/latest/"
echo "3. Set up monitoring and alerting"
echo "4. Enable daily processing schedule if needed"
echo "" 