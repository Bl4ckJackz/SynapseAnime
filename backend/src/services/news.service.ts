import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Like } from 'typeorm';
import { News } from '../entities/news.entity';

@Injectable()
export class NewsService {
  constructor(
    @InjectRepository(News)
    private newsRepository: Repository<News>,
  ) {}

  async fetchLatestNews(sources: string[] = ['myanimelist']): Promise<News[]> {
    const allNews: News[] = [];

    for (const source of sources) {
      switch (source) {
        case 'custom':
          const customNews = await this.fetchCustomNews();
          allNews.push(...customNews);
          break;
        default:
          console.warn(`Unknown news source: ${source}`);
      }
    }

    // Sort by publication date (newest first)
    return allNews.sort(
      (a, b) =>
        new Date(b.publishedAt).getTime() - new Date(a.publishedAt).getTime(),
    );
  }

  private async fetchMyAnimeListNews(): Promise<News[]> {
    // This would typically connect to MyAnimeList's API
    // For now, we'll simulate with mock data
    console.log('Fetching news from MyAnimeList...');

    // In a real implementation, we would use the Jikan API to fetch news
    // For demonstration purposes, returning empty array
    return [];
  }

  private async fetchAniListNews(): Promise<News[]> {
    // This would connect to AniList's API
    console.log('Fetching news from AniList...');

    // In a real implementation, we would use AniList's GraphQL API
    // For demonstration purposes, returning empty array
    return [];
  }

  private async fetchCustomNews(): Promise<News[]> {
    // Fetch internally curated news
    return await this.newsRepository.find({
      where: { source: 'custom', isActive: true },
      order: { publishedAt: 'DESC' },
    });
  }

  async createNews(newsData: Partial<News>): Promise<News> {
    const news = new News();
    Object.assign(news, newsData);

    // Set default values if not provided
    if (!news.publishedAt) {
      news.publishedAt = new Date();
    }

    if (!news.createdAt) {
      news.createdAt = new Date();
    }

    if (!news.updatedAt) {
      news.updatedAt = new Date();
    }

    return await this.newsRepository.save(news);
  }

  async getNewsByCategory(category: string, limit = 10): Promise<News[]> {
    return await this.newsRepository.find({
      where: { category: category as any, isActive: true },
      order: { publishedAt: 'DESC' },
      take: limit,
    });
  }

  async getNewsBySearch(query: string, limit = 10): Promise<News[]> {
    return await this.newsRepository.find({
      where: [
        { title: Like(`%${query}%`) },
        { content: Like(`%${query}%`) },
        { excerpt: Like(`%${query}%`) },
      ],
      order: { publishedAt: 'DESC' },
      take: limit,
    });
  }

  async getNewsById(id: string): Promise<News | null> {
    return await this.newsRepository.findOne({ where: { id } });
  }

  async getRecentNews(limit = 10): Promise<News[]> {
    return await this.newsRepository.find({
      where: { isActive: true },
      order: { publishedAt: 'DESC' },
      take: limit,
    });
  }

  async updateNews(id: string, newsData: Partial<News>): Promise<News | null> {
    const news = await this.newsRepository.findOne({ where: { id } });

    if (!news) {
      return null;
    }

    Object.assign(news, newsData);
    news.updatedAt = new Date();

    return await this.newsRepository.save(news);
  }

  async deleteNews(id: string): Promise<boolean> {
    const result = await this.newsRepository.delete(id);
    return result.affected !== 0;
  }

  async getTrendingNews(limit = 5): Promise<News[]> {
    // For now, we'll return the most recently published news
    // In a real implementation, we might factor in views, shares, etc.
    return await this.newsRepository.find({
      where: { isActive: true },
      order: { publishedAt: 'DESC' },
      take: limit,
    });
  }

  async getNewsByTags(tags: string[], limit = 10): Promise<News[]> {
    // Find news that contains any of the specified tags
    const allNews = await this.newsRepository.find({
      where: { isActive: true },
    });
    return allNews
      .filter(
        (news) => news.tags && news.tags.some((tag) => tags.includes(tag)),
      )
      .slice(0, limit);
  }
}
