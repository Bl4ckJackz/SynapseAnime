import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Like } from 'typeorm';
import { Manga } from '../entities/manga.entity';
import { Chapter } from '../entities/chapter.entity';

@Injectable()
export class MangaService {
  constructor(
    @InjectRepository(Manga)
    private mangaRepository: Repository<Manga>,
    @InjectRepository(Chapter)
    private chapterRepository: Repository<Chapter>,
  ) {}

  async searchManga(query: string, filters?: any) {
    // Only search in our local database
    const localManga = await this.mangaRepository.find({
      where: [{ title: Like(`%${query}%`) }],
    });

    return localManga;
  }

  async getMangaById(mangaId: string) {
    // Only try to find in our local database
    let manga = await this.mangaRepository.findOne({ where: { id: mangaId } });

    if (!manga) {
      // If not found locally, try to find by mangadexId
      manga = await this.mangaRepository.findOne({
        where: { mangadexId: mangaId },
      });
    }

    return manga;
  }

  async getChapters(mangaId: string) {
    // First try to get chapters from our database
    const localChapters = await this.chapterRepository.find({
      where: { mangaId },
      order: { number: 'ASC' },
    });

    if (localChapters.length > 0) {
      return localChapters;
    }

    // If no chapters in DB, try to get manga to trigger sync
    const manga = await this.mangaRepository.findOne({
      where: { id: mangaId },
    });
    if (manga) {
      // Chapters should already be synced when manga was added
      return await this.chapterRepository.find({
        where: { mangaId },
        order: { number: 'ASC' },
      });
    }

    return [];
  }

  async getChapterPages(chapterId: string) {
    // This would normally fetch from MangaDex, but for now return empty array
    return [];
  }

  async getMangaByGenre(genre: string, limit = 10) {
    // For SQLite, we'll search in the JSON string representation of genres
    return await this.mangaRepository.find({
      where: { genres: Like(`%${genre}%`) },
      take: limit,
      order: { rating: 'DESC' },
    });
  }

  async getPopularManga(limit = 10) {
    return await this.mangaRepository.find({
      order: { rating: 'DESC' },
      take: limit,
    });
  }

  async getLatestManga(limit = 10) {
    return await this.mangaRepository.find({
      order: { createdAt: 'DESC' },
      take: limit,
    });
  }

  async addToReadingList(userId: string, mangaId: string) {
    // This would typically update the user's reading list
    // Implementation depends on how reading lists are stored
    console.log(`Adding manga ${mangaId} to user ${userId}'s reading list`);
  }

  async removeFromReadingList(userId: string, mangaId: string) {
    // This would typically update the user's reading list
    console.log(`Removing manga ${mangaId} from user ${userId}'s reading list`);
  }
}
