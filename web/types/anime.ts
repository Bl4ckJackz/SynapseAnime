export type AnimeStatus = "ongoing" | "completed" | "upcoming";

export interface Anime {
  id: string;
  malId?: number;
  title: string;
  titleEnglish?: string;
  titleJapanese?: string;
  description: string;
  synopsis?: string;
  coverUrl?: string;
  bannerImage?: string;
  trailerUrl?: string;
  genres: string[];
  studios?: string[];
  status: AnimeStatus;
  duration?: string;
  type?: string;
  releaseYear: number;
  rating: number;
  popularity: number;
  totalEpisodes: number;
  createdAt: string;
}

export interface Episode {
  id: string;
  animeId: string;
  number: number;
  title: string;
  duration: number;
  thumbnail?: string;
  streamUrl: string;
  source?: string;
}

export interface AnimeSource {
  id: string;
  name: string;
  description: string;
  isActive: boolean;
}

export interface ReleaseSchedule {
  id: string;
  animeId: string;
  episodeNumber: number;
  releaseDate: string;
  notified: boolean;
}
