
import axios from 'axios';
import { load } from 'cheerio';

const baseUrl = 'https://www.mangaworld.mx';

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

        const $ = load(data);
        const results = [];

        console.log('HTML Loaded. Parsing entries...');

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
    }
}

search('86');
