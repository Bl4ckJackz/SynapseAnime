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

@Injectable()
export class MangaDexService {
  private readonly baseUrl = 'https://api.mangadex.org';

  constructor(
    @InjectRepository(Manga)
    private mangaRepository: Repository<Manga>,
    @InjectRepository(Chapter)
    private chapterRepository: Repository<Chapter>,
  ) { }

  async searchManga(query: string, filters?: any): Promise<Manga[]> {
    try {
      const params: any = {
        title: query,
        limit: 20,
        'includes[]': ['cover_art'],
        ...filters,
      };

      const response = await mangadexAxios.get(`${this.baseUrl}/manga`, { params });
      const mangaResults = response.data.data;


      const mangas: Manga[] = mangaResults.map((mangaData: any) => {
        const manga = new Manga();
        manga.mangadexId = mangaData.id;
        manga.title = this.extractTitle(mangaData.attributes.title);
        manga.description = this.extractDescription(mangaData.attributes.description);
        manga.status = this.mapStatus(mangaData.attributes.status);
        manga.year = mangaData.attributes.year;

        // Find cover relationship
        const coverRel = mangaData.relationships?.find((rel: any) => rel.type === 'cover_art');
        if (coverRel && coverRel.attributes?.fileName) {
          manga.coverImage = `https://uploads.mangadex.org/covers/${mangaData.id}/${coverRel.attributes.fileName}`;
        }

        return manga;
      });

      return mangas;
    } catch (error) {
      console.error('Error searching manga:', error);
      return []; // Return empty instead of throwing to prevent crashing the UI
    }
  }

