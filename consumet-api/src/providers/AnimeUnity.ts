import { load } from 'cheerio';
import { ISource, IAnimeInfo, IAnimeResult, SubOrSub, IEpisodeServer, ISearch } from '@consumet/extensions';
import AnimeParser from '@consumet/extensions/dist/models/anime-parser';
import * as fs from 'fs';

// Helper function for debug logging
function logDebug(message: string) {
    const logPath = 'c:\\Users\\domin\\debug_animeunity.txt';
    const timestamp = new Date().toISOString();
    const logMessage = `${timestamp}: ${message}\n`;
    try {
        fs.appendFileSync(logPath, logMessage);
    } catch (err) {
        console.error('Failed to write to debug log:', err);
    }
}

class AnimeUnity extends AnimeParser {
    override readonly baseUrl = 'https://www.animeunity.so';
    override readonly name = 'AnimeUnity';
    protected override readonly logo = 'https://i.imgur.com/6L8q9qS.png';
    protected override readonly classPath = 'ANIME.AnimeUnity';

    override search = async (query: string, page?: number): Promise<ISearch<IAnimeResult>> => {
        try {
            const res = await this.client.get(`${this.baseUrl}/archivio?title=${query}`);
            const $ = load(res.data);

            const recordsStr = $('archivio').attr('records');
            if (!recordsStr) return { results: [] };

            // The records are HTML entity encoded
            const items = JSON.parse(recordsStr.replace(/&quot;/g, '"'));

            const searchResult: ISearch<IAnimeResult> = {
                hasNextPage: false,
                results: [],
            };

            for (const i in items) {
                searchResult.results.push({
                    id: `${items[i].id}-${items[i].slug}`,
                    title: items[i].title ?? items[i].title_eng,
                    url: `${this.baseUrl}/anime/${items[i].id}-${items[i].slug}`,
                    image: items[i].imageurl,
                    cover: items[i].imageurl_cover,
                    rating: parseFloat(items[i].score),
                    releaseDate: items[i].date,
                    subOrDub: items[i].dub ? SubOrSub.DUB : SubOrSub.SUB,
                });
            }

            return searchResult;
        } catch (err) {
            throw new Error((err as Error).message);
        }
    };

    override fetchAnimeInfo = async (animeId: string, page: number = 1): Promise<IAnimeInfo> => {
        const id = animeId.split('/').pop()?.split('-')[0];
        const url = `${this.baseUrl}/anime/${animeId}`;
        const episodesPerPage = 120;
        const lastPageEpisode = page * episodesPerPage;
        const firstPageEpisode = lastPageEpisode - 119;
        const url2 = `${this.baseUrl}/info_api/${id}/1?start_range=${firstPageEpisode}&end_range=${lastPageEpisode}`;

        try {
            const res = await this.client.get(url);
            const $ = load(res.data);
            const totalEpisodes = parseInt($('video-player')?.attr('episodes_count') ?? '0');

            const animeInfo: IAnimeInfo = {
                id: animeId,
                title: $('h1.title')?.text().trim() as string,
                url: url,
                genres: $('.info-wrapper.pt-3.pb-3 small')?.map((_, element) => {
                    return $(element).text().replace(',', '').trim();
                }).toArray() as string[],
                totalEpisodes: totalEpisodes,
                image: $('img.cover')?.attr('src'),
                cover: $('.banner')?.attr('src') ?? $('.banner')?.attr('style')?.replace('background: url(', ''),
                description: $('.description').text().trim(),
                episodes: [],
            };

            const res2 = await this.client.get(url2);
            const items = res2.data.episodes;
            for (const i in items) {
                animeInfo.episodes?.push({
                    id: `${items[i].id}`,
                    number: parseInt(items[i].number),
                    url: `${url}/${items[i].id}`,
                });
            }

            return animeInfo;
        } catch (err) {
            throw new Error((err as Error).message);
        }
    };

