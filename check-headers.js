const XLSX = require('xlsx');

// Read the Excel file
const workbook = XLSX.readFile('./outlook_email_attachment (1)');

// Get the first sheet
const sheetName = workbook.SheetNames[0];
const worksheet = workbook.Sheets[sheetName];

// Convert to JSON to see the structure
const jsonData = XLSX.utils.sheet_to_json(worksheet, { header: 1 });

// Get headers (first row)
const headers = jsonData[0];

console.log('Excel file headers:');
console.log('==================');
headers.forEach((header, index) => {
    console.log(`${index}: "${header}"`);
});

console.log('\nFirst few data rows:');
console.log('====================');
for (let i = 1; i < Math.min(5, jsonData.length); i++) {
    console.log(`Row ${i}:`, jsonData[i]);
}

// Check for UPC-related columns
console.log('\nUPC-related columns:');
console.log('===================');
headers.forEach((header, index) => {
    if (header && header.toLowerCase().includes('upc')) {
        console.log(`${index}: "${header}"`);
    }
});

// Check for quantity-related columns
console.log('\nQuantity-related columns:');
console.log('========================');
headers.forEach((header, index) => {
    if (header && (header.toLowerCase().includes('qty') || header.toLowerCase().includes('quantity'))) {
        console.log(`${index}: "${header}"`);
    }
}); 