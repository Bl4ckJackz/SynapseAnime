import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_client.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/tv_show.dart';

/// Provider for movies/TV repository
final moviesTvRepositoryProvider = Provider<MoviesTvRepository>((ref) {
  return MoviesTvRepository(ref.watch(apiClientProvider));
});

class MoviesTvRepository {
  final ApiClient _apiClient;

  MoviesTvRepository(this._apiClient);

  /// Search movies by query
  Future<List<Movie>> searchMovies(String query) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/movies-tv/search',
      queryParameters: {'q': query, 'type': 'movie'},
    );
    final data = response.data?['results'] as List<dynamic>? ??
        response.data?['data'] as List<dynamic>? ??
        (response.data is List ? response.data as List<dynamic> : []);
    return data
        .map((json) => Movie.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Search TV shows by query
  Future<List<TvShow>> searchTvShows(String query) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/movies-tv/search',
      queryParameters: {'q': query, 'type': 'tv'},
    );
    final data = response.data?['results'] as List<dynamic>? ??
        response.data?['data'] as List<dynamic>? ??
        (response.data is List ? response.data as List<dynamic> : []);
    return data
        .map((json) => TvShow.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get trending movies
  Future<List<Movie>> getTrendingMovies() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/movies-tv/movies/trending',
    );
    final data = response.data?['results'] as List<dynamic>? ??
        response.data?['data'] as List<dynamic>? ??
        (response.data is List ? response.data as List<dynamic> : []);
    return data
        .map((json) => Movie.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get trending TV shows
  Future<List<TvShow>> getTrendingTvShows() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/movies-tv/tv/trending',
    );
    final data = response.data?['results'] as List<dynamic>? ??
        response.data?['data'] as List<dynamic>? ??
        (response.data is List ? response.data as List<dynamic> : []);
    return data
        .map((json) => TvShow.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get popular movies
  Future<List<Movie>> getPopularMovies() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/movies-tv/movies/popular',
    );
    final data = response.data?['results'] as List<dynamic>? ??
        response.data?['data'] as List<dynamic>? ??
        (response.data is List ? response.data as List<dynamic> : []);
    return data
        .map((json) => Movie.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get popular TV shows
  Future<List<TvShow>> getPopularTvShows() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/movies-tv/tv/popular',
    );
    final data = response.data?['results'] as List<dynamic>? ??
        response.data?['data'] as List<dynamic>? ??
        (response.data is List ? response.data as List<dynamic> : []);
    return data
        .map((json) => TvShow.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get movie details by TMDB ID
  Future<Movie> getMovieDetails(int tmdbId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/movies-tv/movies/$tmdbId',
    );
    final data = response.data?['data'] as Map<String, dynamic>? ??
        response.data ??
        <String, dynamic>{};
    return Movie.fromJson(data);
  }

  /// Get TV show details by TMDB ID
  Future<TvShow> getTvShowDetails(int tmdbId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/movies-tv/tv/$tmdbId',
    );
    final data = response.data?['data'] as Map<String, dynamic>? ??
        response.data ??
        <String, dynamic>{};
    return TvShow.fromJson(data);
  }

  /// Get episodes for a specific season
  Future<List<TvEpisode>> getSeasonEpisodes(int tmdbId, int season) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/movies-tv/tv/$tmdbId/season/$season',
    );
    final data = response.data?['episodes'] as List<dynamic>? ??
        response.data?['data'] as List<dynamic>? ??
        (response.data is List ? response.data as List<dynamic> : []);
    return data
        .map((json) => TvEpisode.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get movie stream URL
  Future<String> getMovieStreamUrl(int tmdbId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/movies-tv/stream/movie/$tmdbId',
    );
    return response.data?['embedUrl']?.toString() ??
        response.data?['url']?.toString() ??
        '';
  }

  /// Get TV show stream URL for a specific episode
  Future<String> getTvStreamUrl(
      int tmdbId, int season, int episode) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/movies-tv/stream/tv/$tmdbId/$season/$episode',
    );
    return response.data?['embedUrl']?.toString() ??
        response.data?['url']?.toString() ??
        '';
  }
}
