import { MangaParser, MediaStatus } from '@consumet/extensions/dist/models';
import { IMangaChapterPage, IMangaInfo, IMangaResult, ISearch } from '@consumet/extensions/dist/models';
import axios from 'axios';
import { load } from 'cheerio';

class MangaKatana extends MangaParser {
    override readonly name = 'MangaKatana';
    protected override baseUrl = 'https://mangakatana.com';
    protected override logo = 'https://mangakatana.com/favicon.ico';
    protected override classPath = 'MANGA.MangaKatana';

    override search = async (query: string, page: number = 1): Promise<ISearch<IMangaResult>> => {
        try {
            const { data } = await axios.get(`${this.baseUrl}/?search=${encodeURIComponent(query)}&page=${page}`);
            const $ = load(data);
            const results: IMangaResult[] = [];

            $('div.item').each((i, el) => {
                const url = $(el).find('.title a').attr('href');
                const id = url?.split('/').pop();
                const title = $(el).find('.title a').text().trim();
                const image = $(el).find('img').attr('src');

                if (id && title) {
                    results.push({
                        id: id,
                        title: title,
                        image: image,
                    });
                }
            });

            return { results };
        } catch (err) {
            throw new Error((err as Error).message);
        }
    };

    override fetchMangaInfo = async (mangaId: string): Promise<IMangaInfo> => {
        try {
            const { data } = await axios.get(`${this.baseUrl}/manga/${mangaId}`);
            const $ = load(data);

            const title = $('h1.heading').text().trim();
            const image = $('div.media div.cover img').attr('src');
            const description = $('div.summary p').text().trim();

            const statusStr = $('div.meta .status').text().trim().toLowerCase();
            let status = MediaStatus.UNKNOWN;
            if (statusStr.includes('ongoing')) status = MediaStatus.ONGOING;
            if (statusStr.includes('completed')) status = MediaStatus.COMPLETED;

            const genres: string[] = [];
            $('div.meta .genres a').each((_, el) => {
                genres.push($(el).text().trim());
            });

            const chapters: any[] = [];
            $('.chapters .chapter').each((_, el) => {
                const chapterLink = $(el).find('a');
                const chapterUrl = chapterLink.attr('href');
                const titleText = chapterLink.text().trim();
                const date = $(el).parent().find('.update_time').text().trim(); // Attempt to find date in parent row/item if possible, or skip

                const id = chapterUrl?.split('/').pop(); // e.g. c1

                const numberMatch = titleText.match(/(\d+(\.\d+)?)/);
                const chapterNumber = numberMatch ? parseFloat(numberMatch[0]) : 0;

                if (id) {
                    chapters.push({
                        id: `${mangaId}/${id}`, // Store as "manga_id/chapter_id"
                        title: titleText,
                        chapterNumber: chapterNumber,
                        releaseDate: date,
                    });
                }
            });
            // Ensure descending order
            chapters.sort((a, b) => b.chapterNumber - a.chapterNumber);

            return {
                id: mangaId,
                title: title,
                image: image,
                description: description,
                status: status,
                genres: genres,
                chapters: chapters
            };
        } catch (err) {
            throw new Error((err as Error).message);
        }
    };

    override fetchChapterPages = async (chapterId: string): Promise<IMangaChapterPage[]> => {
        try {
            // chapterId is like "manga-slug/c1"
            const url = `${this.baseUrl}/manga/${chapterId}`;

            const { data } = await axios.get(url);
            const $ = load(data);

            const pages: IMangaChapterPage[] = [];

            // Find all scripts that might contain the page array
            // Pattern: var [randomName] = ["url1", "url2", ...];
            const scripts = $('script').map((i, el) => $(el).html()).get();

            let bestArray: string[] = [];

            for (const script of scripts) {
                if (!script) continue;

                // Regex to find variable assignments of arrays (handling multi-line)
                // var name = [...];
                const matches = script.matchAll(/var\s+([a-zA-Z0-9_]+)\s*=\s*(\[[\s\S]*?\])\s*;/g);

                for (const match of matches) {
                    try {
                        const varName = match[1];
                        let arrayStr = match[2];

                        // Fix generic syntax issues if any (like single quotes)
                        arrayStr = arrayStr.replace(/'/g, '"');

                        // Remove trailing comma if present (e.g. [ "url", ] -> [ "url" ])
                        arrayStr = arrayStr.replace(/,\s*\]/, ']');

                        const potentialPages: string[] = JSON.parse(arrayStr);

                        // Check if it looks like an image array
                        if (Array.isArray(potentialPages) &&
                            potentialPages.length > 0 &&
                            (potentialPages[0].includes('http') || potentialPages[0].includes('.jpg') || potentialPages[0].includes('.png'))) {

                            // Keep the longest array found
                            if (potentialPages.length > bestArray.length) {
                                bestArray = potentialPages;
                            }
                        }
                    } catch (e) {
                        // Ignore parsing errors
                    }
                }
            }

            bestArray.forEach((u: string, i: number) => {
                pages.push({
                    page: i,
                    img: u
                });
            });

            return pages;
        } catch (err) {
            throw new Error((err as Error).message);
        }
    };
}

export default MangaKatana;
