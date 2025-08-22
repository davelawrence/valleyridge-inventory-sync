# Valley Ridge Inventory Sync System

[![AWS](https://img.shields.io/badge/AWS-Lambda-orange.svg)](https://aws.amazon.com/lambda/)
[![Node.js](https://img.shields.io/badge/Node.js-18.x-green.svg)](https://nodejs.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen.svg)]()

## 📋 Overview

This system automates the process of receiving Excel inventory files from Loloi (vendor), processing them into CSV format, and making them available for import into Shopify via Matrixify. The system includes both full import and incremental/delta processing capabilities.

## 🏗️ Architecture

- **AWS Lambda**: Processes Excel files to CSV format
- **AWS S3**: Stores incoming files and processed CSV files
- **AWS Transfer Family**: SFTP server for vendor file uploads
- **AWS CloudWatch**: Monitoring and metrics
- **Matrixify**: Shopify app for bulk import/export

## 🚀 Features

### Core Features
- ✅ **Automatic Processing**: Excel files uploaded to S3 trigger Lambda processing
- ✅ **Case-Insensitive Headers**: Handles variations in column names
- ✅ **File Extension Detection**: Works with files that have no extensions
- ✅ **Pre-signed URLs**: Generates temporary URLs for Matrixify access
- ✅ **SFTP Integration**: Secure file transfer for vendor uploads
- ✅ **Vendor SFTP Delivery**: Active integration with Loloi for automated file delivery

### Advanced Features
- 🆕 **Incremental Processing**: Generates delta files with only changed records
- 🆕 **Change Tracking**: Identifies new, updated, and deleted products
- 🆕 **Performance Optimization**: 80-95% reduction in file sizes
- 🆕 **Audit Trail**: Detailed change logging and reasons

## 📁 Project Structure

```
valleyridge-inventory-sync/
├── functions/
│   └── process-inventory/          # Main Lambda function
│       ├── index.js               # Full import processing logic
│       ├── incremental-processor.js # Incremental processing logic
│       ├── template.yaml          # SAM template (full import)
│       ├── template-incremental.yaml # SAM template (incremental)
│       ├── samconfig.toml         # Deployment config
│       ├── samconfig-incremental.toml # Incremental deployment config
│       └── package.json           # Dependencies
├── docs/
│   ├── vendor-onboarding-loloi.md # Vendor setup instructions
│   ├── matrixify-results-setup.md # Matrixify configuration
│   └── incremental-import-system.md # Incremental processing documentation
├── scripts/
│   ├── sync-matrixify-results.sh  # Sync Matrixify results to S3
│   ├── get-import-url.sh          # Generate pre-signed URLs
│   ├── deploy-incremental.sh      # Deploy incremental processing system
│   └── test-incremental.sh        # Test incremental processing functionality
├── credentials/                   # Secure credential storage (gitignored)
├── README.md                      # This file
├── INCREMENTAL_IMPORT_SUMMARY.md  # Incremental system summary
└── .gitignore                     # Git ignore rules
```

## 🛠️ Installation & Setup

### Prerequisites

- **AWS CLI** configured with appropriate permissions
- **AWS SAM CLI** installed
- **Node.js** 18.x or later
- **Git** for version control

### Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/valleyridge-inventory-sync.git
   cd valleyridge-inventory-sync
   ```

2. **Install dependencies**:
   ```bash
   cd functions/process-inventory
   npm install
   cd ../..
   ```

3. **Configure credentials**:
   ```bash
   mkdir credentials
   # Add your credential files to the credentials/ directory
   # (These are gitignored for security)
   ```

4. **Deploy the system**:
   ```bash
   # Deploy full import system
   cd functions/process-inventory
   sam deploy --config-file samconfig.toml
   
   # Deploy incremental system (optional)
   sam deploy --config-file samconfig-incremental.toml
   ```

## 🔧 Configuration

### Environment Variables

The system can be configured via environment variables:

- `S3_BUCKET`: S3 bucket name (default: valleyridge-inventory-sync)
- `SUPPORT_EMAIL`: Email for error notifications
- `LOG_LEVEL`: Logging level (INFO, DEBUG, ERROR)

### AWS Permissions

The system requires the following AWS permissions:

- **S3**: Read/Write access to inventory bucket
- **Lambda**: Create/Update/Delete functions
- **CloudWatch**: Logging and metrics
- **IAM**: Role creation and management
- **Transfer Family**: SFTP server management

## 📊 Usage

### Full Import Processing

The system automatically processes Excel files when uploaded to the S3 bucket:

1. Upload Excel file to `s3://valleyridge-inventory-sync/incoming/`
2. Lambda function processes the file
3. CSV file created in `s3://valleyridge-inventory-sync/processed/latest/`
4. Use the CSV file for Matrixify import

### Incremental Processing

For incremental processing (recommended):

1. Deploy incremental system: `./scripts/deploy-incremental.sh`
2. Test the system: `./scripts/test-incremental.sh`
3. Upload files to trigger delta processing
4. Use delta files for faster Matrixify imports

### Manual Operations

Generate pre-signed URL for Matrixify:
```bash
./scripts/get-import-url.sh
```

Sync Matrixify results:
```bash
./scripts/sync-matrixify-results.sh
```

## 📈 Monitoring

### CloudWatch Metrics

The system sends detailed metrics to CloudWatch:

- `FilesProcessed`: Number of files processed
- `RecordsProcessed`: Total records processed
- `DeltaRecordsGenerated`: Number of records in delta files (incremental)
- `ProcessingTime`: Time taken to process files
- `Errors`: Error count by type

### Logs

Monitor CloudWatch logs for:
- Processing errors and warnings
- Change detection results
- Performance metrics
- System health

## 🔒 Security

- **IAM Roles**: Least privilege access
- **SFTP Authentication**: SSH key-based security
- **S3 Policies**: Controlled access to bucket
- **Encryption**: All data encrypted in transit and at rest
- **Credential Management**: Secure storage and rotation

## 🧪 Testing

### Automated Testing

Run the incremental system test:
```bash
./scripts/test-incremental.sh
```

This will:
- Create test Excel files
- Upload them to S3
- Trigger Lambda processing
- Validate delta file generation
- Show CloudWatch logs

### Manual Testing

1. Upload a test Excel file to S3
2. Check CloudWatch logs for processing
3. Verify CSV file generation
4. Test Matrixify import

## 🚀 Deployment

### Production Deployment

1. **Deploy full import system**:
   ```bash
   cd functions/process-inventory
   sam deploy --config-file samconfig.toml
   ```

2. **Deploy incremental system**:
   ```bash
   ./scripts/deploy-incremental.sh
   ```

3. **Configure S3 notifications** (if needed)
4. **Test with sample files**
5. **Monitor performance**

### Staging Deployment

Use the same deployment process but with different stack names and S3 buckets.

## 🔄 Version Control

### Branch Strategy

- `main`: Production-ready code
- `develop`: Development branch
- `feature/*`: Feature branches
- `hotfix/*`: Emergency fixes

### Commit Guidelines

Use conventional commit messages:
- `feat:` New features
- `fix:` Bug fixes
- `docs:` Documentation changes
- `style:` Code style changes
- `refactor:` Code refactoring
- `test:` Test changes
- `chore:` Maintenance tasks

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Add tests if applicable
5. Commit your changes: `git commit -m 'feat: add amazing feature'`
6. Push to the branch: `git push origin feature/amazing-feature`
7. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

For support and questions:

- **Documentation**: Check the `docs/` directory
- **Issues**: Create a GitHub issue
- **Email**: support@valleyridge.ca

## 📊 Status

- **Full Import System**: ✅ Production Ready (available for rollback)
- **Incremental Import System**: ✅ Production Ready (currently active)
- **Vendor SFTP Integration**: ✅ Configured and Active
- **Documentation**: ✅ Complete
- **Testing**: ✅ Automated tests available
- **Monitoring**: ✅ CloudWatch integration

## 🔮 Roadmap

- [ ] Email notifications for processing results
- [ ] Slack integration for alerts
- [ ] Web dashboard for monitoring
- [ ] Multi-vendor support
- [ ] Advanced change analytics
- [ ] Automated baseline management

## 🆕 Recent Updates

### Vendor SFTP Transition (January 2025)
- **Status**: ✅ **Active** - System now processes vendor files via SFTP
- **Change**: S3 notifications updated to use incremental processor
- **Benefits**: 80-95% smaller files, better change tracking, improved performance
- **Vendor**: Loloi now delivers files directly via SFTP instead of Make automation
- **Documentation**: See [CHANGELOG.md](CHANGELOG.md) for detailed change history

---

**Built with ❤️ for Valley Ridge** 