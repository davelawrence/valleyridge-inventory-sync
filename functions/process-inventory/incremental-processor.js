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
 * Main Lambda handler for incremental processing
 * @param {Object} event - S3 event notification
 * @param {Object} context - Lambda context
 */
exports.handler = async (event, context) => {
    const startTime = Date.now();
    const requestId = context.awsRequestId;
    
    console.log(`[${requestId}] Starting incremental inventory processing`);
    console.log(`[${requestId}] Event:`, JSON.stringify(event, null, 2));
    
    try {
        // Process each S3 event
        const results = [];
        for (const record of event.Records) {
            const result = await processS3EventIncremental(record, requestId);
            results.push(result);
        }
        
        const processingTime = Date.now() - startTime;
        console.log(`[${requestId}] Incremental processing completed in ${processingTime}ms`);
        
        // Send metrics to CloudWatch
        await sendMetrics(requestId, results, processingTime);
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                message: 'Incremental processing completed successfully',
                results: results,
                processingTime: processingTime
            })
        };
        
    } catch (error) {
        console.error(`[${requestId}] Error in incremental handler:`, error);
        await sendErrorMetrics(requestId, error);
        await sendErrorNotification(error, requestId);
        throw error;
    }
};

/**
 * Process a single S3 event with incremental logic
 * @param {Object} record - S3 event record
 * @param {string} requestId - Request ID for logging
 */
async function processS3EventIncremental(record, requestId) {
    const bucket = record.s3.bucket.name;
    const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
    
    console.log(`[${requestId}] Processing file incrementally: s3://${bucket}/${key}`);
    
    // Validate file
    if (!isValidFile(key)) {
        throw new Error(`Invalid file type: ${key}. Expected .xls or .xlsx file`);
    }
    
    // Download new file from S3
    const fileData = await downloadFromS3(bucket, key, requestId);
    
    // Process new Excel file
    const newData = await processExcelFile(fileData, requestId);
    
    // Load baseline data (last processed file)
    const baselineData = await loadBaselineData(requestId);
    
    // Compare and generate delta
    const deltaData = await generateDelta(newData, baselineData, requestId);
    
    // Generate CSV for delta
    const csvData = await generateCSV(deltaData, requestId);
    
    // Upload delta file to S3
    const outputKey = generateDeltaOutputKey(key);
    await uploadToS3(csvData, outputKey, requestId);
    
    // Update latest file with full data
    await updateLatestFile(csvData, requestId);
    
    // Save new data as baseline for next comparison
    await saveBaselineData(newData, requestId);
    
    console.log(`[${requestId}] Successfully processed incrementally: ${key} -> ${outputKey}`);
    
    return {
        inputFile: key,
        outputFile: outputKey,
        totalRecords: newData.length,
        deltaRecords: deltaData.length,
        newProducts: deltaData.filter(item => item.changeType === 'new').length,
        updatedProducts: deltaData.filter(item => item.changeType === 'updated').length,
        deletedProducts: deltaData.filter(item => item.changeType === 'deleted').length,
        status: 'success'
    };
}

/**
 * Load baseline data from S3
 * @param {string} requestId - Request ID for logging
 * @returns {Array} - Baseline data or empty array if no baseline exists
 */
async function loadBaselineData(requestId) {
    console.log(`[${requestId}] Loading baseline data`);
    
    try {
        const params = {
            Bucket: S3_BUCKET,
            Key: 'baseline/inventory-baseline.json'
        };
        
        const response = await s3.getObject(params).promise();
        const baselineData = JSON.parse(response.Body.toString());
        
        console.log(`[${requestId}] Loaded baseline with ${baselineData.length} records`);
        return baselineData;
        
    } catch (error) {
        if (error.code === 'NoSuchKey') {
            console.log(`[${requestId}] No baseline found, starting fresh`);
            return [];
        }
        console.error(`[${requestId}] Error loading baseline:`, error);
        throw new Error(`Failed to load baseline: ${error.message}`);
    }
}

/**
 * Save new data as baseline
 * @param {Array} data - New data to save as baseline
 * @param {string} requestId - Request ID for logging
 */
