const axios = require('axios');
const fs = require('fs');

async function fetchAU() {
    try {
        const response = await axios.get('https://www.animeunity.so', {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
            }
        });
        fs.writeFileSync('c:\\Users\\domin\\debug_au.html', response.data);
        console.log('Successfully saved to c:\\Users\\domin\\debug_au.html');
    } catch (error) {
        console.error('Error fetching:', error.message);
    }
}

fetchAU();
