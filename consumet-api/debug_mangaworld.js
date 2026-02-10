
const axios = require('axios');
const cheerio = require('cheerio');
const fs = require('fs');

const baseUrl = 'https://www.mangaworld.ac';

async function search(query) {
    console.log(`Searching for "${query}" on ${baseUrl}...`);
    try {
        const url = `${baseUrl}/archive?keyword=${encodeURIComponent(query)}`;
        console.log(`URL: ${url}`);

        const { data } = await axios.get(url, {
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            }
        });

        // Save HTML for inspection
        fs.writeFileSync('debug_mangaworld.html', data);
        console.log('HTML saved to debug_mangaworld.html');
        console.log('HTML Snippet:', data.substring(0, 500));

        const $ = cheerio.load(data);
        const results = [];

        console.log('HTML Loaded. Parsing entries...');
        console.log('Number of .entry elements:', $('div.entry').length);
        console.log('Number of .comic-search-result elements:', $('.comic-search-result').length);

        $('div.entry').each((i, el) => {
            const entryUrl = $(el).find('a').attr('href');
            const title = $(el).find('a').attr('title');

            console.log(`Found entry: ${title} (${entryUrl})`);

            if (entryUrl && title) {
                results.push({
                    title: title.trim(),
                    url: entryUrl
                });
            }
        });

        console.log(`Total Found: ${results.length}`);
        return results;
    } catch (err) {
        console.error('Error:', err.message);
        if (err.response) {
            console.error('Status:', err.response.status);
            if (err.response.data) {
                fs.writeFileSync('debug_error.html', err.response.data);
                console.log('Error HTML saved to debug_error.html');
            }
        }
    }
}

search('86');