async function saveBaselineData(data, requestId) {
    console.log(`[${requestId}] Saving new baseline data`);
    
    try {
        const params = {
            Bucket: S3_BUCKET,
            Key: 'baseline/inventory-baseline.json',
            Body: JSON.stringify(data, null, 2),
            ContentType: 'application/json',
            Metadata: {
                'processed-by': 'valleyridge-inventory-sync',
                'processed-at': new Date().toISOString(),
                'request-id': requestId,
                'record-count': data.length.toString()
            }
        };
        
        await s3.putObject(params).promise();
        console.log(`[${requestId}] Successfully saved baseline with ${data.length} records`);
        
    } catch (error) {
        console.error(`[${requestId}] Error saving baseline:`, error);
        throw new Error(`Failed to save baseline: ${error.message}`);
    }
}

/**
 * Generate delta data by comparing new data with baseline
 * @param {Array} newData - New inventory data
 * @param {Array} baselineData - Baseline inventory data
 * @param {string} requestId - Request ID for logging
 * @returns {Array} - Delta data with change types
 */
async function generateDelta(newData, baselineData, requestId) {
    console.log(`[${requestId}] Generating delta: ${newData.length} new vs ${baselineData.length} baseline`);
    
    // Create lookup maps for efficient comparison
    const baselineMap = new Map();
    baselineData.forEach(item => {
        baselineMap.set(item['Variant Barcode'], item);
    });
    
    const newDataMap = new Map();
    newData.forEach(item => {
        newDataMap.set(item['Variant Barcode'], item);
    });
    
    const deltaData = [];
    
    // Find new products (in new data but not in baseline)
    for (const [upc, newItem] of newDataMap) {
        if (!baselineMap.has(upc)) {
            deltaData.push({
                ...newItem,
                changeType: 'new',
                changeReason: 'New product'
            });
        }
    }
    
    // Find updated products (in both but with changes)
    for (const [upc, newItem] of newDataMap) {
        const baselineItem = baselineMap.get(upc);
        if (baselineItem && hasChanges(newItem, baselineItem)) {
            deltaData.push({
                ...newItem,
                changeType: 'updated',
                changeReason: getChangeReason(newItem, baselineItem)
            });
        }
    }
    
    // Find deleted products (in baseline but not in new data)
    // Note: This is optional and depends on business requirements
    for (const [upc, baselineItem] of baselineMap) {
        if (!newDataMap.has(upc)) {
            deltaData.push({
                ...baselineItem,
                'Variant Inventory Qty': 0, // Set quantity to 0 for deleted items
                changeType: 'deleted',
                changeReason: 'Product removed from inventory'
            });
        }
    }
    
    console.log(`[${requestId}] Delta generated: ${deltaData.length} changes`);
    console.log(`[${requestId}] - New: ${deltaData.filter(item => item.changeType === 'new').length}`);
    console.log(`[${requestId}] - Updated: ${deltaData.filter(item => item.changeType === 'updated').length}`);
    console.log(`[${requestId}] - Deleted: ${deltaData.filter(item => item.changeType === 'deleted').length}`);
    
    return deltaData;
}

/**
 * Check if two inventory items have changes
 * @param {Object} newItem - New inventory item
 * @param {Object} baselineItem - Baseline inventory item
 * @returns {boolean} - True if there are changes
 */
function hasChanges(newItem, baselineItem) {
    return (
        newItem['Variant Inventory Qty'] !== baselineItem['Variant Inventory Qty'] ||
        newItem['Variant Metafield: custom.internal_discontinued [single_line_text_field]'] !== 
        baselineItem['Variant Metafield: custom.internal_discontinued [single_line_text_field]']
    );
}

/**
 * Get human-readable change reason
 * @param {Object} newItem - New inventory item
 * @param {Object} baselineItem - Baseline inventory item
 * @returns {string} - Change reason
 */
function getChangeReason(newItem, baselineItem) {
    const reasons = [];
    
    if (newItem['Variant Inventory Qty'] !== baselineItem['Variant Inventory Qty']) {
        reasons.push(`Quantity changed from ${baselineItem['Variant Inventory Qty']} to ${newItem['Variant Inventory Qty']}`);
    }
    
    if (newItem['Variant Metafield: custom.internal_discontinued [single_line_text_field]'] !== 
        baselineItem['Variant Metafield: custom.internal_discontinued [single_line_text_field]']) {
        reasons.push('Discontinued status changed');
    }
    
    return reasons.join(', ');
}

