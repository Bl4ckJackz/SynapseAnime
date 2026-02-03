import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Manga, MangaStatus } from '../entities/manga.entity';
import { Chapter } from '../entities/chapter.entity';
import axios from 'axios';

// Axios instance with timeout for MangaDex API
const mangadexAxios = axios.create({
  timeout: 15000, // 15 second timeout
  headers: {
    'User-Agent': 'AnimeAIPlayer/1.0',
  },
});

// MangaDex API response types
interface MangaDexRelationship {
  id: string;
  type: string;
  attributes?: {
    name?: string;
    fileName?: string;
  };
  manga?: {
    id: string;
  };
}

interface MangaDexTag {
  attributes: {
    name: Record<string, string>;
    group?: string;
  };
}

interface MangaDexMangaAttributes {
  title: Record<string, string>;
  altTitles?: Record<string, string>[];
  description?: Record<string, string>;
  status?: string;
  year?: number;
  tags?: MangaDexTag[];
  averageRating?: number;
  createdAt?: string;
  updatedAt?: string;
}

interface MangaDexMangaData {
  id: string;
  attributes: MangaDexMangaAttributes;
  relationships?: MangaDexRelationship[];
}

interface MangaDexChapterAttributes {
  chapter?: string;
  title?: string;
  volume?: string;
  pages?: number;
  translatedLanguage?: string;
  publishAt?: string;
}

interface MangaDexChapterData {
  id: string;
  attributes: MangaDexChapterAttributes;
  relationships?: MangaDexRelationship[];
}

interface MangaDexAtHomeResponse {
  baseUrl: string;
  chapter: {
    hash: string;
    data: string[];
  };
}

interface MangaDexCoverResponse {
  data: {
    attributes: {
      fileName: string;
    };
  };
}

// Generic API response wrapper
interface MangaDexApiResponse<T> {
  data: T;
  total?: number;
}

@Injectable()
export class MangaDexService {
  private readonly baseUrl = 'https://api.mangadex.org';

  constructor(
    @InjectRepository(Manga)
    private mangaRepository: Repository<Manga>,
    @InjectRepository(Chapter)
    private chapterRepository: Repository<Chapter>,
  ) { }

  async searchManga(
    query: string,
    filters?: Record<string, string | number | string[]>,
  ): Promise<Manga[]> {
    try {
      // MangaDex Tag IDs for exclusion
      // Doujinshi: b13b2a48-c720-44a9-9c77-39c9979373fb
      // Anthology: a3c67850-4684-404e-9b7f-c69850ee5da6
      const excludedTagIds = [
        'b13b2a48-c720-44a9-9c77-39c9979373fb', // Doujinshi
        'a3c67850-4684-404e-9b7f-c69850ee5da6', // Anthology
      ];

      const params: Record<string, string | number | string[]> = {
        title: query,
        limit: 20,
        'includes[]': ['cover_art'],
        'excludedTags[]': excludedTagIds,
        ...filters,
      };

      const response = await mangadexAxios.get(`${this.baseUrl}/manga`, {
        params,
      });
      const apiResponse = response.data as MangaDexApiResponse<
        MangaDexMangaData[]
      >;
      const mangaResults = apiResponse.data;

      const mangas: Manga[] = mangaResults.map(
        (mangaData: MangaDexMangaData) => {
          const manga = new Manga();
          manga.mangadexId = mangaData.id;
          manga.title = this.extractTitle(mangaData.attributes.title);
          manga.description = this.extractDescription(
            mangaData.attributes.description,
          );
          manga.status = this.mapStatus(
            mangaData.attributes.status ?? 'ongoing',
          );
          manga.year = mangaData.attributes.year ?? 0;

          // Find cover relationship
          const coverRel = mangaData.relationships?.find(
            (rel: MangaDexRelationship) => rel.type === 'cover_art',
          );
          if (coverRel && coverRel.attributes?.fileName) {
            manga.coverImage = `https://uploads.mangadex.org/covers/${mangaData.id}/${coverRel.attributes.fileName}`;
          }

          return manga;
        },
      );

      return mangas;
    } catch (error) {
      console.error('Error searching manga:', error);
      return []; // Return empty instead of throwing to prevent crashing the UI
    }
  }

