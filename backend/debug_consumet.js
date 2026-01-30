const axios = require('axios');

async function test() {
    try {
        const url = 'http://localhost:3002/anime/animeunity/Naruto%20Movie';
        console.log(`Fetching: ${url}`);
        const r = await axios.get(url);
        console.log('--- Results ---');
        r.data.results.forEach(item => {
            console.log(`ID: ${item.id}`);
            console.log(`Title: ${item.title}`);
            console.log('---');
        });
    } catch (e) {
        console.error(e.message);
    }
}

test();
