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

console.log('Excel file analysis:');
console.log('===================');
console.log(`Total rows: ${jsonData.length}`);
console.log(`Total columns: ${headers.length}`);

console.log('\nHeaders with indices:');
console.log('=====================');
headers.forEach((header, index) => {
    console.log(`${index}: "${header}"`);
});

console.log('\nDetailed first 5 rows:');
console.log('=====================');
for (let i = 1; i < Math.min(6, jsonData.length); i++) {
    console.log(`Row ${i}:`);
    const row = jsonData[i];
    row.forEach((cell, index) => {
        console.log(`  ${index}: "${cell}" (type: ${typeof cell})`);
    });
    console.log('');
}

// Check for the specific columns we need
console.log('\nColumn mapping analysis:');
console.log('========================');
const upcIndex = headers.findIndex(h => h && h.toLowerCase() === 'upc');
const qtyIndex = headers.findIndex(h => h && h.toLowerCase() === 'available qty');
const discontinuedIndex = headers.findIndex(h => h && h.toLowerCase() === 'discontinued');

console.log(`UPC column index: ${upcIndex} (${upcIndex >= 0 ? headers[upcIndex] : 'NOT FOUND'})`);
console.log(`Available Qty column index: ${qtyIndex} (${qtyIndex >= 0 ? headers[qtyIndex] : 'NOT FOUND'})`);
console.log(`Discontinued column index: ${discontinuedIndex} (${discontinuedIndex >= 0 ? headers[discontinuedIndex] : 'NOT FOUND'})`);

// Check a few sample rows for these columns
console.log('\nSample data from required columns:');
console.log('==================================');
for (let i = 1; i < Math.min(6, jsonData.length); i++) {
    const row = jsonData[i];
    console.log(`Row ${i}:`);
    if (upcIndex >= 0) console.log(`  UPC: "${row[upcIndex]}"`);
    if (qtyIndex >= 0) console.log(`  Available Qty: "${row[qtyIndex]}"`);
    if (discontinuedIndex >= 0) console.log(`  Discontinued: "${row[discontinuedIndex]}"`);
    console.log('');
} 