
import MangaWorld from './src/providers/mangaworld';
import MangaKatana from './src/providers/mangakatana';
import MangaSee from './src/providers/mangasee';

async function test(providerName: string, query: string) {
    let provider;
    if (providerName === 'MangaWorld') provider = new MangaWorld();
    if (providerName === 'MangaKatana') provider = new MangaKatana();
    if (providerName === 'MangaSee') provider = new MangaSee();

    if (!provider) return;

    console.log(`\n--- Testing ${providerName} ---`);
    console.log(`Searching for "${query}"...`);
    try {
        const searchRes = await provider.search(query);
        console.log(`Found ${searchRes.results.length} results.`);
        if (searchRes.results.length > 0) {
            const first = searchRes.results[0];
            console.log(`First result: ${first.title} (ID: ${first.id})`);

            console.log(`Fetching info for ID: ${first.id}...`);
            const info = await provider.fetchMangaInfo(first.id);
            console.log(`Successfully fetched info! Title: ${info.title}, Chapters: ${info.chapters?.length}`);
        } else {
            console.log('No results found.');
        }
    } catch (e) {
        console.error(`Error in ${providerName}:`, e);
    }
}

async function run() {
    // MangaWorld is verified, skipping or keeping for consistency
    // await test('MangaWorld', 'Tokyo Ghoul'); 
    await test('MangaKatana', 'Tokyo Ghoul');
    await test('MangaSee', 'Tokyo Ghoul');
}

run();
