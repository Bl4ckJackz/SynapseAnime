import { MangaParser, MediaStatus } from '@consumet/extensions/dist/models';
import { IMangaChapterPage, IMangaInfo, IMangaResult, ISearch } from '@consumet/extensions/dist/models';
import axios from 'axios';

class MangaSee extends MangaParser {
    override readonly name = 'MangaSee';
    protected override baseUrl = 'https://manga4life.com';
    protected override logo = 'https://manga4life.com/media/favicon.png';
    protected override classPath = 'MANGA.MangaSee';

    override search = async (query: string): Promise<ISearch<IMangaResult>> => {
        try {
            // MangaSee loads all manga in a JSON and does client side search.
            // Reference: doGet(this.httpHandlerMode, mangaSeeSearch, true);
            // mangaSeeSearch = 'https://mangasee123.com/_search.php';

            const { data } = await axios.get(`${this.baseUrl}/_search.php`, {
                headers: {
                    'Referer': this.baseUrl,
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                }
            });
            // data is array of { i: "slug", s: "Title", a: ["alias"], ... }

            const results: IMangaResult[] = [];
            const queryLower = query.toLowerCase();

            for (const item of data) {
                if (item.s.toLowerCase().includes(queryLower) || item.a.some((alias: string) => alias.toLowerCase().includes(queryLower))) {
                    results.push({
                        id: item.i,
                        title: item.s,
                        image: `https://temp.compsci88.com/cover/${item.i}.jpg` // Official cover domain for MangaSee
                    });
                }
                if (results.length > 20) break; // Limit results
            }

            return { results };
        } catch (err) {
            throw new Error((err as Error).message);
        }
    };

    override fetchMangaInfo = async (mangaId: string): Promise<IMangaInfo> => {
        try {
            const { data } = await axios.get(`${this.baseUrl}/manga/${mangaId}`, {
                headers: {
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
                }
            });
            // Parsing logic from reference:
            // regex vm.CHAPTERS = (.*); 
            // cover details from getRssDetails (RSS feed? or just parse page)
            // Reference just grabs basic details.

            // Let's use simple string searching or regex for efficiency
            const chaptersMatch = data.match(/vm\.CHAPTERS = (\[.*?\]);/);
            const chaptersData = chaptersMatch ? JSON.parse(chaptersMatch[1]) : [];

            const description = data.match(/<div class="Content">([\s\S]*?)<\/div>/)?.[1]?.trim() || '';
            // Cleanup description tags if any
            const cleanDesc = description.replace(/<[^>]*>?/gm, '');

            const image = `https://temp.compsci88.com/cover/${mangaId}.jpg`;
            const title = data.match(/<h1>(.*?)<\/h1>/)?.[1] || mangaId;

            const chapters: any[] = [];

            // Chapter data format: { Chapter: "100010", Type: "Chapter", Date: "2023-01-01", ... }
            // Format decoder: 
            // First digit: ? (usually 1)
            // Next 4 digits: Chapter number
            // Last digit: Decimal? 
            // Reference `toRealChapter`:
            // let chapterString = chapterWrapper['Chapter'];
            // let chapter = chapterString.substring(1, chapterString.length - 1);
            // let odd = chapterString.substring(chapterString.length - 1);
            // if (odd == 0) return chapter
            // else return chapter + "." + odd

            chaptersData.forEach((ch: any) => {
                const chapterString = ch.Chapter;
                const index = chapterString.substring(1, chapterString.length - 1);
                const odd = chapterString.substring(chapterString.length - 1);
                const num = odd === '0' ? index : `${index}.${odd}`;
                const chapterNumber = parseFloat(num);

                // Helper to generate ID. Reference:
                // -chapter-[chapterNumber]-page-1.html
                // e.g. /read-online/One-Piece-chapter-1111-page-1.html
                // We'll store ID as the chapter number, or construct full slug.
                // Let's store sufficient info to reconstruct URL in fetchChapterPages
                // ID: "1111" or "1055.5"

                const chId = `${mangaId}-chapter-${num}`;

                chapters.push({
                    id: chId, // Need full slug for read link? 
                    // URL pattern: https://mangasee123.com/read-online/[MangaID]-chapter-[ChapterNumber]-page-[Page].html
                    title: ch.ChapterName || `Chapter ${num}`,
                    chapterNumber: chapterNumber,
                    releaseDate: ch.Date
                });
            });

            // Ensure descending
            chapters.sort((a, b) => b.chapterNumber - a.chapterNumber);

            return {
                id: mangaId,
                title: title,
                image: image,
                description: cleanDesc,
                chapters: chapters,
                status: MediaStatus.UNKNOWN // Parsing status is a bit more complex from HTML, skipping for brevity
            }

        } catch (err) {
            throw new Error((err as Error).message);
        }
    };

