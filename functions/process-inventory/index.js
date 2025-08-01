const AWS = require('aws-sdk');
const XLSX = require('xlsx');
const createCsvWriter = require('csv-writer').createObjectCsvWriter;
const fs = require('fs');
const path = require('path');

// Configure AWS SDK
const s3 = new AWS.S3();
const cloudwatch = new AWS.CloudWatch();

// Environment variables
const S3_BUCKET = process.env.S3_BUCKET || 'valleyridge-inventory-sync';
const SUPPORT_EMAIL = process.env.SUPPORT_EMAIL || 'support@valleyridge.ca';
const LOG_LEVEL = process.env.LOG_LEVEL || 'INFO';

/**
 * Main Lambda handler function
 * @param {Object} event - S3 event notification
 * @param {Object} context - Lambda context
 */
exports.handler = async (event, context) => {
    const startTime = Date.now();
    const requestId = context.awsRequestId;
    
    console.log(`[${requestId}] Starting inventory processing`);
    console.log(`[${requestId}] Event:`, JSON.stringify(event, null, 2));
    
    try {
        // Process each S3 event
        const results = [];
        for (const record of event.Records) {
            const result = await processS3Event(record, requestId);
            results.push(result);
        }
        
        const processingTime = Date.now() - startTime;
        console.log(`[${requestId}] Processing completed in ${processingTime}ms`);
        
        // Send metrics to CloudWatch
        await sendMetrics(requestId, results, processingTime);
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                message: 'Processing completed successfully',
                results: results,
                processingTime: processingTime
            })
        };
        
    } catch (error) {
        console.error(`[${requestId}] Error in main handler:`, error);
        
        // Send error metrics
        await sendErrorMetrics(requestId, error);
        
        // Send notification to support team
        await sendErrorNotification(error, requestId);
        
        throw error;
    }
};

/**
 * Process a single S3 event
 * @param {Object} record - S3 event record
 * @param {string} requestId - Request ID for logging
 */
async function processS3Event(record, requestId) {
    const bucket = record.s3.bucket.name;
    const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
    
    console.log(`[${requestId}] Processing file: s3://${bucket}/${key}`);
    
    // Validate file
    if (!isValidFile(key)) {
        throw new Error(`Invalid file type: ${key}. Expected .xls or .xlsx file`);
    }
    
    // Download file from S3
    const fileData = await downloadFromS3(bucket, key, requestId);
    
    // Process Excel file
    const processedData = await processExcelFile(fileData, requestId);
    
    // Generate CSV
    const csvData = await generateCSV(processedData, requestId);
    
    // Upload processed file to S3
    const outputKey = generateOutputKey(key);
    await uploadToS3(csvData, outputKey, requestId);
    
    // Update latest file
    await updateLatestFile(csvData, requestId);
    
    console.log(`[${requestId}] Successfully processed: ${key} -> ${outputKey}`);
    
    return {
        inputFile: key,
        outputFile: outputKey,
        recordsProcessed: processedData.length,
        status: 'success'
    };
}

/**
 * Validate if file is a supported Excel format
 * @param {string} key - S3 object key
 * @returns {boolean} - True if valid
 */
function isValidFile(key) {
    const validExtensions = ['.xls', '.xlsx'];
    const extension = path.extname(key).toLowerCase();
    
    // Accept files with valid extensions
    if (validExtensions.includes(extension)) {
        return true;
    }
    
    // Also accept files without extensions (they will be validated as Excel files during processing)
    if (!extension || extension === '') {
        return true;
    }
    
    return false;
}

/**
 * Download file from S3
 * @param {string} bucket - S3 bucket name
 * @param {string} key - S3 object key
 * @param {string} requestId - Request ID for logging
 * @returns {Buffer} - File data
 */
async function downloadFromS3(bucket, key, requestId) {
    console.log(`[${requestId}] Downloading file from S3: s3://${bucket}/${key}`);
    
    try {
        const params = {
            Bucket: bucket,
            Key: key
        };
        
        const response = await s3.getObject(params).promise();
        console.log(`[${requestId}] Downloaded ${response.Body.length} bytes`);
        
        return response.Body;
        
    } catch (error) {
        console.error(`[${requestId}] Error downloading from S3:`, error);
        throw new Error(`Failed to download file from S3: ${error.message}`);
    }
}

/**
 * Process Excel file and extract inventory data
 * @param {Buffer} fileData - Excel file data
 * @param {string} requestId - Request ID for logging
 * @returns {Array} - Processed inventory data
 */
