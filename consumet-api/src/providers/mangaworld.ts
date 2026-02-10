import { MangaParser, MediaStatus } from '@consumet/extensions/dist/models';
import { IMangaChapterPage, IMangaInfo, IMangaResult, ISearch } from '@consumet/extensions/dist/models';
import axios from 'axios';
import { load } from 'cheerio';

class MangaWorld extends MangaParser {
    override readonly name = 'MangaWorld';
    protected override baseUrl = 'https://www.mangaworld.mx';
    protected override logo = 'https://www.mangaworld.mx/favicon.ico';
    protected override classPath = 'MANGA.MangaWorld';

    override search = async (query: string, page?: number): Promise<ISearch<IMangaResult>> => {
        try {
            const { data } = await axios.get(`${this.baseUrl}/archive?keyword=${encodeURIComponent(query)}`);
            const $ = load(data);
            const results: IMangaResult[] = [];

            $('div.entry').each((i, el) => {
                const url = $(el).find('a').attr('href');
                // Extract ID: /manga/678/toukyou-ghoul -> 678/toukyou-ghoul
                const id = url?.split('/manga/').pop();
                const title = $(el).find('a').attr('title');
                const image = $(el).find('img').attr('src');

                if (id && title) {
                    results.push({
                        id: id,
                        title: title.trim(),
                        image: image,
                        // url: url // Optional used in some places
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
            // MangaWorld IDs are often just the slug, but sometimes we might need the full URL or "manga/slug"
            // Assuming ID is just the slug e.g. "one-piece"
            const { data } = await axios.get(`${this.baseUrl}/manga/${mangaId}`);
            const $ = load(data);

            const title = $('h1.name').text().trim();
            const altTitles = $('div.info .meta-data:contains("Titoli alternativi")').next().text().trim().split(','); // Check structure
            // Actually structure based on scraper analysis:
            // div.info -> children. One child might contain "Titoli alternativi:"

            // Let's rely on generic selector similar to reference repo but adapted for cheerio
            const infoDiv = $('div.info');

            let description = $('div.comic-description').text().trim();
            const image = $('div.thumb img').attr('src');

            const statusStr = $('div.meta-data:contains("Stato:") a').text().trim().toLowerCase();
            let status = MediaStatus.UNKNOWN;
            if (statusStr.includes('corso')) status = MediaStatus.ONGOING;
            if (statusStr.includes('finito') || statusStr.includes('completato')) status = MediaStatus.COMPLETED;

            const genres: string[] = [];
            $('div.meta-data:contains("Generi:") a.p-1').each((_, el) => {
                genres.push($(el).text().trim());
            });

            const chapters: any[] = [];
            $('div.chapter').each((_, el) => {
                const chapterUrl = $(el).find('a').attr('href');
                // Url is like https://www.mangaworld.so/manga/2069/read/65e9...
                // ID should probably be the full read URL or part of it? 
                // Consumet usually expects ID to be passable to fetchChapterPages
                // Let's use the full relative path or extract IDs.
                // Reference scraper uses full URL.

                const id = chapterUrl?.replace(this.baseUrl, '') || ''; // Store relative path as ID

                // Extract chapter number
                const titleText = $(el).find('a span').first().text().trim(); // e.g. "Capitolo 1111"
                const date = $(el).find('i').text().trim();

                // Try extract number
                const numberMatch = titleText.match(/(\d+(\.\d+)?)/);
                const chapterNumber = numberMatch ? parseFloat(numberMatch[0]) : 0;

                chapters.push({
                    id: id,
                    title: titleText,
                    chapterNumber: chapterNumber,
                    releaseDate: date,
                    url: chapterUrl // helpful for debug
                });
            });

            // Sort descending (newest first) - typically they are already listed newest first on page
            // But user explicitly asked to change order? "cambiare l'ordine dei capitoli" 
            // Usually means they want OLD -> NEW or NEW -> OLD.
            // Most apps want NEW -> OLD (descending). 
            // If the site lists NEW -> OLD, and user says "change order", maybe they want OLD -> NEW?
            // Or maybe the site lists OLD -> NEW?
            // Ref repo does `Array.from(chaptersDiv).reverse()` which implies site lists OLD -> NEW?
            // Let's check: "Array.from(chaptersDiv).reverse().forEach..."
            // If the site lists OLD -> NEW (Volume 1 ... Volume 100), 
            // reversing it makes it NEW -> OLD (Volume 100 ... Volume 1).
            // Consumet usually expects NEW -> OLD (Chapter 100 at index 0).

            // If the page delivers chapters desc (top is Ch 100), cheerio sees Ch 100 first.
            // If Ref repo reverses, it might be because the site lists them ASC?
            // Let's assume user wants standard DESC order. If site is ASC, we reverse. IF site is DESC, we don't.
            // I will assume I need to ensure DESC order.

            chapters.sort((a, b) => b.chapterNumber - a.chapterNumber);

            return {
                id: mangaId,
                title: title || mangaId,
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
            // chapterId is expected to be "/manga/slug/read/..."
            const url = `${this.baseUrl}${chapterId.startsWith('/') ? '' : '/'}${chapterId}?style=list`;
            const { data } = await axios.get(url);
            const $ = load(data);

            const pages: IMangaChapterPage[] = [];
            $('#page img').each((i, el) => {
                const src = $(el).attr('src');
                if (src) {
                    pages.push({
                        page: i,
                        img: src
                    });
                }
            });

            return pages;
        } catch (err) {
            throw new Error((err as Error).message);
        }
    };
}

export default MangaWorld;
