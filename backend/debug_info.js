const axios = require('axios');

async function test() {
    try {
        const animeId = '3378-fullmetal-alchemist-brotherhood';
        // Note: AnimeUnity provider uses query param for ID in info
        const url = `http://localhost:3002/anime/animeunity/info?id=${encodeURIComponent(animeId)}`;
        console.log(`Fetching: ${url}`);

        const r = await axios.get(url);
        console.log('Status:', r.status);
        if (r.data.episodes && r.data.episodes.length > 0) {
            console.log('First 3 episodes:');
            r.data.episodes.slice(0, 3).forEach(ep => {
                console.log(`Ep ${ep.number}: ID="${ep.id}"`);
            });
        } else {
            console.log('No episodes found');
        }
    } catch (e) {
        console.error('Error:', e.message);
        if (e.response) {
            console.error('Response data:', e.response.data);
        }
    }
}

test();