  async getMangaDetails(mangadexId: string): Promise<Manga> {
    try {
      const response = await mangadexAxios.get(
        `${this.baseUrl}/manga/${mangadexId}`,
      );
      const apiResponse =
        response.data as MangaDexApiResponse<MangaDexMangaData>;
      const mangaData = apiResponse.data;

      // Check if manga already exists in our database
      let manga = await this.mangaRepository.findOne({
        where: { mangadexId },
      });

      if (!manga) {
        manga = new Manga();
      }

      // Map MangaDex data to our entity
      manga.mangadexId = mangaData.id;
      manga.title = this.extractTitle(mangaData.attributes.title);
      manga.altTitles = this.extractAltTitles(
        mangaData.attributes.altTitles ?? [],
      );
      manga.description = this.extractDescription(
        mangaData.attributes.description,
      );
      manga.authors = this.extractAuthors(mangaData.relationships ?? []);
      manga.artists = this.extractArtists(mangaData.relationships ?? []);
      manga.genres = this.extractGenres(mangaData.attributes.tags ?? []);
      manga.tags = this.extractTags(mangaData.attributes.tags ?? []);
      manga.status = this.mapStatus(mangaData.attributes.status ?? 'ongoing');
      manga.year = mangaData.attributes.year ?? 0;
      const coverUrl = await this.getCoverImageUrl(
        mangaData.relationships ?? [],
      );
      if (coverUrl) {
        manga.coverImage = coverUrl;
      }
      manga.rating = mangaData.attributes.averageRating || 0;
      manga.createdAt = new Date(mangaData.attributes.createdAt ?? Date.now());
      manga.updatedAt = new Date(mangaData.attributes.updatedAt ?? Date.now());

      // Save manga to database
      manga = await this.mangaRepository.save(manga);

      // Fetch and save chapters
      await this.syncChapters(manga.id, manga.mangadexId);

      return manga;
    } catch (error) {
      console.error(`Error getting manga details for ${mangadexId}:`, error);
      throw new Error(`Failed to get manga details for ${mangadexId}`);
    }
  }

  async getChapters(
    mangadexId: string,
    preferredLanguage?: string,
  ): Promise<Chapter[]> {
    try {
      let manga = await this.mangaRepository.findOne({
        where: { mangadexId },
      });

      // If manga not found in local DB, sync it first
      if (!manga) {
        console.log(
          `Manga ${mangadexId} not found in DB, syncing from MangaDex...`,
        );
        try {
          manga = await this.getMangaDetails(mangadexId);
        } catch (syncError) {
          console.error(`Failed to sync manga ${mangadexId}:`, syncError);
          // Try to fetch chapters directly from MangaDex API
          return await this.getChaptersFromApi(mangadexId, preferredLanguage);
        }
      }

      const chapters = await this.chapterRepository.find({
        where: { mangaId: manga.id },
        order: { number: 'ASC' },
      });

      // If no chapters in DB, try to fetch from API
      if (chapters.length === 0) {
        console.log(
          `No chapters found in DB for ${mangadexId}, fetching from API...`,
        );
        return await this.getChaptersFromApi(mangadexId, preferredLanguage);
      }

      // Filter and deduplicate chapters by language preference
      return this.filterChaptersByLanguage(chapters, preferredLanguage);
    } catch (error) {
      console.error(`Error getting chapters for manga ${mangadexId}:`, error);
      // Fallback to direct API call
      return await this.getChaptersFromApi(mangadexId, preferredLanguage);
    }
  }

  private async getChaptersFromApi(
    mangadexId: string,
    preferredLanguage?: string,
  ): Promise<Chapter[]> {
    try {
      // First try with preferred languages (IT/EN)
      let chapters = await this.fetchChaptersWithLanguage(mangadexId, [
        'it',
        'en',
      ]);
      console.log(`DEBUG: Fetched ${chapters.length} IT/EN chapters for ${mangadexId}`);

      // If no chapters found, try without language filter
      if (chapters.length === 0) {
        console.log(
          `No IT/EN chapters found for ${mangadexId}, fetching all languages...`,
        );
        chapters = await this.fetchChaptersWithLanguage(mangadexId, undefined);
        console.log(`DEBUG: Fetched ${chapters.length} chapters (all languages) for ${mangadexId}`);
      }

      // Filter and deduplicate chapters by language preference
      const filtered = this.filterChaptersByLanguage(chapters, preferredLanguage);
      console.log(`DEBUG: After filter: ${filtered.length} chapters for ${mangadexId}`);
      return filtered;
    } catch (error) {
      console.error(
        `Error fetching chapters from MangaDex API for ${mangadexId}:`,
        error,
      );
      return [];
    }
  }