async function processExcelFile(fileData, requestId) {
    console.log(`[${requestId}] Processing Excel file`);
    
    try {
        // Read Excel file
        const workbook = XLSX.read(fileData, { type: 'buffer' });
        
        // Get first sheet
        const sheetName = workbook.SheetNames[0];
        const worksheet = workbook.Sheets[sheetName];
        
        console.log(`[${requestId}] Processing sheet: ${sheetName}`);
        
        // Convert to JSON
        const rawData = XLSX.utils.sheet_to_json(worksheet, { header: 1 });
        
        if (rawData.length < 2) {
            throw new Error('Excel file must contain at least a header row and one data row');
        }
        
        // Extract headers and data
        const headers = rawData[0];
        const dataRows = rawData.slice(1);
        
        console.log(`[${requestId}] Found ${dataRows.length} data rows`);
        console.log(`[${requestId}] Headers:`, headers);
        
        // Validate required columns
        validateHeaders(headers, requestId);
        
        // Process data rows
        const processedData = dataRows
            .filter(row => row.length > 0) // Remove empty rows
            .map((row, index) => processDataRow(row, headers, index + 2, requestId))
            .filter(item => item !== null); // Remove invalid rows
        
        console.log(`[${requestId}] Processed ${processedData.length} valid rows`);
        
        return processedData;
        
    } catch (error) {
        console.error(`[${requestId}] Error processing Excel file:`, error);
        throw new Error(`Failed to process Excel file: ${error.message}`);
    }
}

/**
 * Validate that required columns are present
 * @param {Array} headers - Column headers
 * @param {string} requestId - Request ID for logging
 */
function validateHeaders(headers, requestId) {
    // Filter out empty headers and normalize
    const normalizedHeaders = headers.filter(h => h && h.trim()).map(h => h.trim());
    
    // Check for required columns with case-insensitive matching
    const requiredColumns = ['UPC', 'Available QTY', 'Discontinued'];
    const missingColumns = [];
    
    for (const requiredCol of requiredColumns) {
        const found = normalizedHeaders.some(header => 
            header.toLowerCase() === requiredCol.toLowerCase()
        );
        if (!found) {
            missingColumns.push(requiredCol);
        }
    }
    
    if (missingColumns.length > 0) {
        throw new Error(`Missing required columns: ${missingColumns.join(', ')}`);
    }
    
    console.log(`[${requestId}] All required columns found`);
    console.log(`[${requestId}] Headers: ${JSON.stringify(normalizedHeaders)}`);
}

/**
 * Process a single data row
 * @param {Array} row - Data row
 * @param {Array} headers - Column headers
 * @param {number} rowNumber - Row number for error reporting
 * @param {string} requestId - Request ID for logging
 * @returns {Object|null} - Processed row or null if invalid
 */
function processDataRow(row, headers, rowNumber, requestId) {
    try {
        // Create a proper column mapping that handles missing columns
        const columnMap = {};
        let dataIndex = 0;
        
        for (let i = 0; i < headers.length; i++) {
            const header = headers[i];
            if (header && header.trim()) {
                // Map this header to the current data index
                columnMap[header] = dataIndex;
                dataIndex++;
            }
        }
        
        // Helper function to get value by case-insensitive key
        const getValue = (key) => {
            const foundKey = Object.keys(columnMap).find(k => 
                k && k.toLowerCase() === key.toLowerCase()
            );
            if (foundKey) {
                const dataIndex = columnMap[foundKey];
                return row[dataIndex] || '';
            }
            return '';
        };
        
        // Validate UPC
        const upc = String(getValue('UPC')).trim();
        if (!upc || upc === '') {
            console.warn(`[${requestId}] Row ${rowNumber}: Empty UPC, skipping`);
            return null;
        }
        
        // Validate quantity
        const quantity = parseInt(getValue('Available QTY')) || 0;
        if (quantity < 0) {
            console.warn(`[${requestId}] Row ${rowNumber}: Negative quantity for UPC ${upc}, setting to 0`);
        }
        
        // Process discontinued status
        const discontinued = String(getValue('Discontinued')).toLowerCase().trim();
        const isDiscontinued = discontinued === 'yes' || discontinued === '1' || discontinued === 'true';
        
        // Transform data for Matrixify
        return {
            'Variant Barcode': upc,
            'Variant Inventory Qty': quantity,
            'Variant Metafield: custom.internal_discontinued [single_line_text_field]': isDiscontinued ? 'Yes' : 'No'
        };
        
    } catch (error) {
        console.error(`[${requestId}] Error processing row ${rowNumber}:`, error);
        return null;
    }
}

/**
 * Generate CSV from processed data
 * @param {Array} data - Processed inventory data
 * @param {string} requestId - Request ID for logging
 * @returns {string} - CSV data
 */
async function generateCSV(data, requestId) {
    console.log(`[${requestId}] Generating CSV with ${data.length} rows`);
    
    try {
        if (data.length === 0) {
            throw new Error('No valid data to process');
        }
        
        // Get headers from first row
        const headers = Object.keys(data[0]);
        
        // Create CSV writer
        const csvWriter = createCsvWriter({
            path: '/tmp/inventory.csv',
            header: headers.map(header => ({ id: header, title: header }))
        });
        
        // Write CSV to temp file
        await csvWriter.writeRecords(data);
        
        // Read the generated CSV
        const csvData = fs.readFileSync('/tmp/inventory.csv', 'utf8');
        
        console.log(`[${requestId}] Generated CSV with ${csvData.length} characters`);
        
        return csvData;
        
    } catch (error) {
        console.error(`[${requestId}] Error generating CSV:`, error);
        throw new Error(`Failed to generate CSV: ${error.message}`);
    }
}

