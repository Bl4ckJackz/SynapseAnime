import { Anime } from '../../entities/anime.entity';
import { Episode } from '../../entities/episode.entity';

export interface AnimeFilters {
  genre?: string;
  status?: string;
  search?: string;
  page?: number;
  limit?: number;
  filter?: string;
}

export interface PaginatedResult<T> {
  data: T[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

export interface AnimeSource {
  readonly id: string;
  readonly name: string;
  readonly description: string;

  getAnimeList(filters: AnimeFilters): Promise<PaginatedResult<Anime>>;
  getAnimeById(id: string): Promise<Anime | null>;
  getEpisodes(animeId: string): Promise<Episode[]>;
  getStreamUrl(episodeId: string): Promise<string>;

  readonly hasDirectStream: boolean;
  getExternalLink?(anime: Anime): string;

  // Optional schedule method for sources that support it
  getSchedule?(day?: string): Promise<PaginatedResult<Anime>>;
}
