// Simulate the exact data structure from the file
const headers = ["Item ID", "In Stock", "Available Qty", "", "UPC", "Discontinued", "ETA"];
const row = ["AAK1GLOBTXGO00Z093", "N", 0, "", "X00000014816", "N", "2026-01-27"];

console.log("=== ORIGINAL DATA ===");
console.log("Headers:", headers);
console.log("Row:", row);

// Simulate the FIXED column mapping logic
const columnMap = {};

for (let i = 0; i < headers.length; i++) {
    const header = headers[i];
    if (header && header.trim()) {
        // Map this header to the actual column index in the original data
        columnMap[header] = i;
    }
}

console.log("\n=== FIXED COLUMN MAPPING ===");
console.log("Column map:", columnMap);

// Test getting values
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

console.log("\n=== TESTING VALUES ===");
console.log("UPC:", getValue('UPC'));
console.log("Available QTY:", getValue('Available QTY'));
console.log("Discontinued:", getValue('Discontinued'));

// Show the fix
console.log("\n=== THE FIX ===");
console.log("Headers (filtered):", headers.filter(h => h && h.trim()));
console.log("Row data (original):", row);
console.log("UPC should be at index 4 in original row:", row[4]);
console.log("Column map now says UPC is at index:", columnMap['UPC']);
console.log("UPC value retrieved:", getValue('UPC')); 