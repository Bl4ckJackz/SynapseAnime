import 'dart:convert';
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
      String endpoint;
      if (query.toLowerCase().contains('trending')) {
        endpoint = '${AppConstants.apiBaseUrl}/anime/animeunity/trending';
      } else if (query.toLowerCase().contains('popular')) {
        endpoint = '${AppConstants.apiBaseUrl}/anime/animeunity/popular';
      } else {
        endpoint =
            '${AppConstants.apiBaseUrl}/anime/animeunity/${Uri.encodeComponent(query)}';
      }

      print('Making request to: $endpoint');

      final response = await _apiClient.httpClient.get(Uri.parse(endpoint));

      print('Response status: ${response.statusCode}');
      if (response.body.length < 500) {
        // Only print short responses to avoid spam
        print('Response body: ${response.body}');
      } else {
        print('Response body: [${response.body.length} chars]');
      }

      if (response.statusCode == 200) {
        final jsonData =
            response.body.isNotEmpty ? json.decode(response.body) : {};

        if (jsonData is List) {
          return jsonData
              .map((item) => _parseAnimeFromAnimeWorld(item))
              .toList();
        } else if (jsonData.containsKey('results')) {
          final results = jsonData['results'] as List<dynamic>?;
          if (results != null) {
            return results
                .map((item) => _parseAnimeFromAnimeWorld(item))
                .toList();
          }
        }

        return [];
      } else {
        print('API request failed with status: ${response.statusCode}');
        return []; // Return empty list instead of throwing
      }
    } catch (e) {
      print('Error searching anime on AnimeWorld: $e');
      // Return empty list instead of throwing to prevent app crashes
      return [];
    }
  }

  /// Get anime details from AnimeWorld API
  Future<Anime> getAnimeDetails(String animeId) async {
    try {
      final endpoint =
          '${AppConstants.apiBaseUrl}/anime/animeunity/info?id=$animeId';

      print('Making request to: $endpoint');

      final response = await _apiClient.httpClient.get(Uri.parse(endpoint));

      print('Response status: ${response.statusCode}');
      if (response.body.length < 500) {
        // Only print short responses to avoid spam
        print('Response body: ${response.body}');
      } else {
        print('Response body: [${response.body.length} chars]');
      }

      if (response.statusCode == 200) {
        final jsonData =
            response.body.isNotEmpty ? json.decode(response.body) : {};
        return _parseDetailedAnimeFromAnimeWorld(jsonData);
      } else if (response.statusCode == 404) {
        print('Anime details not found for ID: $animeId');
        // Return a default anime object instead of throwing
        return Anime(
          id: animeId,
          title: 'Anime Not Found',
          description: 'Details not available',
          coverUrl: null,
          genres: [],
          status: AnimeStatus.ongoing,
          releaseYear: 0,
          rating: 0.0,
          totalEpisodes: 0,
        );
      } else {
        print('API request failed with status: ${response.statusCode}');
        // Return a default anime object instead of throwing
        return Anime(
          id: animeId,
          title: 'Error Loading',
          description: 'Could not load details',
          coverUrl: null,
          genres: [],
          status: AnimeStatus.ongoing,
          releaseYear: 0,
          rating: 0.0,
          totalEpisodes: 0,
        );
      }
    } catch (e) {
      print('Error getting anime details from AnimeWorld: $e');
      // Return a default anime object instead of throwing
      return Anime(
        id: animeId,
        title: 'Error Loading',
        description: 'Could not load details',
        coverUrl: null,
        genres: [],
        status: AnimeStatus.ongoing,
        releaseYear: 0,
        rating: 0.0,
        totalEpisodes: 0,
      );
    }
  }

  /// Gets streaming links for an anime episode from AnimeWorld API
  Future<AnimeWorldEpisodeResponse> getEpisodeStreamingLinks(
      String episodeId) async {
    try {
      final endpoint =
          '${AppConstants.apiBaseUrl}/anime/animeunity/watch/${Uri.encodeComponent(episodeId)}';

      print('Making request to: $endpoint');

      final response = await _apiClient.httpClient.get(Uri.parse(endpoint));

      print('Response status: ${response.statusCode}');
      if (response.body.length < 500) {
        // Only print short responses to avoid spam
        print('Response body: ${response.body}');
      } else {
        print('Response body: [${response.body.length} chars]');
      }

      if (response.statusCode == 200) {
        final jsonData =
            response.body.isNotEmpty ? json.decode(response.body) : {};

        // Parse the response - the structure might vary
        final sources = (jsonData['sources'] as List<dynamic>?)
                ?.map((source) => Source(
                      url: (source['url'] as dynamic)?.toString() ?? '',
                      quality: (source['quality'] as dynamic)?.toString() ??
                          'unknown',
                      isM3U8: source['isM3U8'] as bool? ?? false,
                    ))
                .toList() ??
            [];

        final downloadLink = (jsonData['download'] as dynamic)?.toString();

        return AnimeWorldEpisodeResponse(
          sources: sources,
          downloadLink: downloadLink,
        );
      } else if (response.statusCode == 404) {
        print('Episode streaming links not found for ID: $episodeId');
        // Return empty response instead of throwing
        return AnimeWorldEpisodeResponse(
          sources: [],
          downloadLink: null,
        );
      } else {
        print('API request failed with status: ${response.statusCode}');
        // Return empty response instead of throwing to prevent app crashes
        return AnimeWorldEpisodeResponse(
          sources: [],
          downloadLink: null,
        );
      }
    } catch (e) {
      print('Error fetching episode streaming links from AnimeWorld: $e');
      // Return empty response instead of throwing to prevent app crashes
      return AnimeWorldEpisodeResponse(
        sources: [],
        downloadLink: null,
      );
    }
  }

  // Helper method to parse anime from AnimeWorld API response
  Anime _parseAnimeFromAnimeWorld(dynamic item) {
    // Ensure item is a Map before accessing its properties
    if (item is! Map<String, dynamic>) {
      return Anime(
        id: '',
        title: 'Unknown Title',
        description: '',
        coverUrl: null,
        genres: [],
        status: AnimeStatus.ongoing,
        releaseYear: 0,
        rating: 0.0,
        totalEpisodes: 0,
      );
    }

    return Anime(
      id: (item['id'] as dynamic)?.toString() ??
          (item['link'] as dynamic)?.toString() ??
          '',
      title: (item['title'] as dynamic)?.toString() ??
          (item['name'] as dynamic)?.toString() ??
          'Unknown Title',
      description: (item['description'] as dynamic)?.toString() ?? '',
      coverUrl: (item['coverUrl'] as dynamic)?.toString() ??
          (item['image'] as dynamic)?.toString(),
      genres: _extractGenres(item['genres']),
      status: AnimeStatus
          .ongoing, // Default status, will be updated in detailed view
      releaseYear:
          int.tryParse((item['year'] as dynamic)?.toString() ?? '0') ?? 0,
      rating: double.tryParse((item['rating'] as dynamic)?.toString() ?? '0') ??
          0.0,
      totalEpisodes:
          int.tryParse((item['totalEpisodes'] as dynamic)?.toString() ?? '0') ??
              0,
    );
  }

  // Helper method to parse detailed anime from AnimeWorld API response
  Anime _parseDetailedAnimeFromAnimeWorld(dynamic item) {
    // Ensure item is a Map before accessing its properties
    if (item is! Map<String, dynamic>) {
      return Anime(
        id: '',
        title: 'Unknown Title',
        description: '',
        coverUrl: null,
        genres: [],
        status: AnimeStatus.ongoing,
        releaseYear: 0,
        rating: 0.0,
        totalEpisodes: 0,
      );
    }

    return Anime(
      id: (item['id'] as dynamic)?.toString() ??
          (item['link'] as dynamic)?.toString() ??
          '',
      title: (item['title'] as dynamic)?.toString() ??
          (item['name'] as dynamic)?.toString() ??
          'Unknown Title',
      description: (item['description'] as dynamic)?.toString() ?? '',
      coverUrl: (item['coverUrl'] as dynamic)?.toString() ??
          (item['image'] as dynamic)?.toString(),
      genres: _extractGenres(item['genres']),
      status: _parseStatus((item['status'] as dynamic)?.toString() ?? ''),
      releaseYear:
          int.tryParse((item['year'] as dynamic)?.toString() ?? '0') ?? 0,
      rating: double.tryParse((item['rating'] as dynamic)?.toString() ?? '0') ??
          0.0,
      totalEpisodes:
          int.tryParse((item['totalEpisodes'] as dynamic)?.toString() ?? '0') ??
              0,
    );
  }

  // Helper method to safely extract genres from API response
  List<String> _extractGenres(dynamic genresData) {
    if (genresData is List) {
      return genresData.map((e) => (e as dynamic)?.toString() ?? '').toList();
    } else if (genresData is String) {
      // If genres is a single string, wrap it in a list
      return [genresData];
    }
    return [];
  }

  // Helper to parse status from string
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