    override fetchEpisodeSources = async (episodeId: string): Promise<ISource> => {
        try {
            const id = episodeId;
            const episodeSources: ISource = {
                sources: [],
            };

            if (!id) return episodeSources;

            const videoUrl = `${this.baseUrl}/embed-url/${id}`;
            logDebug(`[AnimeUnity] Fetching internal ID: ${id}`);

            try {
                const res = await this.client.get(videoUrl, {
                    headers: {
                        Referer: this.baseUrl,
                        'X-Requested-With': 'XMLHttpRequest'
                    }
                });

                const streamUrl = res.data;
                logDebug(`[AnimeUnity] API returned stream URL: ${streamUrl}`);

                if (streamUrl && streamUrl.startsWith('http')) {
                    const res = await this.client.get(streamUrl);
                    const $ = load(res.data);

                    const videoScript = $('script:contains("window.video")').text();
                    const downloadScript = $('script:contains("window.downloadUrl ")').text();

                    const domainMatch = videoScript?.match(/url: '(.*)'/);
                    const tokenMatch = videoScript?.match(/token': '(.*)'/);
                    const expiresMatch = videoScript?.match(/expires': '(.*)'/);

                    if (domainMatch && tokenMatch && expiresMatch) {
                        const domain = domainMatch[1];
                        const token = tokenMatch[1];
                        const expires = expiresMatch[1];
                        const defaultUrl = `${domain}${domain.includes('?') ? '&' : '?'}token=${token}&referer=&expires=${expires}&h=1`;

                        try {
                            const m3u8Content = await this.client.get(defaultUrl);
                            if (m3u8Content.data.includes('EXTM3U')) {
                                const videoList = m3u8Content.data.split('#EXT-X-STREAM-INF:');
                                for (const video of videoList ?? []) {
                                    if (video.includes('BANDWIDTH')) {
                                        const urlLines = video.split('\n');
                                        const url = urlLines[1];
                                        const resolutionMatch = video.match(/RESOLUTION=\d+x(\d+)/);
                                        const quality = resolutionMatch ? `${resolutionMatch[1]}p` : 'auto';

                                        episodeSources.sources.push({
                                            url: url,
                                            quality: quality,
                                            isM3U8: true,
                                        });
                                    }
                                }
                            }
                        } catch (e) { }

                        episodeSources.sources.push({
                            url: defaultUrl,
                            quality: 'default',
                            isM3U8: true,
                        });
                    }
                    episodeSources.download = downloadScript?.match(/downloadUrl = '(.*)'/)?.[1];
                }
            } catch (e) {
                logDebug(`[AnimeUnity] API fetch failed: ${(e as Error).message}`);
            }

            return episodeSources;
        } catch (err) {
            throw new Error((err as Error).message);
        }
    };

    fetchRecentEpisodes = async (page: number = 1): Promise<ISearch<IAnimeResult>> => {
        try {
            const res = await this.client.get(this.baseUrl);
            const $ = load(res.data);

            const layoutItems = $('layout-items');
            const itemsJson = layoutItems.attr('items-json');

            if (!itemsJson) {
                return { results: [] };
            }

            const data = JSON.parse(itemsJson.replace(/&quot;/g, '"'));
            const episodes = data.data || [];

            const results = episodes.map((item: any) => ({
                id: `${item.anime.id}-${item.anime.slug}`,
                episodeId: item.id.toString(),
                episodeNumber: parseInt(item.number),
                title: item.anime.title,
                image: item.anime.imageurl,
                url: `${this.baseUrl}/anime/${item.anime.id}-${item.anime.slug}/${item.id}`,
                releaseDate: item.created_at,
                subOrDub: SubOrSub.SUB,
            }));

            return {
                hasNextPage: data.current_page < (data.last_page || 1),
                results: results
            };
        } catch (err) {
            throw new Error((err as Error).message);
        }
    };

    override fetchEpisodeServers = (episodeId: string): Promise<IEpisodeServer[]> => {
        throw new Error("Method not implemented.");
    };
}

export default AnimeUnity;
