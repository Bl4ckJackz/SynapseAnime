import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/movies_tv_repository.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/tv_show.dart';

// --- Movie Providers ---

final trendingMoviesProvider =
    FutureProvider.autoDispose<List<Movie>>((ref) async {
  final repository = ref.watch(moviesTvRepositoryProvider);
  return repository.getTrendingMovies();
});

final popularMoviesProvider =
    FutureProvider.autoDispose<List<Movie>>((ref) async {
  final repository = ref.watch(moviesTvRepositoryProvider);
  return repository.getPopularMovies();
});

final movieDetailsProvider =
    FutureProvider.autoDispose.family<Movie, int>((ref, tmdbId) async {
  final repository = ref.watch(moviesTvRepositoryProvider);
  return repository.getMovieDetails(tmdbId);
});

final movieSearchProvider =
    FutureProvider.autoDispose.family<List<Movie>, String>((ref, query) async {
  final repository = ref.watch(moviesTvRepositoryProvider);
  return repository.searchMovies(query);
});

final movieStreamUrlProvider =
    FutureProvider.autoDispose.family<String, int>((ref, tmdbId) async {
  final repository = ref.watch(moviesTvRepositoryProvider);
  return repository.getMovieStreamUrl(tmdbId);
});

// --- TV Show Providers ---

final trendingTvShowsProvider =
    FutureProvider.autoDispose<List<TvShow>>((ref) async {
  final repository = ref.watch(moviesTvRepositoryProvider);
  return repository.getTrendingTvShows();
});

final popularTvShowsProvider =
    FutureProvider.autoDispose<List<TvShow>>((ref) async {
  final repository = ref.watch(moviesTvRepositoryProvider);
  return repository.getPopularTvShows();
});

final tvShowDetailsProvider =
    FutureProvider.autoDispose.family<TvShow, int>((ref, tmdbId) async {
  final repository = ref.watch(moviesTvRepositoryProvider);
  return repository.getTvShowDetails(tmdbId);
});

final tvShowSearchProvider =
    FutureProvider.autoDispose
        .family<List<TvShow>, String>((ref, query) async {
  final repository = ref.watch(moviesTvRepositoryProvider);
  return repository.searchTvShows(query);
});

// --- Season Episodes Provider ---

class SeasonEpisodesKey {
  final int tmdbId;
  final int season;

  const SeasonEpisodesKey({required this.tmdbId, required this.season});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeasonEpisodesKey &&
          runtimeType == other.runtimeType &&
          tmdbId == other.tmdbId &&
          season == other.season;

  @override
  int get hashCode => tmdbId.hashCode ^ season.hashCode;
}

final seasonEpisodesProvider = FutureProvider.autoDispose
    .family<List<TvEpisode>, SeasonEpisodesKey>((ref, key) async {
  final repository = ref.watch(moviesTvRepositoryProvider);
  return repository.getSeasonEpisodes(key.tmdbId, key.season);
});

// --- TV Stream URL Provider ---

class TvStreamKey {
  final int tmdbId;
  final int season;
  final int episode;

  const TvStreamKey({
    required this.tmdbId,
    required this.season,
    required this.episode,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TvStreamKey &&
          runtimeType == other.runtimeType &&
          tmdbId == other.tmdbId &&
          season == other.season &&
          episode == other.episode;

  @override
  int get hashCode =>
      tmdbId.hashCode ^ season.hashCode ^ episode.hashCode;
}

final tvStreamUrlProvider = FutureProvider.autoDispose
    .family<String, TvStreamKey>((ref, key) async {
  final repository = ref.watch(moviesTvRepositoryProvider);
  return repository.getTvStreamUrl(key.tmdbId, key.season, key.episode);
});

// --- Search Query State ---

final moviesTvSearchQueryProvider = StateProvider<String>((ref) => '');
