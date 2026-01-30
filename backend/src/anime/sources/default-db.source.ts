import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Like } from 'typeorm';
import {
  AnimeSource,
  AnimeFilters,
  PaginatedResult,
} from './anime-source.interface';
import { Anime, AnimeStatus } from '../../entities/anime.entity';
import { Episode } from '../../entities/episode.entity';

@Injectable()
export class DefaultDbSource implements AnimeSource {
  readonly id = 'default_db';
  readonly name = 'Demo Database';
  readonly description = 'Mocked data for demonstration purposes';
  readonly hasDirectStream = true;

  constructor(
    @InjectRepository(Anime)
    private animeRepository: Repository<Anime>,
    @InjectRepository(Episode)
    private episodeRepository: Repository<Episode>,
  ) {}

  async getAnimeList(filters: AnimeFilters): Promise<PaginatedResult<Anime>> {
    // For now, return mock data to avoid database issues
    const mockAnime: Anime[] = [
      {
        id: '1',
        malId: 38000,
        title: 'Demon Slayer',
        titleEnglish: 'Kimetsu no Yaiba',
        titleJapanese: '鬼滅の刃',
        description: 'A boy becomes a demon slayer to save his sister',
        synopsis: 'Tanjiro Kamado sets out to become a demon slayer after his family is slaughtered and his sister turned into a demon.',
        coverUrl:
          'https://placehold.co/300x450/ff6b6b/ffffff?text=Demon+Slayer',
        bannerImage: 'https://placehold.co/800x450/ff6b6b/ffffff?text=Demon+Slayer+Banner',
        trailerUrl: 'https://example.com/trailer/demon-slayer',
        genres: ['Action', 'Fantasy', 'Supernatural'],
        studios: ['Ufotable'],
        status: AnimeStatus.COMPLETED,
        type: 'TV',
        releaseYear: 2019,
        aired: { from: new Date('2019-04-06'), to: new Date('2019-09-28') },
        rating: 8.7,
        popularity: 1000,
        totalEpisodes: 12,
        streamingSources: [],
        createdAt: new Date(),
        episodes: [],
        watchlist: [],
        releaseSchedules: [],
      },
      {
        id: '2',
        malId: 16498,
        title: 'Attack on Titan',
        titleEnglish: 'Shingeki no Kyojin',
        titleJapanese: '進撃の巨人',
        description: 'Humanity fights for survival against giant humanoid Titans',
        synopsis: 'After his hometown is destroyed and his mother killed, young Eren Jaeger joins the military to fight back against the Titans.',
        coverUrl: 'https://placehold.co/300x450/4ecdc4/ffffff?text=Attack+Titan',
        bannerImage: 'https://placehold.co/800x450/4ecdc4/ffffff?text=Attack+Titan+Banner',
        trailerUrl: 'https://example.com/trailer/attack-titan',
        genres: ['Action', 'Drama', 'Fantasy'],
        studios: ['Mappa', 'Wit Studio'],
        status: AnimeStatus.COMPLETED,
        type: 'TV',
        releaseYear: 2013,
        aired: { from: new Date('2013-04-07'), to: new Date('2023-11-05') },
        rating: 9.0,
        popularity: 900,
        totalEpisodes: 89,
        streamingSources: [],
        createdAt: new Date(),
        episodes: [],
        watchlist: [],
        releaseSchedules: [],
      },
      {
        id: '3',
        malId: 31964,
        title: 'My Hero Academia',
        titleEnglish: 'Boku no Hero Academia',
        titleJapanese: '僕のヒーローアカデミア',
        description: 'A quirkless boy tries to become a hero in a world of superheroes',
        synopsis: 'A young man without powers dreams of becoming a hero in a world where everyone has special abilities.',
        coverUrl: 'https://placehold.co/300x450/45b7d1/ffffff?text=My+Hero+Aca',
        bannerImage: 'https://placehold.co/800x450/45b7d1/ffffff?text=My+Hero+Academia+Banner',
        trailerUrl: 'https://example.com/trailer/my-hero-academia',
        genres: ['Action', 'School', 'Superhero'],
        studios: ['Bones'],
        status: AnimeStatus.ONGOING,
        type: 'TV',
        releaseYear: 2016,
        aired: { from: new Date('2016-04-03'), to: new Date('2026-03-30') }, // Assuming ongoing
        rating: 8.5,
        popularity: 800,
        totalEpisodes: 138,
        streamingSources: [],
        createdAt: new Date(),
        episodes: [],
        watchlist: [],
        releaseSchedules: [],
      },
      {
        id: '4',
        malId: 21,
        title: 'One Piece',
        titleEnglish: 'One Piece',
        titleJapanese: 'ワンピース',
        description: 'A pirate captain searches for the ultimate treasure',
        synopsis: 'Monkey D. Luffy wants to become the King of all pirates by finding the legendary treasure called "One Piece".',
        coverUrl: 'https://placehold.co/300x450/f9ca24/ffffff?text=One+Piece',
        bannerImage: 'https://placehold.co/800x450/f9ca24/ffffff?text=One+Piece+Banner',
        trailerUrl: 'https://example.com/trailer/one-piece',
        genres: ['Action', 'Adventure', 'Comedy'],
        studios: ['Toei Animation'],
        status: AnimeStatus.ONGOING,
        type: 'TV',
        releaseYear: 1999,
        aired: { from: new Date('1999-10-20'), to: new Date('2026-03-30') }, // Assuming ongoing
        rating: 9.2,
        popularity: 1200,
        totalEpisodes: 1000, // Ongoing series
        streamingSources: [],
        createdAt: new Date(),
        episodes: [],
        watchlist: [],
        releaseSchedules: [],
      },
      {
        id: '5',
        malId: 1535,
        title: 'Death Note',
        titleEnglish: 'Death Note',
        titleJapanese: 'デスノート',
        description: 'A high school student gains the power to kill with a supernatural notebook',
        synopsis: 'A high school student discovers a supernatural notebook that grants him the power to kill anyone whose name is written in it.',
        coverUrl: 'https://placehold.co/300x450/6c5ce7/ffffff?text=Death+Note',
        bannerImage: 'https://placehold.co/800x450/6c5ce7/ffffff?text=Death+Note+Banner',
        trailerUrl: 'https://example.com/trailer/death-note',
        genres: ['Thriller', 'Psychological', 'Supernatural'],
        studios: ['Madhouse'],
        status: AnimeStatus.COMPLETED,
        type: 'TV',
        releaseYear: 2006,
        aired: { from: new Date('2006-10-04'), to: new Date('2007-06-27') },
        rating: 9.0,
        popularity: 1100,
        totalEpisodes: 37,
        streamingSources: [],
        createdAt: new Date(),
        episodes: [],
        watchlist: [],
        releaseSchedules: [],
      },
    ];

    // Apply basic filtering
    let filtered = mockAnime;
    if (filters.genre) {
      filtered = filtered.filter((anime) =>
        anime.genres.some((genre) =>
          genre.toLowerCase().includes(filters.genre!.toLowerCase()),
        ),
      );
    }

    if (filters.search) {
      filtered = filtered.filter(
        (anime) =>
          anime.title.toLowerCase().includes(filters.search!.toLowerCase()) ||
          anime.description
            .toLowerCase()
            .includes(filters.search!.toLowerCase()),
      );
    }

    if (filters.status) {
      filtered = filtered.filter((anime) => anime.status === filters.status);
    }

    const start = ((filters.page || 1) - 1) * (filters.limit || 20);
    const end = start + (filters.limit || 20);
    const data = filtered.slice(start, end);

    return {
      data,
      total: filtered.length,
      page: filters.page || 1,
      limit: filters.limit || 20,
      totalPages: Math.ceil(filtered.length / (filters.limit || 20)),
    };
  }