  private async fetchChaptersWithLanguage(
    mangadexId: string,
    languages?: string[],
  ): Promise<Chapter[]> {
    const allChapters: Chapter[] = [];
    let offset = 0;
    const limit = 100;
    let total = 0;

    do {
      const params: Record<string, string | number | string[]> = {
        'order[chapter]': 'asc',
        limit: limit,
        offset: offset,
      };

      // Only add language filter if specified
      if (languages && languages.length > 0) {
        params['translatedLanguage[]'] = languages;
      }

      const response = await mangadexAxios.get(
        `${this.baseUrl}/manga/${mangadexId}/feed`,
        { params },
      );
      const apiResponse = response.data as MangaDexApiResponse<
        MangaDexChapterData[]
      >;
      const chapterData = apiResponse.data || [];
      total = apiResponse.total ?? 0;

      for (const chap of chapterData) {
        const chapter = new Chapter();
        chapter.mangadexChapterId = chap.id;
        chapter.number = parseFloat(chap.attributes.chapter ?? '0') || 0;
        chapter.title = chap.attributes.title || `Chapter ${chapter.number}`;
        const parsedVolume = parseFloat(chap.attributes.volume ?? '');
        chapter.volume = isNaN(parsedVolume) ? undefined : parsedVolume;
        chapter.pages = chap.attributes.pages || 0;
        chapter.language = chap.attributes.translatedLanguage || 'en';
        chapter.publishedAt = new Date(chap.attributes.publishAt ?? Date.now());
        chapter.mangaId = mangadexId;
        chapter.createdAt = new Date();
        allChapters.push(chapter);
      }

      offset += limit;
    } while (offset < total && offset < 1000); // 1000 chapter safety limit

    return allChapters;
  }
  /**
   * Filters and deduplicates chapters by language preference.
   * Priority: Italian > English > any other language
   * For each chapter number, keeps only one version based on language priority.
   */
  private filterChaptersByLanguage(
    chapters: Chapter[],
    preferredLanguage?: string,
  ): Chapter[] {
    // Define language priority (first = highest priority)
    const langPriority = preferredLanguage
      ? [preferredLanguage, 'en', 'it']
      : ['en', 'it'];

    // Group chapters by number
    const chaptersByNumber = new Map<number, Chapter[]>();
    for (const chapter of chapters) {
      const num = chapter.number;
      if (!chaptersByNumber.has(num)) {
        chaptersByNumber.set(num, []);
      }
      chaptersByNumber.get(num)!.push(chapter);
    }

    // For each chapter number, pick the best language version
    const result: Chapter[] = [];
    for (const [, chapterVersions] of chaptersByNumber) {
      let bestChapter: Chapter | null = null;

      // Try to find a chapter in preferred languages
      for (const lang of langPriority) {
        const match = chapterVersions.find((c) => c.language === lang);
        if (match) {
          bestChapter = match;
          break;
        }
      }

      // If no preferred language found, use the first available chapter
      // (better to show a chapter in any language than nothing)
      if (!bestChapter && chapterVersions.length > 0) {
        bestChapter = chapterVersions[0];
      }

      if (bestChapter) {
        result.push(bestChapter);
      }
    }

    // Return sorted by chapter number
    return result.sort((a, b) => a.number - b.number);
  }

  /**
   * @deprecated Use filterChaptersByLanguage instead
   */
  private deduplicateChaptersByLanguage(chapters: Chapter[]): Chapter[] {
    return this.filterChaptersByLanguage(chapters);
  }

  async getChapterPages(chapterId: string): Promise<string[]> {
    try {
      const response = await mangadexAxios.get(
        `${this.baseUrl}/at-home/server/${chapterId}`,
      );
      const atHomeData = response.data as MangaDexAtHomeResponse;
      const serverUrl = atHomeData.baseUrl;
      const chapterInfo = atHomeData.chapter;

      const pages: string[] = [];
      for (const fileName of chapterInfo.data) {
        pages.push(`${serverUrl}/data/${chapterInfo.hash}/${fileName}`);
      }

      return pages;
    } catch (error) {
      console.error(`Error getting pages for chapter ${chapterId}:`, error);
      throw new Error(`Failed to get pages for chapter ${chapterId}`);
    }
  }

  async syncMangaData(mangadexId: string): Promise<void> {
    try {
      // This will fetch manga details and chapters, saving them to our DB
      await this.getMangaDetails(mangadexId);
    } catch (error) {
      console.error(`Error syncing manga data for ${mangadexId}:`, error);
      throw new Error(`Failed to sync manga data for ${mangadexId}`);
    }
  }

  private extractTitle(titles: Record<string, string>): string {
    // Prefer English title, fall back to original Japanese
    if (titles.en) return titles.en;
    if (titles.ja) return titles.ja;
    // Return first available title
    const values = Object.values(titles);
    return values[0] || '';
  }

  private extractAltTitles(
    altTitles: Record<string, string>[],
  ): Record<string, string> {
    if (!altTitles || !Array.isArray(altTitles)) return {};

    const titles: Record<string, string> = {};
    for (const title of altTitles) {
      for (const [lang, value] of Object.entries(title)) {
        titles[lang] = value;
      }
    }
    return titles;
  }

