# Matrixify Results Upload Setup

This guide explains how to configure Matrixify to upload import results to your SFTP server for storage and monitoring.

## Overview

Matrixify can upload import result files to your SFTP server after each import completes. These files are then synced to S3 for long-term storage and monitoring.

## SFTP Configuration

### Connection Details
- **Server**: `s-34ce3bb4895a4fac8.server.transfer.us-east-1.amazonaws.com`
- **Username**: `matrixify`
- **Authentication**: SSH Key
- **Port**: 22
- **Directory**: `/valleyridge-inventory-sync/matrixify-results/`

### SSH Key
Use the existing `matrixify_key` private key that was created for the SFTP server.

## Matrixify Configuration Steps

### 1. Enable Results Upload
1. In your Matrixify import schedule settings
2. Look for "Upload Results" or "Export Results" option
3. Enable this feature

### 2. Configure SFTP Connection
1. **Connection Type**: SFTP
2. **Host**: `s-34ce3bb4895a4fac8.server.transfer.us-east-1.amazonaws.com`
3. **Port**: 22
4. **Username**: `matrixify`
5. **Authentication**: SSH Key
6. **Private Key**: Upload the `matrixify_key` private key file

### 3. Set Upload Directory
- **Remote Directory**: `/valleyridge-inventory-sync/matrixify-results/`
- **File Naming**: Use default or customize as needed

### 4. Configure File Types
Matrixify can upload different types of result files:
- **Import Results**: CSV file with detailed import results
- **Error Logs**: JSON or text files with error details
- **Summary Reports**: Summary of the import process

## Automated Sync to S3

### Manual Sync
Run the sync script to download files from SFTP and upload to S3:

```bash
./sync-matrixify-results.sh
```

### Automated Sync (Optional)
You can set up a cron job to run the sync script periodically:

```bash
# Add to crontab to run every 15 minutes after Matrixify imports
*/15 3-4 * * * /path/to/valleyridge-inventory-sync/sync-matrixify-results.sh
```

## S3 Storage Structure

Files are organized in S3 as follows:

```
s3://valleyridge-inventory-sync/
├── matrixify-results/
│   ├── 2025-07-30/
│   │   ├── 2025-07-30T20-05-00Z-import-results.csv
│   │   └── 2025-07-30T20-05-00Z-error-log.json
│   └── 2025-07-31/
│       └── ...
└── import-logs/
    ├── 2025-07-30/
    │   └── sftp-sync-2025-07-30T20-05-00Z.json
    └── 2025-07-31/
        └── ...
```

## File Types and Content

### Import Results CSV
Contains detailed information about each imported row:
- Row number
- Status (success/failed/skipped)
- Error messages (if any)
- Original data
- Processed data

### Error Logs
JSON files containing:
- Import ID
- Timestamp
- Error details
- Affected rows
- Import summary

### Sync Logs
JSON files created by the sync script:
- Sync timestamp
- Files processed
- File metadata
- Sync status

## Monitoring and Troubleshooting

### Check Recent Results
```bash
# List recent result files
aws s3 ls s3://valleyridge-inventory-sync/matrixify-results/$(date +%Y-%m-%d)/

# List recent sync logs
aws s3 ls s3://valleyridge-inventory-sync/import-logs/$(date +%Y-%m-%d)/
```

### View Import Results
```bash
# Download and view recent results
aws s3 cp s3://valleyridge-inventory-sync/matrixify-results/$(date +%Y-%m-%d)/latest-results.csv -
```

### Check Sync Status
```bash
# View recent sync log
aws s3 cp s3://valleyridge-inventory-sync/import-logs/$(date +%Y-%m-%d)/latest-sync.json -
```

## Benefits

1. **Complete Audit Trail**: All import results stored permanently
2. **Error Tracking**: Detailed error logs for troubleshooting
3. **Performance Monitoring**: Track import success rates over time
4. **Compliance**: Maintain records for business requirements
5. **Automated Storage**: No manual intervention required

## Troubleshooting

### SFTP Connection Issues
- Verify SSH key permissions: `chmod 600 matrixify_key`
- Test connection: `sftp -i matrixify_key matrixify@s-34ce3bb4895a4fac8.server.transfer.us-east-1.amazonaws.com`
- Check directory permissions on SFTP server

### Sync Script Issues
- Ensure AWS CLI is configured
- Check file permissions: `chmod +x sync-matrixify-results.sh`
- Verify S3 bucket access permissions

### Matrixify Configuration
- Ensure SFTP credentials are correct
- Check that upload directory exists and is writable
- Verify file naming conventions are compatible 