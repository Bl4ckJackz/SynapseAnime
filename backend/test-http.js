const http = require('http');

const options = {
  host: 'localhost',
  port: 3000,
  path: '/',
  method: 'GET',
  timeout: 10000
};

const req = http.request(options, (res) => {
  console.log(`Status Code: ${res.statusCode}`);
  res.on('data', (chunk) => {
    console.log('Response body:', chunk.toString());
  });
  res.on('end', () => {
    console.log('Request completed');
  });
});

req.on('error', (error) => {
  console.error('Error:', error.message);
});

req.on('timeout', () => {
  console.log('Request timed out');
  req.destroy();
});

req.end();