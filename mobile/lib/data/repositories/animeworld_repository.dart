import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../api_client.dart';
import '../../domain/entities/anime.dart';

final animeWorldRepositoryProvider = Provider<AnimeWorldRepository>((ref) {
  return AnimeWorldRepository(ref.read(apiClientProvider));
});

class AnimeWorldRepository {
  final ApiClient _apiClient;

  AnimeWorldRepository(this._apiClient);

  /// Search for anime on AnimeWorld API
  Future<List<Anime>> searchAnime(String query) async {
    try {
      String path;
      if (query.toLowerCase().contains('trending')) {
        path = '/anime/animeunity/trending';
      } else if (query.toLowerCase().contains('popular')) {
        path = '/anime/animeunity/popular';
      } else {
        path = '/anime/animeunity/${Uri.encodeComponent(query)}';
      }

      final response = await _apiClient.get<dynamic>(path);
      final data = response.data;

      if (data is List) {
        return data
            .map((item) => _parseAnimeFromAnimeWorld(item))
            .toList();
      } else if (data is Map && data.containsKey('results')) {
        final results = data['results'] as List<dynamic>?;
        if (results != null) {
          return results
              .map((item) => _parseAnimeFromAnimeWorld(item))
              .toList();
        }
      }

      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('Error searching anime on AnimeWorld: $e');
      return [];
    }
  }

  /// Get anime details from AnimeWorld API
  Future<Anime> getAnimeDetails(String animeId) async {
    try {
      final response = await _apiClient.get<dynamic>(
        '/anime/animeunity/info',
        queryParameters: {'id': animeId},
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return _parseDetailedAnimeFromAnimeWorld(data);
      }

      return _defaultAnime(animeId, 'Anime Not Found');
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting anime details: $e');
      return _defaultAnime(animeId, 'Error Loading');
    }
  }

  /// Gets streaming links for an anime episode from AnimeWorld API
  Future<AnimeWorldEpisodeResponse> getEpisodeStreamingLinks(
      String episodeId) async {
    try {
      final response = await _apiClient.get<dynamic>(
        '/anime/animeunity/watch/${Uri.encodeComponent(episodeId)}',
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final sources = (data['sources'] as List<dynamic>?)
                ?.map((source) => Source(
                      url: source['url']?.toString() ?? '',
                      quality: source['quality']?.toString() ?? 'unknown',
                      isM3U8: source['isM3U8'] as bool? ?? false,
                    ))
                .toList() ??
            [];

        final downloadLink = data['download']?.toString();

        return AnimeWorldEpisodeResponse(
          sources: sources,
          downloadLink: downloadLink,
        );
      }

      return AnimeWorldEpisodeResponse(sources: [], downloadLink: null);
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching episode streams: $e');
      return AnimeWorldEpisodeResponse(sources: [], downloadLink: null);
    }
  }

  Anime _defaultAnime(String id, String title) {
    return Anime(
      id: id,
      title: title,
      description: '',
      coverUrl: null,
      genres: const [],
      status: AnimeStatus.ongoing,
      releaseYear: 0,
      rating: 0.0,
      totalEpisodes: 0,
    );
  }

  Anime _parseAnimeFromAnimeWorld(dynamic item) {
    if (item is! Map<String, dynamic>) {
      return _defaultAnime('', 'Unknown Title');
    }

    return Anime(
      id: item['id']?.toString() ?? item['link']?.toString() ?? '',
      title: item['title']?.toString() ?? item['name']?.toString() ?? 'Unknown Title',
      description: item['description']?.toString() ?? '',
      coverUrl: item['coverUrl']?.toString() ?? item['image']?.toString(),
      genres: _extractGenres(item['genres']),
      status: AnimeStatus.ongoing,
      releaseYear: int.tryParse(item['year']?.toString() ?? '0') ?? 0,
      rating: double.tryParse(item['rating']?.toString() ?? '0') ?? 0.0,
      totalEpisodes: int.tryParse(item['totalEpisodes']?.toString() ?? '0') ?? 0,
    );
  }

  Anime _parseDetailedAnimeFromAnimeWorld(dynamic item) {
    if (item is! Map<String, dynamic>) {
      return _defaultAnime('', 'Unknown Title');
    }

    return Anime(
      id: item['id']?.toString() ?? item['link']?.toString() ?? '',
      title: item['title']?.toString() ?? item['name']?.toString() ?? 'Unknown Title',
      description: item['description']?.toString() ?? '',
      coverUrl: item['coverUrl']?.toString() ?? item['image']?.toString(),
      genres: _extractGenres(item['genres']),
      status: _parseStatus(item['status']?.toString() ?? ''),
      releaseYear: int.tryParse(item['year']?.toString() ?? '0') ?? 0,
      rating: double.tryParse(item['rating']?.toString() ?? '0') ?? 0.0,
      totalEpisodes: int.tryParse(item['totalEpisodes']?.toString() ?? '0') ?? 0,
    );
  }

  List<String> _extractGenres(dynamic genresData) {
    if (genresData is List) {
      return genresData.map((e) => e?.toString() ?? '').toList();
    } else if (genresData is String) {
      return [genresData];
    }
    return [];
  }

  AnimeStatus _parseStatus(String status) {
    final lowerStatus = status.toLowerCase();
    if (lowerStatus.contains('completed') || lowerStatus.contains('finished')) {
      return AnimeStatus.completed;
    }
    return AnimeStatus.ongoing;
  }
}

class AnimeWorldEpisodeResponse {
  final List<Source> sources;
  final String? downloadLink;

  AnimeWorldEpisodeResponse({
    required this.sources,
    this.downloadLink,
  });
}

class Source {
  final String url;
  final String quality;
  final bool isM3U8;

  Source({
    required this.url,
    required this.quality,
    required this.isM3U8,
  });
}