/**
 * Generate output key for processed file
 * @param {string} inputKey - Input file key
 * @returns {string} - Output file key
 */
function generateOutputKey(inputKey) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const baseName = path.basename(inputKey, path.extname(inputKey));
    return `processed/${baseName}-${timestamp}.csv`;
}

/**
 * Upload processed file to S3
 * @param {string} csvData - CSV data
 * @param {string} key - S3 object key
 * @param {string} requestId - Request ID for logging
 */
async function uploadToS3(csvData, key, requestId) {
    console.log(`[${requestId}] Uploading to S3: s3://${S3_BUCKET}/${key}`);
    
    try {
        const params = {
            Bucket: S3_BUCKET,
            Key: key,
            Body: csvData,
            ContentType: 'text/csv',
            Metadata: {
                'processed-by': 'valleyridge-inventory-sync',
                'processed-at': new Date().toISOString(),
                'request-id': requestId
            }
        };
        
        await s3.putObject(params).promise();
        console.log(`[${requestId}] Successfully uploaded to S3`);
        
    } catch (error) {
        console.error(`[${requestId}] Error uploading to S3:`, error);
        throw new Error(`Failed to upload to S3: ${error.message}`);
    }
}

/**
 * Update the latest processed file
 * @param {string} csvData - CSV data
 * @param {string} requestId - Request ID for logging
 */
async function updateLatestFile(csvData, requestId) {
    console.log(`[${requestId}] Updating latest file`);
    
    try {
        const params = {
            Bucket: S3_BUCKET,
            Key: 'processed/latest/inventory.csv',
            Body: csvData,
            ContentType: 'text/csv',
            Metadata: {
                'processed-by': 'valleyridge-inventory-sync',
                'processed-at': new Date().toISOString(),
                'request-id': requestId
            }
        };
        
        await s3.putObject(params).promise();
        console.log(`[${requestId}] Successfully updated latest file`);
        
    } catch (error) {
        console.error(`[${requestId}] Error updating latest file:`, error);
        // Don't throw error for latest file update failure
    }
}

/**
 * Send metrics to CloudWatch
 * @param {string} requestId - Request ID
 * @param {Array} results - Processing results
 * @param {number} processingTime - Processing time in ms
 */
async function sendMetrics(requestId, results, processingTime) {
    try {
        const totalRecords = results.reduce((sum, result) => sum + result.recordsProcessed, 0);
        
        const metrics = [
            {
                MetricName: 'FilesProcessed',
                Value: results.length,
                Unit: 'Count',
                Dimensions: [
                    { Name: 'FunctionName', Value: 'valleyridge-process-inventory' }
                ]
            },
            {
                MetricName: 'RecordsProcessed',
                Value: totalRecords,
                Unit: 'Count',
                Dimensions: [
                    { Name: 'FunctionName', Value: 'valleyridge-process-inventory' }
                ]
            },
            {
                MetricName: 'ProcessingTime',
                Value: processingTime,
                Unit: 'Milliseconds',
                Dimensions: [
                    { Name: 'FunctionName', Value: 'valleyridge-process-inventory' }
                ]
            }
        ];
        
        await cloudwatch.putMetricData({
            Namespace: 'ValleyRidge/InventorySync',
            MetricData: metrics
        }).promise();
        
        console.log(`[${requestId}] Metrics sent to CloudWatch`);
        
    } catch (error) {
        console.error(`[${requestId}] Error sending metrics:`, error);
        // Don't throw error for metrics failure
    }
}

/**
 * Send error metrics to CloudWatch
 * @param {string} requestId - Request ID
 * @param {Error} error - Error object
 */
async function sendErrorMetrics(requestId, error) {
    try {
        const metrics = [
            {
                MetricName: 'Errors',
                Value: 1,
                Unit: 'Count',
                Dimensions: [
                    { Name: 'FunctionName', Value: 'valleyridge-process-inventory' },
                    { Name: 'ErrorType', Value: error.name || 'Unknown' }
                ]
            }
        ];
        
        await cloudwatch.putMetricData({
            Namespace: 'ValleyRidge/InventorySync',
            MetricData: metrics
        }).promise();
        
    } catch (metricError) {
        console.error(`[${requestId}] Error sending error metrics:`, metricError);
    }
}

/**
 * Send error notification to support team
 * @param {Error} error - Error object
 * @param {string} requestId - Request ID
 */
async function sendErrorNotification(error, requestId) {
    // TODO: Implement email notification using SES or SNS
    console.error(`[${requestId}] Error notification should be sent to: ${SUPPORT_EMAIL}`);
    console.error(`[${requestId}] Error details:`, error.message);
} 