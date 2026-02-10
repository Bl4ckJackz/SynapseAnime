
const axios = require('axios');

async function checkApi() {
    try {
        console.log('Fetching recent episodes from localhost:3004...');
        const response = await axios.get('http://localhost:3004/anime/animeunity/recent-episodes');
        console.log('Status:', response.status);
        console.log('Data keys:', Object.keys(response.data));
        if (response.data.results) {
            console.log('Results count:', response.data.results.length);
            if (response.data.results.length > 0) {
                console.log('First result:', response.data.results[0]);
            }
        } else {
            console.log('No results field found. Full Data:', JSON.stringify(response.data, null, 2));
        }
    } catch (error) {
        console.error('Error fetching API:', error.message);
        if (error.response) {
            console.error('Response status:', error.response.status);
            console.error('Response data:', error.response.data);
        }
    }
}

checkApi();
