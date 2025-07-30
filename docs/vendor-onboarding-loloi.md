# Valley Ridge - Loloi Inventory Integration Setup

**Date**: July 30, 2025  
**Vendor**: Loloi  
**Project**: Daily Inventory Synchronization  

## Overview

Valley Ridge has implemented an automated inventory synchronization system that will receive daily inventory files from Loloi via SFTP. This system processes your inventory data and automatically updates our Shopify store.

## SFTP Connection Details

### Server Information
- **Host**: `s-34ce3bb4895a4fac8.server.transfer.us-east-1.amazonaws.com`
- **Port**: 22
- **Protocol**: SFTP (SSH File Transfer Protocol)
- **Authentication**: SSH Key

### User Credentials
- **Username**: `loloi-vendor`
- **SSH Private Key**: [Attached separately for security]

### Directory Structure
- **Upload Directory**: `/valleyridge-inventory-sync/incoming/`
- **File Naming**: Use your standard naming convention

## File Requirements

### Format
- **File Type**: Excel (.xls or .xlsx)
- **Encoding**: UTF-8
- **Delimiter**: Standard Excel format

### Required Columns
Your inventory file must include these columns (case-insensitive):
- **UPC** - Product UPC/barcode
- **Available QTY** - Current available quantity
- **Discontinued** - Product discontinued status (Yes/No)

### Optional Columns
- Any additional columns will be preserved but not processed

## Upload Process

### Daily Upload Schedule
- **Frequency**: Daily
- **Recommended Time**: Between 12:00 AM - 2:00 AM EST
- **Processing Time**: Files are processed within 15 minutes of upload

### Upload Steps
1. Connect to SFTP server using provided credentials
2. Navigate to `/valleyridge-inventory-sync/incoming/`
3. Upload your daily inventory file
4. Verify successful upload
5. Disconnect from SFTP server

### File Processing
- Files are automatically detected and processed
- Processed data is converted to CSV format
- Shopify inventory is updated automatically
- Processing logs are available for troubleshooting


## Security

### Credentials
- SSH key is unique to Loloi
- Credentials are encrypted in transit
- Access is limited to upload directory only
- No read access to other files or directories


---

*This document contains confidential information. Please handle securely and do not share with unauthorized parties.* 
