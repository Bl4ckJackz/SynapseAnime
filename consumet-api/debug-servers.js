
const { HiAnime } = require('aniwatch');

(async () => {
    const hianime = new HiAnime.Scraper();
    const episodeId = 'the-melody-of-oblivion-6505?ep=44242';

    try {
        console.log(`Fetching servers for: ${episodeId}`);
        const servers = await hianime.getEpisodeServers(episodeId);

        let selectedCategory = null;
        if (servers.sub && servers.sub.length > 0) selectedCategory = 'sub';
        else if (servers.dub && servers.dub.length > 0) selectedCategory = 'dub';

        if (selectedCategory) {
            let catServers = servers[selectedCategory] || [];
            const priority = ['hd-1', 'megacloud', 'vidcloud', 'vidstreaming'];
            let bestServer = catServers.find(s => priority.includes(s.name)) || catServers[0];

            if (bestServer) {
                console.log(`Selected Server: ${bestServer.name}`);
                try {
                    const sources = await hianime.getEpisodeSources(episodeId, bestServer.name, selectedCategory);
                    console.log('Sources fetched successfully!');
                    console.log('Headers:', JSON.stringify(sources.headers || {}, null, 2));
                    console.log(`Number of sources: ${sources.sources.length}`);
                    if (sources.sources.length > 0) {
                        console.log('First Source URL:', sources.sources[0].url);
                    }
                } catch (e) {
                    console.error('Error fetching sources:', e);
                }
            } else {
                console.error('No server found.');
            }
        } else {
            console.error('No category found.');
        }

    } catch (err) {
        console.error('Error:', err);
    }
})();
