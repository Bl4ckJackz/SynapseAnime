const axios = require('axios');

async function test() {
    try {
        console.log('--- NARUTO ---');
        const r1 = await axios.get('http://localhost:3002/anime/animeunity/naruto');
        r1.data.results.forEach(r => console.log(`${r.title}: ${r.id}`));

        console.log('\n--- FMA ---');
        const r2 = await axios.get('http://localhost:3002/anime/animeunity/Fullmetal%20Alchemist%3A%20Brotherhood');
        r2.data.results.forEach(r => console.log(`${r.title}: ${r.id}`));
    } catch (e) {
        console.error(e.message);
    }
}

test();
