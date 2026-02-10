const axios = require('axios');

const API_KEY = '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';
const API_URL = 'https://api.perplexity.ai/chat/completions';

async function testPerplexity() {
    try {
        console.log('Testing Perplexity API...');
        const response = await axios.post(
            API_URL,
            {
                model: 'sonar',
                messages: [{ role: 'user', content: 'Say hello!' }],
                temperature: 0.7,
            },
            {
                headers: {
                    Authorization: `Bearer ${API_KEY}`,
                    'Content-Type': 'application/json',
                },
            }
        );
        console.log('Response:', response.data);
    } catch (error) {
        console.error('Error:', error.response ? error.response.data : error.message);
    }
}

testPerplexity();
