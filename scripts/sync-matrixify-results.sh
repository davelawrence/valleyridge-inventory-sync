#!/bin/bash

# Valley Ridge Inventory Sync - Matrixify Results Sync Script
# This script syncs Matrixify result files from SFTP to S3

set -e

# Configuration
SFTP_HOST="s-34ce3bb4895a4fac8.server.transfer.us-east-1.amazonaws.com"
SFTP_USER="matrixify"
SFTP_KEY="matrixify_key"
S3_BUCKET="valleyridge-inventory-sync"
TEMP_DIR="/tmp/matrixify-results"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
DATE_PREFIX=$(date -u +"%Y-%m-%d")

echo "Starting Matrixify results sync at $(date)"

# Create temp directory
mkdir -p "$TEMP_DIR"

# Download files from SFTP
echo "Connecting to SFTP server..."
sftp -i "$SFTP_KEY" -o StrictHostKeyChecking=no "$SFTP_USER@$SFTP_HOST" << EOF
    cd /
    lcd "$TEMP_DIR"
    get *.csv
    get *.json
    get *.txt
    bye
EOF

# Check if any files were downloaded
if [ -z "$(ls -A $TEMP_DIR 2>/dev/null)" ]; then
    echo "No files found on SFTP server"
    exit 0
fi

echo "Files downloaded to $TEMP_DIR:"
ls -la "$TEMP_DIR"

# Upload each file to S3 with metadata
for file in "$TEMP_DIR"/*; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        s3_key="matrixify-results/$DATE_PREFIX/${TIMESTAMP}-${filename}"
        
        echo "Uploading $filename to S3..."
        
        # Determine content type
        if [[ "$filename" == *.csv ]]; then
            content_type="text/csv"
        elif [[ "$filename" == *.json ]]; then
            content_type="application/json"
        else
            content_type="text/plain"
        fi
        
        # Upload to S3 with metadata
        aws s3 cp "$file" "s3://$S3_BUCKET/$s3_key" \
            --content-type "$content_type" \
            --metadata "processed-at=$(date -u +"%Y-%m-%dT%H:%M:%SZ"),processed-by=valleyridge-sync-script,source=matrixify-sftp,original-filename=$filename"
        
        echo "Uploaded: s3://$S3_BUCKET/$s3_key"
    fi
done

# Create sync log
sync_log="$TEMP_DIR/sync-log-$TIMESTAMP.json"
cat > "$sync_log" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "files_processed": $(ls "$TEMP_DIR"/*.csv "$TEMP_DIR"/*.json "$TEMP_DIR"/*.txt 2>/dev/null | wc -l),
  "files": [
$(for file in "$TEMP_DIR"/*.csv "$TEMP_DIR"/*.json "$TEMP_DIR"/*.txt 2>/dev/null; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
        echo "    {\"filename\": \"$filename\", \"size\": $size, \"s3_key\": \"matrixify-results/$DATE_PREFIX/${TIMESTAMP}-${filename}\"}"
    fi
done | tr '\n' ',' | sed 's/,$//')
  ],
  "message": "SFTP sync completed successfully"
}
EOF

# Upload sync log
aws s3 cp "$sync_log" "s3://$S3_BUCKET/import-logs/$DATE_PREFIX/sftp-sync-$TIMESTAMP.json" \
    --content-type "application/json" \
    --metadata "processed-at=$(date -u +"%Y-%m-%dT%H:%M:%SZ"),processed-by=valleyridge-sync-script,log-type=sftp-sync-summary"

echo "Sync log uploaded: s3://$S3_BUCKET/import-logs/$DATE_PREFIX/sftp-sync-$TIMESTAMP.json"

# Clean up temp directory
rm -rf "$TEMP_DIR"

echo "Matrixify results sync completed at $(date)" 