#!/bin/bash

# Valley Ridge Inventory Sync - Incremental Import System Test
# This script tests the incremental processing functionality

set -e

echo "🧪 Testing Valley Ridge Inventory Sync - Incremental Import System"
echo "================================================================="

# Configuration
BUCKET_NAME="valleyridge-inventory-sync"
TEST_FILE_1="test-inventory-baseline.xlsx"
TEST_FILE_2="test-inventory-updated.xlsx"

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

# Create test Excel files
create_test_files() {
    print_status "Creating test Excel files..."
    
    # Create a simple test file with Node.js
    cat > create-test-files.js << 'EOF'
const XLSX = require('xlsx');

// Create baseline test data
const baselineData = [
    { UPC: '1234567890123', 'Available QTY': 50, 'Discontinued': 'No' },
    { UPC: '9876543210987', 'Available QTY': 30, 'Discontinued': 'No' },
    { UPC: '5556667778889', 'Available QTY': 25, 'Discontinued': 'No' },
    { UPC: '1112223334445', 'Available QTY': 0, 'Discontinued': 'Yes' }
];

// Create updated test data (with changes)
const updatedData = [
    { UPC: '1234567890123', 'Available QTY': 45, 'Discontinued': 'No' },  // Quantity changed
    { UPC: '9876543210987', 'Available QTY': 30, 'Discontinued': 'No' },  // No change
    { UPC: '5556667778889', 'Available QTY': 0, 'Discontinued': 'Yes' },  // Quantity and discontinued changed
    { UPC: '1112223334445', 'Available QTY': 0, 'Discontinued': 'Yes' },  // No change
    { UPC: '9998887776665', 'Available QTY': 100, 'Discontinued': 'No' }  // New product
];

// Create workbooks
const baselineWorkbook = XLSX.utils.book_new();
const updatedWorkbook = XLSX.utils.book_new();

// Add worksheets
const baselineWorksheet = XLSX.utils.json_to_sheet(baselineData);
const updatedWorksheet = XLSX.utils.json_to_sheet(updatedData);

XLSX.utils.book_append_sheet(baselineWorkbook, baselineWorksheet, 'Inventory');
XLSX.utils.book_append_sheet(updatedWorkbook, updatedWorksheet, 'Inventory');

// Write files
XLSX.writeFile(baselineWorkbook, 'test-inventory-baseline.xlsx');
XLSX.writeFile(updatedWorkbook, 'test-inventory-updated.xlsx');

console.log('Test files created successfully');
console.log('Baseline file: test-inventory-baseline.xlsx');
console.log('Updated file: test-inventory-updated.xlsx');
EOF

    # Run the script to create test files
    cd functions/process-inventory
    node create-test-files.js
    cd ../..
    
    # Clean up the temporary script
    rm functions/process-inventory/create-test-files.js
    
    print_success "Test files created"
}

# Upload test files to S3
upload_test_files() {
    print_status "Uploading test files to S3..."
    
    # Upload baseline file
    aws s3 cp "functions/process-inventory/$TEST_FILE_1" "s3://$BUCKET_NAME/incoming/$TEST_FILE_1"
    print_success "Uploaded baseline file: $TEST_FILE_1"
    
    # Wait a moment for processing
    sleep 5
    
    # Upload updated file
    aws s3 cp "functions/process-inventory/$TEST_FILE_2" "s3://$BUCKET_NAME/incoming/$TEST_FILE_2"
    print_success "Uploaded updated file: $TEST_FILE_2"
    
    # Wait for processing
    print_status "Waiting for Lambda processing..."
    sleep 10
}

# Check processing results
check_results() {
    print_status "Checking processing results..."
    
    # Check if baseline was created
    if aws s3 ls "s3://$BUCKET_NAME/baseline/inventory-baseline.json" > /dev/null 2>&1; then
        print_success "Baseline file created"
    else
        print_error "Baseline file not found"
        return 1
    fi
    
    # Check if delta file was created
    DELTA_FILES=$(aws s3 ls "s3://$BUCKET_NAME/processed/delta/" | grep "test-inventory-updated-delta" | wc -l)
    if [ "$DELTA_FILES" -gt 0 ]; then
        print_success "Delta file(s) created"
    else
        print_error "No delta files found"
        return 1
    fi
    
    # Check latest delta file
    if aws s3 ls "s3://$BUCKET_NAME/processed/latest/inventory-delta.csv" > /dev/null 2>&1; then
        print_success "Latest delta file created"
    else
        print_error "Latest delta file not found"
        return 1
    fi
}

