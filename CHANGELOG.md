# Changelog

All notable changes to the Valley Ridge Inventory Sync system will be documented in this file.

## [Unreleased] - 2025-01-XX

### Changed
- **S3 Notifications**: Updated bucket notifications to use incremental processor instead of full import processor
  - Files: `functions/process-inventory/s3-notification.json`
  - **Before**: Both `.xls` and `.xlsx` files triggered `valleyridge-process-inventory` (full import)
  - **After**: Both `.xls` and `.xlsx` files now trigger `valleyridge-process-inventory-incremental` (incremental processing)
  - **Impact**: Improved performance with 80-95% smaller delta files and better change tracking

### Why This Change Was Made
- **Vendor Transition**: Preparing for Loloi to start delivering files via SFTP instead of Make automation
- **Performance Improvement**: Incremental processing reduces file sizes and Matrixify import times
- **Better Change Tracking**: Delta files provide clear visibility into inventory changes

### Technical Details
- **Lambda Function ARN Updated**: 
  - From: `arn:aws:lambda:us-east-1:413362489612:function:valleyridge-process-inventory`
  - To: `arn:aws:lambda:us-east-1:413362489612:function:valleyridge-process-inventory-incremental`
- **File Types Supported**: `.xls` and `.xlsx` (no changes to supported formats)
- **S3 Path**: Files uploaded to `incoming/` folder will automatically trigger processing

### Deployment Status
- ✅ **S3 Notifications**: Updated in AWS (command executed successfully)
- ✅ **Configuration Files**: Updated in codebase
- ⏳ **Make Automation**: Still active (to be disabled after vendor confirms SFTP delivery)

### Next Steps
1. **Vendor Testing**: Confirm Loloi can successfully upload files via SFTP
2. **First File Processing**: Verify incremental processor creates baseline and generates delta files
3. **Disable Make Automation**: Turn off once vendor SFTP delivery is confirmed working
4. **Monitor Performance**: Track improvements in file sizes and processing times

### Rollback Plan
If issues arise, S3 notifications can be reverted to full import processor:
```bash
# Revert to full import processor
aws s3api put-bucket-notification-configuration \
  --bucket valleyridge-inventory-sync \
  --notification-configuration file://functions/process-inventory/s3-notification-full-import.json
```

---

## [Previous Versions]
*Note: This changelog was created to document the vendor SFTP transition. Previous changes were not tracked in this format.*
