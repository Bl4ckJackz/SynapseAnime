
const fs = require('fs');
const cheerio = require('cheerio');

const html = fs.readFileSync('c:\\Users\\domin\\debug_au.html', 'utf8');
const $ = cheerio.load(html);

const layoutItems = $('layout-items');
console.log(`Found ${layoutItems.length} layout-items elements.`);

layoutItems.each((i, el) => {
    const attr = $(el).attr('items-json');
    console.log(`Element ${i} items-json length: ${attr ? attr.length : 'null'}`);
    if (attr) {
        try {
            const jsonStr = attr.replace(/&quot;/g, '"');
            const data = JSON.parse(jsonStr);
            console.log(`Element ${i} parsed JSON keys:`, Object.keys(data));
            if (data.data && Array.isArray(data.data)) {
                console.log(`Element ${i} contains ${data.data.length} items in 'data'.`);
                console.log('First item sample:', JSON.stringify(data.data[0], null, 2));
            }
        } catch (e) {
            console.error(`Element ${i} JSON parse error:`, e.message);
        }
    }
});