  private extractDescription(descriptions?: Record<string, string>): string {
    // Prefer English description
    if (descriptions && descriptions.en) {
      return descriptions.en;
    }
    // Return first available description
    if (descriptions) {
      const firstDesc = Object.values(descriptions)[0];
      return firstDesc || '';
    }
    return '';
  }

  private extractAuthors(relationships: MangaDexRelationship[]): string[] {
    if (!relationships) return [];

    return relationships
      .filter((rel) => rel.type === 'author')
      .map((rel) => rel.attributes?.name)
      .filter((name): name is string => !!name);
  }

  private extractArtists(relationships: MangaDexRelationship[]): string[] {
    if (!relationships) return [];

    return relationships
      .filter((rel) => rel.type === 'artist')
      .map((rel) => rel.attributes?.name)
      .filter((name): name is string => !!name);
  }

  private extractGenres(tags: MangaDexTag[]): string[] {
    if (!tags) return [];

    return tags
      .filter((tag) => tag.attributes.group === 'genre')
      .map((tag) => tag.attributes.name.en)
      .filter((name): name is string => !!name);
  }

  private extractTags(tags: MangaDexTag[]): string[] {
    if (!tags) return [];

    return tags
      .map((tag) => tag.attributes.name.en)
      .filter((name): name is string => !!name);
  }

  private mapStatus(status: string): MangaStatus {
    switch (status) {
      case 'ongoing':
        return MangaStatus.ONGOING;
      case 'completed':
        return MangaStatus.COMPLETED;
      case 'hiatus':
        return MangaStatus.HIATUS;
      case 'cancelled':
        return MangaStatus.CANCELLED;
      default:
        return MangaStatus.ONGOING;
    }
  }

  private async getCoverImageUrl(
    relationships: MangaDexRelationship[],
  ): Promise<string | null> {
    if (!relationships) return null;

    const coverRel = relationships.find((rel) => rel.type === 'cover_art');
    if (!coverRel?.id) return null;

    try {
      const coverResponse = await mangadexAxios.get(
        `${this.baseUrl}/cover/${coverRel.id}`,
      );
      const coverData = coverResponse.data as MangaDexCoverResponse;
      const fileName = coverData.data.attributes.fileName;
      return `https://uploads.mangadex.org/covers/${coverRel.manga?.id ?? coverRel.id}/${fileName}`;
    } catch (error) {
      console.error('Error fetching cover image:', error);
      return null;
    }
  }

  async syncChapters(mangaId: string, mangadexId: string): Promise<void> {
    try {
      // Clear existing chapters first
      await this.chapterRepository.delete({ mangaId });

      let offset = 0;
      const limit = 100;
      let total = 0;

      do {
        const params: Record<string, string | number | string[]> = {
          'order[volume]': 'asc',
          'order[chapter]': 'asc',
          limit: limit,
          offset: offset,
          'translatedLanguage[]': ['it', 'en'], // Filter for Italian and English
        };

        const response = await mangadexAxios.get(
          `${this.baseUrl}/manga/${mangadexId}/feed`,
          { params },
        );
        const apiResponse = response.data as MangaDexApiResponse<
          MangaDexChapterData[]
        >;
        const chapterList = apiResponse.data || [];
        total = apiResponse.total ?? 0;

        for (const chap of chapterList) {
          const chapter = new Chapter();
          chapter.mangadexChapterId = chap.id;
          chapter.number = parseFloat(chap.attributes.chapter ?? '0') || 0;
          chapter.title = chap.attributes.title || `Chapter ${chapter.number}`;
          const parsedVolume = parseFloat(chap.attributes.volume ?? '');
          chapter.volume = isNaN(parsedVolume) ? undefined : parsedVolume;
          chapter.pages = chap.attributes.pages || 0;
          chapter.language = chap.attributes.translatedLanguage || 'en';
          const scanlationGroup = this.extractScanlationGroup(
            chap.relationships ?? [],
          );
          if (scanlationGroup) {
            chapter.scanlationGroup = scanlationGroup;
          }
          chapter.publishedAt = new Date(
            chap.attributes.publishAt ?? Date.now(),
          );
          chapter.mangaId = mangaId;
          chapter.createdAt = new Date();

          await this.chapterRepository.save(chapter);
        }

        offset += limit;
      } while (offset < total && offset < 1000); // 1000 chapter safety limit
    } catch (error) {
      console.error(`Error syncing chapters for manga ${mangadexId}:`, error);
      throw new Error(`Failed to sync chapters for manga ${mangadexId}`);
    }
  }

  private extractScanlationGroup(
    relationships: MangaDexRelationship[],
  ): string | undefined {
    if (!relationships) return undefined;

    const groupRel = relationships.find(
      (rel) => rel.type === 'scanlation_group',
    );
    return groupRel?.attributes?.name;
  }
}
