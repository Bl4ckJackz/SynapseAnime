const axios = require('axios');

async function test() {
    try {
        const episodeId = '3378-fullmetal-alchemist-brotherhood/1';
        const url = `http://localhost:3002/anime/animeunity/watch/${encodeURIComponent(episodeId)}`;
        console.log(`Fetching: ${url}`);

        const r = await axios.get(url);
        console.log('Status:', r.status);
        console.log('Data:', JSON.stringify(r.data, null, 2));
    } catch (e) {
        console.error('Error:', e.message);
        if (e.response) {
            console.error('Response data:', e.response.data);
        }
    }
}

test();
