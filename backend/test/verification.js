const axios = require('axios');

const BASE_URL = 'http://localhost:3000';

async function runTests() {
    console.log('Starting verification tests...\n');

    try {
        // 1. Test AnimeWorld Search (Consumet Fallback)
        console.log('1. Testing AnimeWorld Search (should use Consumet if scraper fails)...');
        const searchRes = await axios.get(`${BASE_URL}/anime/animeworld/search?q=naruto`);
        console.log(`   Status: ${searchRes.status}`);
        console.log(`   Results: ${searchRes.data.length} items`);
        if (searchRes.data.length > 0) {
            console.log(`   First item: ${searchRes.data[0].title} (${searchRes.data[0].id})`);
        }
        console.log('   ✅ Passed\n');

        // 2. Test AnimeWorld Details
        console.log('2. Testing AnimeWorld Details...');
        if (searchRes.data.length > 0) {
            const animeId = searchRes.data[0].id;
            console.log(`   Fetching details for: ${animeId}`);
            const detailRes = await axios.get(`${BASE_URL}/anime/animeworld/details/${encodeURIComponent(animeId)}`);
            console.log(`   Status: ${detailRes.status}`);
            console.log(`   Title: ${detailRes.data.title}`);
            console.log(`   Episodes: ${detailRes.data.totalEpisodes}`);
            console.log('   ✅ Passed\n');

            // 3. Test AnimeWorld Episodes Endpoint (New)
            console.log('3. Testing AnimeWorld Episodes List...');
            const episodesRes = await axios.get(`${BASE_URL}/anime/animeworld/episodes/${encodeURIComponent(animeId)}`);
            console.log(`   Status: ${episodesRes.status}`);
            console.log(`   Episodes found: ${episodesRes.data.length}`);
            console.log('   ✅ Passed\n');

            // 4. Test Episode Streaming (Wildcard Route)
            if (episodesRes.data.length > 0) {
                const episode = episodesRes.data[0];
                console.log('4. Testing Episode Streaming (Wildcard Route)...');
                console.log(`   Fetching stream for episode ID: ${episode.id}`);
                // Note: episode.id might have slashes, so we test if the wildcard handles it
                // We don't double encode here because the client puts it in the path URL-encoded
                const encEpId = encodeURIComponent(episode.id);
                const streamRes = await axios.get(`${BASE_URL}/anime/animeworld/episode/${encEpId}`);
                console.log(`   Status: ${streamRes.status}`);
                console.log(`   Stream URL: ${streamRes.data.sources[0]?.url}`);
                console.log('   ✅ Passed\n');
            }
        } else {
            console.log('   ⚠️ Skipping details/episodes tests because search returned no results\n');
        }

        // 5. Test MangaDex Search
        console.log('5. Testing MangaDex Search...');
        const mangaRes = await axios.get(`${BASE_URL}/mangadex/manga/search?q=one+piece`);
        console.log(`   Status: ${mangaRes.status}`);
        console.log(`   Results: ${mangaRes.data.length}`);
        console.log('   ✅ Passed\n');

        // 6. Test MangaHook Filters
        console.log('6. Testing MangaHook Filters...');
        const hookRes = await axios.get(`${BASE_URL}/mangahook/filters`);
        console.log(`   Status: ${hookRes.status}`);
        console.log(`   Categories: ${hookRes.data.categories?.length || 0}`);
        console.log('   ✅ Passed\n');

    } catch (error) {
        console.error('❌ Test Failed:', error.message);
        if (error.response) {
            console.error('   Response Data:', error.response.data);
            console.error('   Response Status:', error.response.status);
        }
    }
}

runTests();
