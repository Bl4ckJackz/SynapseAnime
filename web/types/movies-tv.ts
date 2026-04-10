export interface Movie {
  id: number;
  title: string;
  originalTitle?: string;
  overview?: string;
  posterPath?: string;
  backdropPath?: string;
  voteAverage: number;
  voteCount: number;
  releaseDate?: string;
  genreIds: number[];
  genres: string[];
  runtime?: number;
  tagline?: string;
  cast: CastMember[];
  similar: Movie[];
  imdbId?: string;
}

export interface TvShow {
  id: number;
  name: string;
  originalName?: string;
  overview?: string;
  posterPath?: string;
  backdropPath?: string;
  voteAverage: number;
  numberOfSeasons: number;
  numberOfEpisodes: number;
  genres: string[];
  firstAirDate?: string;
  cast: CastMember[];
  similar: TvShow[];
}

export interface TvEpisode {
  id: number;
  episodeNumber: number;
  seasonNumber: number;
  name: string;
  overview?: string;
  stillPath?: string;
  airDate?: string;
  runtime?: number;
  voteAverage: number;
}

export interface CastMember {
  name: string;
  character?: string;
  profilePath?: string;
}
