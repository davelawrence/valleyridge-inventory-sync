const AWS = require('aws-sdk');
const XLSX = require('xlsx');

const s3 = new AWS.S3();

async function analyzeLatestFile() {
    try {
        console.log('Downloading latest file from S3...');
        const params = {
            Bucket: 'valleyridge-inventory-sync',
            Key: 'incoming/outlook_email_attachment.xlsx'
        };
        
        const response = await s3.getObject(params).promise();
        console.log('File downloaded successfully');
        
        // Parse Excel file
        const workbook = XLSX.read(response.Body, { type: 'buffer' });
        const sheetName = workbook.SheetNames[0];
        const worksheet = workbook.Sheets[sheetName];
        
        // Convert to JSON
        const data = XLSX.utils.sheet_to_json(worksheet, { header: 1 });
        
        console.log('\n=== LATEST FILE ANALYSIS ===');
        console.log(`Sheet name: ${sheetName}`);
        console.log(`Total rows: ${data.length}`);
        
        // Show headers (first row)
        if (data.length > 0) {
            console.log('\n=== HEADERS ===');
            const headers = data[0];
            headers.forEach((header, index) => {
                console.log(`${index}: "${header}"`);
            });
        }
        
        // Show first few data rows
        if (data.length > 1) {
            console.log('\n=== FIRST 3 DATA ROWS ===');
            for (let i = 1; i <= Math.min(3, data.length - 1); i++) {
                console.log(`Row ${i}:`, data[i]);
            }
        }
        
        // Look for UPC column
        if (data.length > 0) {
            const headers = data[0];
            const upcIndex = headers.findIndex(h => 
                h && h.toString().toLowerCase().includes('upc') || 
                h && h.toString().toLowerCase().includes('barcode')
            );
            
            if (upcIndex >= 0) {
                console.log(`\n=== UPC COLUMN FOUND ===`);
                console.log(`Column index: ${upcIndex}`);
                console.log(`Column name: "${headers[upcIndex]}"`);
                
                // Check first few UPC values
                console.log('\n=== FIRST 5 UPC VALUES ===');
                for (let i = 1; i <= Math.min(5, data.length - 1); i++) {
                    const upcValue = data[i][upcIndex];
                    console.log(`Row ${i}: "${upcValue}" (type: ${typeof upcValue})`);
                }
            } else {
                console.log('\n=== NO UPC COLUMN FOUND ===');
                console.log('Available columns:');
                headers.forEach((header, index) => {
                    if (header) {
                        console.log(`  ${index}: "${header}"`);
                    }
                });
            }
        }
        
    } catch (error) {
        console.error('Error analyzing file:', error);
    }
}

analyzeLatestFile(); 