  async getMangaDetails(mangadexId: string): Promise<Manga> {
    try {
      const response = await mangadexAxios.get(`${this.baseUrl}/manga/${mangadexId}`);
      const mangaData = response.data.data;

      // Check if manga already exists in our database
      let manga = await this.mangaRepository.findOne({
        where: { mangadexId }
      });

      if (!manga) {
        manga = new Manga();
      }

      // Map MangaDex data to our entity
      manga.mangadexId = mangaData.id;
      manga.title = this.extractTitle(mangaData.attributes.title);
      manga.altTitles = this.extractAltTitles(mangaData.attributes.altTitles);
      manga.description = this.extractDescription(mangaData.attributes.description);
      manga.authors = this.extractAuthors(mangaData.relationships);
      manga.artists = this.extractArtists(mangaData.relationships);
      manga.genres = this.extractGenres(mangaData.attributes.tags);
      manga.tags = this.extractTags(mangaData.attributes.tags);
      manga.status = this.mapStatus(mangaData.attributes.status);
      manga.year = mangaData.attributes.year;
      const coverUrl = await this.getCoverImageUrl(mangaData.relationships);
      if (coverUrl) {
        manga.coverImage = coverUrl;
      }
      manga.rating = mangaData.attributes.averageRating || 0;
      manga.createdAt = new Date(mangaData.attributes.createdAt);
      manga.updatedAt = new Date(mangaData.attributes.updatedAt);

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

  async getChapters(mangadexId: string): Promise<Chapter[]> {
    try {
      let manga = await this.mangaRepository.findOne({
        where: { mangadexId }
      });

      // If manga not found in local DB, sync it first
      if (!manga) {
        console.log(`Manga ${mangadexId} not found in DB, syncing from MangaDex...`);
        try {
          manga = await this.getMangaDetails(mangadexId);
        } catch (syncError) {
          console.error(`Failed to sync manga ${mangadexId}:`, syncError);
          // Try to fetch chapters directly from MangaDex API
          return await this.getChaptersFromApi(mangadexId);
        }
      }

      const chapters = await this.chapterRepository.find({
        where: { mangaId: manga.id },
        order: { number: 'ASC' },
      });

      // If no chapters in DB, try to fetch from API
      if (chapters.length === 0) {
        console.log(`No chapters found in DB for ${mangadexId}, fetching from API...`);
        return await this.getChaptersFromApi(mangadexId);
      }

      return chapters;
    } catch (error) {
      console.error(`Error getting chapters for manga ${mangadexId}:`, error);
      // Fallback to direct API call
      return await this.getChaptersFromApi(mangadexId);
    }
  }

  private async getChaptersFromApi(mangadexId: string): Promise<Chapter[]> {
    try {
      const params: any = {
        'order[chapter]': 'asc',
        limit: 100,
        'translatedLanguage[]': ['it', 'en'],
      };

      const response = await mangadexAxios.get(`${this.baseUrl}/manga/${mangadexId}/feed`, { params });
      const chapterData = response.data.data || [];

      return chapterData.map((chap: any) => {
        const chapter = new Chapter();
        chapter.mangadexChapterId = chap.id;
        chapter.number = parseFloat(chap.attributes.chapter) || 0;
        chapter.title = chap.attributes.title || `Chapter ${chapter.number}`;
        const parsedVolume = parseFloat(chap.attributes.volume);
        chapter.volume = isNaN(parsedVolume) ? undefined : parsedVolume;
        chapter.pages = chap.attributes.pages || 0;
        chapter.language = chap.attributes.translatedLanguage || 'en';
        chapter.publishedAt = new Date(chap.attributes.publishAt);
        chapter.mangaId = mangadexId; // Use the mangadex ID as fallback
        chapter.createdAt = new Date();
        return chapter;
      });
    } catch (error) {
      console.error(`Error fetching chapters from MangaDex API for ${mangadexId}:`, error);
      return [];
    }
  }

  async getChapterPages(chapterId: string): Promise<string[]> {
    try {
      const response = await mangadexAxios.get(`${this.baseUrl}/at-home/server/${chapterId}`);
      const serverUrl = response.data.baseUrl;
      const chapterData = response.data.chapter;

      const pages: string[] = [];
      for (const fileName of chapterData.data) {
        pages.push(`${serverUrl}/data/${chapterData.hash}/${fileName}`);
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

  private extractTitle(titles: any): string {
    // Prefer English title, fall back to original Japanese
    if (titles.en) return titles.en;
    if (titles.ja) return titles.ja;
    // Return first available title
    const values = Object.values(titles);
    return (values[0] as string) || '';
  }

  private extractAltTitles(altTitles: any[]): Record<string, string> {
    if (!altTitles || !Array.isArray(altTitles)) return {};

    const titles: Record<string, string> = {};
    for (const title of altTitles) {
      for (const [lang, value] of Object.entries(title)) {
        titles[lang] = value as string;
      }
    }
    return titles;
  }

  private extractDescription(descriptions: any): string {
    // Prefer English description
    if (descriptions && descriptions.en) {
      return descriptions.en;
    }
    // Return first available description
    if (descriptions) {
      const firstDesc = Object.values(descriptions)[0];
      return firstDesc as string || '';
    }
    return '';
  }

  private extractAuthors(relationships: any[]): string[] {
    if (!relationships) return [];

    return relationships
      .filter((rel: any) => rel.type === 'author')
      .map((rel: any) => rel.attributes?.name)
      .filter((name: any) => name) || [];
  }

  private extractArtists(relationships: any[]): string[] {
    if (!relationships) return [];

    return relationships
      .filter((rel: any) => rel.type === 'artist')
      .map((rel: any) => rel.attributes?.name)
      .filter((name: any) => name) || [];
  }

  private extractGenres(tags: any[]): string[] {
    if (!tags) return [];

    return tags
      .filter((tag: any) => tag.attributes.group === 'genre')
      .map((tag: any) => tag.attributes.name.en)
      .filter((name: any) => name) || [];
  }

  private extractTags(tags: any[]): string[] {
    if (!tags) return [];

    return tags
      .map((tag: any) => tag.attributes.name.en)
      .filter((name: any) => name) || [];
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

  private async getCoverImageUrl(relationships: any[]): Promise<string | null> {
    if (!relationships) return null;

    const coverRel = relationships.find((rel: any) => rel.type === 'cover_art');
    if (!coverRel?.id) return null;

    try {
      const coverResponse = await mangadexAxios.get(`${this.baseUrl}/cover/${coverRel.id}`);
      const fileName = coverResponse.data.data.attributes.fileName;
      return `https://uploads.mangadex.org/covers/${coverRel.manga.id}/${fileName}`;
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
        const params: any = {
          'order[volume]': 'asc',
          'order[chapter]': 'asc',
          limit: limit,
          offset: offset,
          'translatedLanguage[]': ['it', 'en'], // Filter for Italian and English
        };

        const response = await mangadexAxios.get(`${this.baseUrl}/manga/${mangadexId}/feed`, { params });
        const chapterData = response.data.data;
        total = response.data.total;

        for (const chap of chapterData) {
          const chapter = new Chapter();
          chapter.mangadexChapterId = chap.id;
          chapter.number = parseFloat(chap.attributes.chapter) || 0;
          chapter.title = chap.attributes.title || `Chapter ${chapter.number}`;
          const parsedVolume = parseFloat(chap.attributes.volume);
          chapter.volume = isNaN(parsedVolume) ? undefined : parsedVolume;
          chapter.pages = chap.attributes.pages || 0;
          chapter.language = chap.attributes.translatedLanguage || 'en';
          const scanlationGroup = this.extractScanlationGroup(chap.relationships);
          if (scanlationGroup) {
            chapter.scanlationGroup = scanlationGroup;
          }
          chapter.publishedAt = new Date(chap.attributes.publishAt);
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

  private extractScanlationGroup(relationships: any[]): string | undefined {
    if (!relationships) return undefined;

    const groupRel = relationships.find((rel: any) => rel.type === 'scanlation_group');
    return groupRel?.attributes?.name;
  }
}