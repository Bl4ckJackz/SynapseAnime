import axios from 'axios';

const TEST_PROVIDERS = [
    { name: 'MangaWorld', url: 'http://localhost:3000/manga/mangaworld', query: 'one piece' },
    { name: 'MangaKatana', url: 'http://localhost:3000/manga/mangakatana', query: 'one piece' },
    { name: 'MangaSee', url: 'http://localhost:3000/manga/mangasee', query: 'one piece' },
];

async function test(port: number = 3000) {
    console.log(`Running tests on port ${port}...`);

    for (const provider of TEST_PROVIDERS) {
        try {
            const baseUrl = provider.url.replace('3000', port.toString());
            console.log(`\nTesting ${provider.name}...`);

            // 1. Search
            console.log(`  Searching for "${provider.query}"...`);
            const searchUrl = `${baseUrl}/${encodeURIComponent(provider.query)}`;
            const searchRes = await axios.get(searchUrl);
            const searchResults = searchRes.data.results;

            if (searchResults.length === 0) {
                console.error(`  FAIL: No results found for ${provider.name}`);
                continue;
            }
            console.log(`  PASS: Found ${searchResults.length} results.`);

            const firstManga = searchResults[0];
            console.log(`  Using first result: ${firstManga.title} (${firstManga.id})`);

            // 2. Info
            console.log(`  Fetching info for ${firstManga.id}...`);
            const infoUrl = `${baseUrl}/info?id=${encodeURIComponent(firstManga.id)}`;
            const infoRes = await axios.get(infoUrl);
            const infoData = infoRes.data;

            if (!infoData.chapters || infoData.chapters.length === 0) {
                console.error(`  FAIL: No chapters found for ${provider.name}`);
                continue;
            }
            console.log(`  PASS: Found ${infoData.chapters.length} chapters.`);

            // 3. Verify Order
            const firstCh = infoData.chapters[0].chapterNumber;
            const lastCh = infoData.chapters[infoData.chapters.length - 1].chapterNumber;
            console.log(`  Order check: First Ch=${firstCh}, Last Ch=${lastCh}`);

            if (firstCh > lastCh) {
                console.log(`  PASS: Chapters appear to be descending (Newest first).`);
            } else {
                console.log(`  WARN: Chapters appear to be ascending (Oldest first). User requested descending?`);
            }

        } catch (e: any) {
            console.error(`  ERROR testing ${provider.name}: ${e.message}`);
            if (e.response) {
                console.error(`  Response status: ${e.response.status}`);
                console.error(`  Response data:`, e.response.data);
            }
        }
    }
}

// Check args for port
const portArg = process.argv.find(arg => arg.startsWith('--port='));
const port = portArg ? parseInt(portArg.split('=')[1]) : 3000;

test(port);
