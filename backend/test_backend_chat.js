
const axios = require('axios');

const API_URL = 'http://localhost:3005';

async function testBackendChat() {
    const username = `testuser_${Date.now()}`;
    const email = `${username}@example.com`;
    const password = 'password123';

    console.log(`1. Registering user: ${username}...`);
    try {
        await axios.post(`${API_URL}/auth/register`, {
            nickname: username,
            email,
            password,
        });
        console.log('   Registration successful.');
    } catch (error) {
        console.error('   Registration failed:', error.response?.data || error.message);
        return;
    }

    console.log('2. Logging in...');
    let token;
    try {
        const response = await axios.post(`${API_URL}/auth/login`, {
            email,
            password,
        });
        token = response.data.access_token;
        console.log('   Login successful. Token obtained.');
    } catch (error) {
        console.error('   Login failed:', error.response?.data || error.message);
        return;
    }

    console.log('3. Sending Chat Request...');
    try {
        const response = await axios.post(
            `${API_URL}/ai/chat`,
            {
                messages: [
                    { role: 'user', content: 'Ciao! Consigliami un anime simile a Death Note.' }
                ]
            },
            {
                headers: {
                    Authorization: `Bearer ${token}`,
                },
            }
        );

        console.log('   Chat Response Received:');
        console.log('---------------------------------------------------');
        console.log(response.data);
        console.log('---------------------------------------------------');
        console.log('TEST PASSED: Backend AI Chat is working!');

    } catch (error) {
        console.error('   Chat Request failed:', error.response?.data || error.message);
        if (error.response?.data?.message) {
            console.error('   Error Message:', error.response.data.message);
        }
    }
}

testBackendChat();
