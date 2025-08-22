#!/bin/bash

# Valley Ridge Inventory Sync - Real Data Incremental Processing Test
# This script tests the incremental processing system with actual Loloi inventory files

set -e

echo "🧪 Testing Incremental Processing with Real Loloi Data"
echo "====================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

print_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

print_result() {
    echo -e "${CYAN}[RESULT]${NC} $1"
}

# Configuration
S3_BUCKET="valleyridge-inventory-sync"
STACK_NAME="valleyridge-inventory-sync-incremental"
TEST_DIR="test-results-$(date +%Y%m%d-%H%M%S)"
LOLOI_FILES=(
    "Loloi_Inventory w. UPC (10).XLS"
    "Loloi_Inventory w. UPC (11).XLS"
    "Loloi_Inventory w. UPC (12).XLS"
)

# Create test results directory
mkdir -p "$TEST_DIR"

# Function to check AWS CLI and SAM CLI
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found. Please install it first."
        exit 1
    fi
    
    if ! command -v sam &> /dev/null; then
        print_error "AWS SAM CLI not found. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to deploy the incremental processing system
deploy_system() {
    print_step "Deploying incremental processing system..."
    
    if [ ! -f "scripts/deploy-incremental.sh" ]; then
        print_error "Deploy script not found: scripts/deploy-incremental.sh"
        exit 1
    fi
    
    chmod +x scripts/deploy-incremental.sh
    ./scripts/deploy-incremental.sh
    
    print_success "System deployed successfully"
}

# Function to check if S3 bucket exists and create folder structure
setup_s3_structure() {
    print_step "Setting up S3 bucket structure..."
    
    # Check if bucket exists
    if ! aws s3 ls "s3://$S3_BUCKET" &> /dev/null; then
        print_error "S3 bucket $S3_BUCKET does not exist. Please deploy the system first."
        exit 1
    fi
    
    # Create folder structure
    aws s3api put-object --bucket "$S3_BUCKET" --key "baseline/" --content-type "application/x-directory"
    aws s3api put-object --bucket "$S3_BUCKET" --key "processed/delta/" --content-type "application/x-directory"
    aws s3api put-object --bucket "$S3_BUCKET" --key "processed/latest/" --content-type "application/x-directory"
    
    print_success "S3 bucket structure created"
}

# Function to upload a file to S3 and trigger processing
upload_and_process() {
    local file_path="$1"
    local test_name="$2"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    
    print_step "Processing $test_name..."
    
    # Generate unique key for this test
    local s3_key="incoming/test-$test_name-$timestamp.xls"
    
    # Upload file to S3
    print_status "Uploading $file_path to s3://$S3_BUCKET/$s3_key"
    aws s3 cp "$file_path" "s3://$S3_BUCKET/$s3_key"
    
    # Wait for Lambda processing
    print_status "Waiting for Lambda processing to complete..."
    sleep 30
    
    # Check for output files
    local baseline_exists=false
    local delta_exists=false
    local latest_exists=false
    
    # Check baseline
    if aws s3 ls "s3://$S3_BUCKET/baseline/inventory-baseline.json" &> /dev/null; then
        baseline_exists=true
        print_success "Baseline file created"
    else
        print_warning "Baseline file not found"
    fi
    
    # Check delta files
    local delta_files=$(aws s3 ls "s3://$S3_BUCKET/processed/delta/" --recursive | grep "delta-$timestamp" || true)
    if [ -n "$delta_files" ]; then
        delta_exists=true
        print_success "Delta files created"
        echo "$delta_files" > "$TEST_DIR/delta-files-$test_name.txt"
    else
        print_warning "Delta files not found"
    fi
    
    # Check latest file
    if aws s3 ls "s3://$S3_BUCKET/processed/latest/inventory-delta.csv" &> /dev/null; then
        latest_exists=true
        print_success "Latest file created"
    else
        print_warning "Latest file not found"
    fi
    
    # Download results for analysis
    if [ "$baseline_exists" = true ]; then
        aws s3 cp "s3://$S3_BUCKET/baseline/inventory-baseline.json" "$TEST_DIR/baseline-$test_name.json"
    fi
    
    if [ "$delta_exists" = true ]; then
        aws s3 cp "s3://$S3_BUCKET/processed/delta/" "$TEST_DIR/delta-$test_name/" --recursive
    fi
    
    if [ "$latest_exists" = true ]; then
        aws s3 cp "s3://$S3_BUCKET/processed/latest/inventory-delta.csv" "$TEST_DIR/latest-$test_name.csv"
    fi
    
    # Record results
    echo "Test: $test_name" >> "$TEST_DIR/test-results.txt"
    echo "  Input: $file_path" >> "$TEST_DIR/test-results.txt"
    echo "  S3 Key: $s3_key" >> "$TEST_DIR/test-results.txt"
    echo "  Baseline: $baseline_exists" >> "$TEST_DIR/test-results.txt"
    echo "  Delta: $delta_exists" >> "$TEST_DIR/test-results.txt"
    echo "  Latest: $latest_exists" >> "$TEST_DIR/test-results.txt"
    echo "" >> "$TEST_DIR/test-results.txt"
    
    return 0
}