    override fetchChapterPages = async (chapterId: string): Promise<IMangaChapterPage[]> => {
        try {
            // chapterId expected: "One-Piece-chapter-1111"
            // URL: https://mangasee123.com/read-online/One-Piece-chapter-1111-page-1.html

            const url = `${this.baseUrl}/read-online/${chapterId}-page-1.html`;
            const { data } = await axios.get(url);

            // Extract logic for pages.
            // Reference:
            // Search for curChapter = { ... };
            // Search for curPathName = "...";
            // Pages loop

            const curChapterMatch = data.match(/vm\.CurChapter = (\{.*?\});/);
            const curPathNameMatch = data.match(/vm\.CurPathName = "(.*?)";/);

            if (!curChapterMatch || !curPathNameMatch) throw new Error('Failed to parse chapter pages');

            const curChapter = JSON.parse(curChapterMatch[1]);
            const curPathName = curPathNameMatch[1];

            const pages: IMangaChapterPage[] = [];
            const totalPages = parseInt(curChapter.Page);

            // Directory construction: 
            // Directory is derived from Chapter number structure
            // e.g. Directory: /manga/One-Piece/0001-001.png
            // directory: curChapter.Directory usually empty string or special
            // The provided utils in ref repo show `getSlideUrl`:
            // https://[host]/manga/[CanonicalName]/[Directory]/[ChapterImage(chapter)]-[PageImage(page)].png
            // Host: curPathName (e.g. "https://cwj.guya.moe")

            // Image URL format is complex.
            // Reference utils.ts:
            // function getSlideUrl(canonicalName, chapter, page, host)
            // let directory = chapter.Directory == "" ? "" : chapter.Directory + "/";
            // return host + "/manga/" + canonicalName + "/" + directory + chapterImage(chapter.Chapter) + "-" + pageImage(page) + ".png";

            // Chapter image format:
            // 100010 -> 0001
            // 100015 -> 0001.5
            // Logic:
            // remove leading 1. 
            // index = ch.substring(1, 5)
            // odd = ch.substring(5, 6)
            // if odd == 0 return index
            // else return index + "." + odd

            // But looking at ref repo `utils.ts` in `temp_mangasee`:
            /*
              export const getSlideUrl = (canonicalName: string, chapter: number, page: number, host: string) => {
                const pageString = page < 10 ? '00' + page : page < 100 ? '0' + page : page;
                const chapterString = chapter < 10 ? '000' + chapter : chapter < 100 ? '00' + chapter : chapter < 1000 ? '0' + chapter : chapter;
                return `${host}/manga/${canonicalName}/${chapterString}-${pageString}.png`;
              };
            */
            // Wait, `getSlideUrl` in ref repo seems simpler but assumes `chapter` is number.
            // But `chapter` variable in loop of `getDetails` calls `toRealChapter`.
            // So the number passed to getSlideUrl is the real float number. 
            // How does it handle floats like 100.5?
            // I should look at `getSlideUrl` implementation in `temp_mangasee/src/utils.ts` carefully.

            // Let's rely on parsing the raw chapter object from the page which has correct formatting hints perhaps?
            // Actually simpler: 
            // The page variable `curChapter` has `Directory`.
            // The host `curPathName`.
            // CanonicalName is part of chapterId e.g. "One-Piece".

            const mangaId = chapterId.split('-chapter-')[0];
            const directory = curChapter.Directory ? `${curChapter.Directory}/` : '';

            // Decoding chapter string for image filename
            // Format: 100010 -> 0001
            const chStr = curChapter.Chapter; // "100010"
            const core = chStr.substring(1, 5); // "0001"
            const odd = chStr.substring(5, 6); // "0"
            const chFilename = odd === '0' ? core : `${core}.${odd}`;

            for (let i = 1; i <= totalPages; i++) {
                const pageNum = i.toString().padStart(3, '0');
                const imgUrl = `https://${curPathName}/manga/${mangaId}/${directory}${chFilename}-${pageNum}.png`;
                pages.push({
                    page: i,
                    img: imgUrl
                });
            }

            return pages;
        } catch (err) {
            throw new Error((err as Error).message);
        }
    };
}

export default MangaSee;
