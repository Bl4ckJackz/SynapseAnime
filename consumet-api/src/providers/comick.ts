import axios from 'axios';
import { load } from 'cheerio';
import { MangaParser, MediaStatus } from '@consumet/extensions/dist/models';
import { IMangaInfo, IMangaResult, ISearch } from '@consumet/extensions/dist/models';

class ComicK extends MangaParser {
    override readonly name = 'ComicK';
    protected override baseUrl = 'https://comick.art';
    protected override logo = 'https://th.bing.com/th/id/OIP.fw4WrmAoA2PmKitiyMzUIgAAAA?pid=ImgDet&rs=1';
    protected override classPath = 'MANGA.ComicK';
    private apiUrl = 'https://comick.art/api';
    private referer = 'https://comick.art';

    /**
     * @description Fetches info about the manga
     * @param mangaId Comic slug
     * @returns Promise<IMangaInfo>
     */
    fetchMangaInfo = async (mangaId: string): Promise<IMangaInfo> => {
        try {
            const data = await this.getComicData(mangaId);
            const links = Object.values(data.links ?? {}).filter(link => link !== null);

            // Fix: Check if md_titles is an array
            const altTitles = Array.isArray(data.md_titles)
                ? data.md_titles.map((title: any) => title.title)
                : [];

            const mangaInfo: IMangaInfo = {
                id: data.slug,
                title: data.title ?? data.slug,
                altTitles: altTitles,
                description: data.desc,
                genres: data.md_comic_md_genres?.map((genre: any) => genre.md_genres.name) ?? [],
                status: (data.status === 1) ? MediaStatus.ONGOING : MediaStatus.COMPLETED,
                image: data.default_thumbnail ?? '',
                // @ts-ignore
                malId: data.links?.mal,
                // @ts-ignore
                links: links,
                chapters: [],
            };

            const allChapters = await this.fetchAllChapters(mangaInfo.id, 1);
            for (const chapter of allChapters) {
                mangaInfo.chapters?.push({
                    id: `${mangaInfo.id}/${chapter.hid}-chapter-${chapter.chap}-${chapter.lang}`,
                    title: chapter.title ?? (chapter.chap ? `Chapter ${chapter.chap}` : 'Chapter'),
                    chapterNumber: chapter.chap,
                    volumeNumber: chapter.vol,
                    releaseDate: chapter.created_at,
                    // @ts-ignore
                    lang: chapter.lang,
                });
            }
            return mangaInfo;
        } catch (err: any) {
            if (err.code == 'ERR_BAD_REQUEST')
                throw new Error(`[${this.name}] Bad request. Make sure you have entered a valid query.`);
            throw new Error(err.message);
        }
    };

    /**
     *
     * @param chapterId Chapter ID '{slug}/{hid}-chapter-{chap}-{lang}'
     * @returns Promise<IMangaChapterPage[]>
     */
    fetchChapterPages = async (chapterId: string) => {
        try {
            const data = await this._axios().get(`/comics/${chapterId}`);
            const pages: any[] = [];
            data.data.chapter.images.map((image: any, index: number) => {
                pages.push({
                    img: image.url,
                    page: index,
                });
            });
            return pages;
        } catch (err: any) {
            throw new Error(err.message);
        }
    };

    /**
     * @param query search query
     * @param page page number (default: 1)
     */
    override search = async (query: string, page?: number | string): Promise<ISearch<IMangaResult>> => {
        try {
            // Default cursor logic seems missing in interface but used in JS implementation.
            // Using page as simple page param here or empty cursor?
            // JS used `cursor` arg but method signature search(query, page, limit) usually.
            // But JS implementation was `search = async (query, cursor)`.
            // Let's stick to simple implementation matching standard interface if possible.
            // But if pagination relies on cursor, 'page' arg might be treated as cursor.

            const cursor = page ? page.toString() : '';
            const req = await this._axios().get(`/search?q=${encodeURIComponent(query)}&cursor=${cursor}`);

            const results: ISearch<IMangaResult> = {
                results: [],
                // @ts-ignore
                prev_cursor: req.data.prev_cursor,
                // @ts-ignore
                next_cursor: req.data.next_cursor,
                // @ts-ignore
                hasNextPage: !!req.data.next_cursor // Approximate
            };

            const data = await req.data.data; // data property?
            // JS: const data = await req.data.data; wait, req.data is the response body.
            // req.data usually has data property?
            // JS code: `const data = await req.data.data;` -> await on non-promise? Maybe just `req.data.data`.

            // In axios response, req.data is the body.

            for (const manga of (Array.isArray(data) ? data : [])) {
                results.results.push({
                    id: manga.slug,
                    title: manga.title ?? manga.slug,
                    altTitles: Array.isArray(manga.md_titles) ? manga.md_titles.map((title: any) => title.title) : [],
                    image: manga.default_thumbnail ?? '',
                });
            }
            return results;
        } catch (err: any) {
            throw new Error(err.message);
        }
    };

    fetchAllChapters = async (hid: string, page: number): Promise<any[]> => {
        if (page <= 0) {
            page = 1;
        }
        const req = await this._axios().get(`/comics/${hid}/chapter-list?page=${page}`);
        return req.data.data; // data.data check
    };

    getComicData = async (mangaId: string) => {
        const req = await this._axios().get(`${this.baseUrl}/comic/${mangaId}`);
        const $ = load(req.data); // Cheerio load
        // @ts-ignore
        return JSON.parse($("script[id='comic-data']").text());
    };

    _axios() {
        return axios.create({
            baseURL: this.apiUrl,
            headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                Referer: this.referer,
            },
        });
    }
}

export default ComicK;