/**
 * Generate output key for delta file
 * @param {string} inputKey - Input file key
 * @returns {string} - Output file key
 */
function generateDeltaOutputKey(inputKey) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const baseName = path.basename(inputKey, path.extname(inputKey));
    return `processed/delta/${baseName}-delta-${timestamp}.csv`;
}

// Reuse existing functions from the main processor
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

function validateHeaders(headers, requestId) {
    // Filter out empty headers and normalize
    const normalizedHeaders = headers.filter(h => h && h.trim()).map(h => h.trim());
    
    // Check for required columns with case-insensitive matching
    const requiredColumns = ['UPC', 'Available Qty', 'Discontinued'];
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

function processDataRow(row, headers, rowNumber, requestId) {
    try {
        // Create a proper column mapping that handles missing columns
        const columnMap = {};
        
        for (let i = 0; i < headers.length; i++) {
            const header = headers[i];
            if (header && header.trim()) {
                // Map this header to the actual column index in the original data
                columnMap[header] = i;
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
        const quantity = parseInt(getValue('Available Qty')) || 0;
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
            'Variant Metafield: custom.internal_discontinued [single_line_text_field]': isDiscontinued ? 'Yes' : 'No',
            'Variant Inventory Tracker': 'shopify',
            'Variant Inventory Policy': 'deny'
        };
        
    } catch (error) {
        console.error(`[${requestId}] Error processing row ${rowNumber}:`, error);
        return null;
    }
}

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

async function updateLatestFile(csvData, requestId) {
    console.log(`[${requestId}] Updating latest file`);
    
    try {
        const params = {
            Bucket: S3_BUCKET,
            Key: 'processed/latest/inventory-delta.csv',
            Body: csvData,
            ContentType: 'text/csv',
            Metadata: {
                'processed-by': 'valleyridge-inventory-sync',
                'processed-at': new Date().toISOString(),
                'request-id': requestId
            }
        };
        
        await s3.putObject(params).promise();
        console.log(`[${requestId}] Successfully updated latest delta file`);
        
    } catch (error) {
        console.error(`[${requestId}] Error updating latest file:`, error);
        // Don't throw error for latest file update failure
    }
}

async function sendMetrics(requestId, results, processingTime) {
    try {
        const totalRecords = results.reduce((sum, result) => sum + result.totalRecords, 0);
        const deltaRecords = results.reduce((sum, result) => sum + result.deltaRecords, 0);
        
        const metrics = [
            {
                MetricName: 'FilesProcessed',
                Value: results.length,
                Unit: 'Count',
                Dimensions: [
                    { Name: 'FunctionName', Value: 'valleyridge-process-inventory-incremental' }
                ]
            },
            {
                MetricName: 'TotalRecordsProcessed',
                Value: totalRecords,
                Unit: 'Count',
                Dimensions: [
                    { Name: 'FunctionName', Value: 'valleyridge-process-inventory-incremental' }
                ]
            },
            {
                MetricName: 'DeltaRecordsGenerated',
                Value: deltaRecords,
                Unit: 'Count',
                Dimensions: [
                    { Name: 'FunctionName', Value: 'valleyridge-process-inventory-incremental' }
                ]
            },
            {
                MetricName: 'ProcessingTime',
                Value: processingTime,
                Unit: 'Milliseconds',
                Dimensions: [
                    { Name: 'FunctionName', Value: 'valleyridge-process-inventory-incremental' }
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

async function sendErrorMetrics(requestId, error) {
    try {
        const metrics = [
            {
                MetricName: 'Errors',
                Value: 1,
                Unit: 'Count',
                Dimensions: [
                    { Name: 'FunctionName', Value: 'valleyridge-process-inventory-incremental' },
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

async function sendErrorNotification(error, requestId) {
    // TODO: Implement email notification using SES or SNS
    console.error(`[${requestId}] Error notification should be sent to: ${SUPPORT_EMAIL}`);
    console.error(`[${requestId}] Error details:`, error.message);
} 