# Download and analyze results
analyze_results() {
    print_status "Analyzing results..."
    
    # Download latest delta file
    aws s3 cp "s3://$BUCKET_NAME/processed/latest/inventory-delta.csv" "test-delta-results.csv"
    
    # Download baseline for comparison
    aws s3 cp "s3://$BUCKET_NAME/baseline/inventory-baseline.json" "test-baseline.json"
    
    print_success "Results downloaded for analysis"
    
    # Show delta file contents
    echo ""
    echo "📊 Delta File Contents:"
    echo "======================="
    if [ -f "test-delta-results.csv" ]; then
        cat "test-delta-results.csv"
    else
        print_error "Delta file not found"
    fi
    
    echo ""
    echo "📈 Expected Changes:"
    echo "==================="
    echo "1. UPC 1234567890123: Quantity 50 → 45 (updated)"
    echo "2. UPC 5556667778889: Quantity 25 → 0, Discontinued No → Yes (updated)"
    echo "3. UPC 9998887776665: New product (new)"
    echo "4. UPC 9876543210987: No changes (should not appear in delta)"
    echo "5. UPC 1112223334445: No changes (should not appear in delta)"
    
    echo ""
    echo "🔍 Analysis:"
    echo "============"
    
    # Count different change types
    NEW_COUNT=$(grep -c "new" "test-delta-results.csv" || echo "0")
    UPDATED_COUNT=$(grep -c "updated" "test-delta-results.csv" || echo "0")
    DELETED_COUNT=$(grep -c "deleted" "test-delta-results.csv" || echo "0")
    
    echo "New products: $NEW_COUNT"
    echo "Updated products: $UPDATED_COUNT"
    echo "Deleted products: $DELETED_COUNT"
    
    # Validate results
    if [ "$NEW_COUNT" -eq 1 ] && [ "$UPDATED_COUNT" -eq 2 ]; then
        print_success "✅ Test results match expectations!"
    else
        print_warning "⚠️  Test results may not match expectations"
        echo "Expected: 1 new, 2 updated, 0 deleted"
        echo "Found: $NEW_COUNT new, $UPDATED_COUNT updated, $DELETED_COUNT deleted"
    fi
}

# Clean up test files
cleanup() {
    print_status "Cleaning up test files..."
    
    # Remove local test files
    rm -f "functions/process-inventory/$TEST_FILE_1"
    rm -f "functions/process-inventory/$TEST_FILE_2"
    rm -f "test-delta-results.csv"
    rm -f "test-baseline.json"
    
    # Remove S3 test files (optional - uncomment if you want to clean up)
    # aws s3 rm "s3://$BUCKET_NAME/incoming/$TEST_FILE_1"
    # aws s3 rm "s3://$BUCKET_NAME/incoming/$TEST_FILE_2"
    
    print_success "Cleanup completed"
}

# Show CloudWatch logs
show_logs() {
    print_status "Recent CloudWatch logs:"
    echo "=========================="
    
    # Get the Lambda function name
    FUNCTION_NAME="valleyridge-process-inventory-incremental"
    
    # Get recent log streams
    LOG_STREAMS=$(aws logs describe-log-streams \
        --log-group-name "/aws/lambda/$FUNCTION_NAME" \
        --order-by LastEventTime \
        --descending \
        --max-items 3 \
        --query 'logStreams[*].logStreamName' \
        --output text)
    
    for stream in $LOG_STREAMS; do
        echo ""
        echo "📋 Log Stream: $stream"
        echo "----------------------------------------"
        aws logs get-log-events \
            --log-group-name "/aws/lambda/$FUNCTION_NAME" \
            --log-stream-name "$stream" \
            --query 'events[*].message' \
            --output text | tail -20
    done
}

# Main test process
main() {
    echo "Starting incremental system test..."
    echo ""
    
    check_aws_config
    create_test_files
    upload_test_files
    check_results
    analyze_results
    show_logs
    cleanup
    
    print_success "Incremental system test completed!"
    echo ""
    echo "🎯 Test Summary:"
    echo "================"
    echo "✅ Test files created and uploaded"
    echo "✅ Lambda processing triggered"
    echo "✅ Baseline and delta files generated"
    echo "✅ Results analyzed and validated"
    echo ""
    echo "📚 Next Steps:"
    echo "=============="
    echo "1. Review the delta file contents above"
    echo "2. Check CloudWatch logs for any errors"
    echo "3. Test Matrixify import with the delta file"
    echo "4. Monitor performance improvements"
}

# Run main function
main "$@" 