  async getAnimeById(id: string): Promise<Anime | null> {
    // Return mock data for now
    const mockAnime = await this.getAnimeList({ page: 1, limit: 100 });
    return mockAnime.data.find((anime) => anime.id === id) || null;
  }

  async getEpisodes(animeId: string): Promise<Episode[]> {
    // Return mock episodes
    const mockEpisodes: Episode[] = [
      {
        id: `${animeId}_ep_1`,
        animeId,
        number: 1,
        title: `Episode 1: Introduction`,
        duration: 1320, // 22 minutes in seconds
        thumbnail: `https://placehold.co/320x180/ff6b6b/ffffff?text=EP+1`,
        streamUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        anime: null as any, // Will be populated by TypeORM if needed
      },
      {
        id: `${animeId}_ep_2`,
        animeId,
        number: 2,
        title: `Episode 2: Development`,
        duration: 1320, // 22 minutes in seconds
        thumbnail: `https://placehold.co/320x180/4ecdc4/ffffff?text=EP+2`,
        streamUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        anime: null as any, // Will be populated by TypeORM if needed
      },
      {
        id: `${animeId}_ep_3`,
        animeId,
        number: 3,
        title: `Episode 3: Climax`,
        duration: 1320, // 22 minutes in seconds
        thumbnail: `https://placehold.co/320x180/45b7d1/ffffff?text=EP+3`,
        streamUrl:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
        anime: null as any, // Will be populated by TypeORM if needed
      },
    ];
    return mockEpisodes;
  }

  async getStreamUrl(episodeId: string): Promise<string> {
    // Return a sample stream URL
    return 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
  }
}
