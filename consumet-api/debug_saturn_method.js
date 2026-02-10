
const { ANIME } = require('@consumet/extensions');

try {
    const saturn = new ANIME.AnimeSaturn();
    console.log('AnimeSaturn instantiated.');
    console.log('fetchRecentEpisodes type:', typeof saturn.fetchRecentEpisodes);
} catch (e) {
    console.error('Error instantiating AnimeSaturn:', e.message);
}
