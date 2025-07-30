#!/bin/bash

# Generate a pre-signed URL for the latest processed CSV file
echo "Generating pre-signed URL for Matrixify import..."
echo ""

# Generate the URL
URL=$(aws s3 presign s3://valleyridge-inventory-sync/processed/latest/data.csv --expires-in 3600)

echo "✅ Pre-signed URL generated successfully!"
echo ""
echo "📋 Copy this URL to Matrixify:"
echo ""
echo "$URL"
echo ""
echo "⏰ This URL will expire in 1 hour"
echo ""
echo "📝 Instructions:"
echo "1. Copy the URL above"
echo "2. In Matrixify, go to Import → Import from URL"
echo "3. Paste the URL and click 'Upload from URL'"
echo "4. Set up your import template and schedule"
echo ""
echo "🔄 To get a new URL, run this script again" 