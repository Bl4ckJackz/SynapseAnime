const axios = require('axios');

async function test() {
    try {
        const id = '3378-fullmetal-alchemist-brotherhood';
        console.log(`Checking episodes for: ${id}`);

        // Use the fixed query param format
        const url = `http://localhost:3002/anime/animeunity/info?id=${encodeURIComponent(id)}`;
        const r = await axios.get(url);

        console.log('Success!');
        if (r.data.episodes && r.data.episodes.length > 0) {
            console.log('First 3 Episode IDs:');
            r.data.episodes.slice(0, 3).forEach(ep => {
                console.log(`Ep ${ep.number}: ${ep.id}`);
            });
        } else {
            console.log('No episodes found.');
        }
    } catch (e) {
        console.error('Error:', e.message);
        if (e.response) console.error('Data:', e.response.data);
    }
}

test();