# Function to analyze the results
analyze_results() {
    print_step "Analyzing test results..."
    
    echo "📊 INCREMENTAL PROCESSING TEST RESULTS" > "$TEST_DIR/analysis-report.txt"
    echo "=====================================" >> "$TEST_DIR/analysis-report.txt"
    echo "" >> "$TEST_DIR/analysis-report.txt"
    
    # Analyze baseline files
    echo "📈 BASELINE ANALYSIS:" >> "$TEST_DIR/analysis-report.txt"
    echo "====================" >> "$TEST_DIR/analysis-report.txt"
    for baseline_file in "$TEST_DIR"/baseline-*.json; do
        if [ -f "$baseline_file" ]; then
            local test_name=$(basename "$baseline_file" .json | sed 's/baseline-//')
            local record_count=$(jq 'length' "$baseline_file" 2>/dev/null || echo "Error reading JSON")
            echo "  $test_name: $record_count records" >> "$TEST_DIR/analysis-report.txt"
        fi
    done
    echo "" >> "$TEST_DIR/analysis-report.txt"
    
    # Analyze delta files
    echo "🔄 DELTA ANALYSIS:" >> "$TEST_DIR/analysis-report.txt"
    echo "=================" >> "$TEST_DIR/analysis-report.txt"
    for delta_dir in "$TEST_DIR"/delta-*/; do
        if [ -d "$delta_dir" ]; then
            local test_name=$(basename "$delta_dir" | sed 's/delta-//' | sed 's|/$||')
            local csv_files=$(find "$delta_dir" -name "*.csv" | wc -l)
            echo "  $test_name: $csv_files delta files" >> "$TEST_DIR/analysis-report.txt"
            
            # Count changes in each delta file
            for csv_file in "$delta_dir"/*.csv; do
                if [ -f "$csv_file" ]; then
                    local filename=$(basename "$csv_file")
                    local total_lines=$(wc -l < "$csv_file")
                    local data_lines=$((total_lines - 1)) # Subtract header
                    echo "    $filename: $data_lines changes" >> "$TEST_DIR/analysis-report.txt"
                fi
            done
        fi
    done
    echo "" >> "$TEST_DIR/analysis-report.txt"
    
    # Analyze latest files
    echo "📋 LATEST FILES:" >> "$TEST_DIR/analysis-report.txt"
    echo "===============" >> "$TEST_DIR/analysis-report.txt"
    for latest_file in "$TEST_DIR"/latest-*.csv; do
        if [ -f "$latest_file" ]; then
            local test_name=$(basename "$latest_file" .csv | sed 's/latest-//')
            local total_lines=$(wc -l < "$latest_file")
            local data_lines=$((total_lines - 1)) # Subtract header
            echo "  $test_name: $data_lines records" >> "$TEST_DIR/analysis-report.txt"
        fi
    done
    echo "" >> "$TEST_DIR/analysis-report.txt"
    
    # Check CloudWatch logs
    echo "📝 CLOUDWATCH LOGS:" >> "$TEST_DIR/analysis-report.txt"
    echo "==================" >> "$TEST_DIR/analysis-report.txt"
    local log_group="/aws/lambda/valleyridge-process-inventory-incremental"
    if aws logs describe-log-groups --log-group-name-prefix "$log_group" &> /dev/null; then
        local recent_logs=$(aws logs describe-log-streams --log-group-name "$log_group" --order-by LastEventTime --descending --max-items 3 --query 'logStreams[0:3].logStreamName' --output text 2>/dev/null || echo "No log streams found")
        echo "  Recent log streams: $recent_logs" >> "$TEST_DIR/analysis-report.txt"
    else
        echo "  Log group not found" >> "$TEST_DIR/analysis-report.txt"
    fi
    echo "" >> "$TEST_DIR/analysis-report.txt"
    
    print_success "Analysis complete. See $TEST_DIR/analysis-report.txt"
}

# Function to display summary
show_summary() {
    echo ""
    echo "🎉 INCREMENTAL PROCESSING TEST COMPLETE!"
    echo "======================================="
    echo ""
    echo "📁 Test Results Directory: $TEST_DIR"
    echo ""
    echo "📊 Files Generated:"
    echo "=================="
    echo "✅ Test results: $TEST_DIR/test-results.txt"
    echo "✅ Analysis report: $TEST_DIR/analysis-report.txt"
    echo "✅ Baseline files: $TEST_DIR/baseline-*.json"
    echo "✅ Delta files: $TEST_DIR/delta-*/"
    echo "✅ Latest files: $TEST_DIR/latest-*.csv"
    echo ""
    echo "🔍 Next Steps:"
    echo "=============="
    echo "1. Review the analysis report: cat $TEST_DIR/analysis-report.txt"
    echo "2. Check test results: cat $TEST_DIR/test-results.txt"
    echo "3. Examine baseline files for data structure"
    echo "4. Review delta files for change detection"
    echo "5. Verify latest files for current state"
    echo ""
    echo "📝 CloudWatch Logs:"
    echo "=================="
    echo "aws logs tail /aws/lambda/valleyridge-process-inventory-incremental --follow"
    echo ""
}

# Main test execution
main() {
    print_status "Starting incremental processing test with real Loloi data..."
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Deploy system if needed
    read -p "Do you want to deploy the incremental processing system? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        deploy_system
    else
        print_status "Skipping deployment. Assuming system is already deployed."
    fi
    
    # Setup S3 structure
    setup_s3_structure
    
    # Process each file in sequence
    print_step "Processing Loloi inventory files in sequence..."
    echo ""
    
    for i in "${!LOLOI_FILES[@]}"; do
        local file="${LOLOI_FILES[$i]}"
        local test_name="test-$(printf "%02d" $((i+1)))"
        
        if [ ! -f "$file" ]; then
            print_error "File not found: $file"
            continue
        fi
        
        print_status "Processing file $((i+1)) of ${#LOLOI_FILES[@]}: $file"
        upload_and_process "$file" "$test_name"
        echo ""
        
        # Wait between files to ensure processing completes
        if [ $i -lt $((${#LOLOI_FILES[@]}-1)) ]; then
            print_status "Waiting 10 seconds before next file..."
            sleep 10
        fi
    done
    
    # Analyze results
    analyze_results
    
    # Show summary
    show_summary
    
    print_success "Incremental processing test completed successfully!"
}

# Run main function
main "$@" 