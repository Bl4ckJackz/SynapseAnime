import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/utils/api_helpers.dart';
import '../../domain/entities/anime.dart';
import '../../domain/entities/episode.dart';
import '../api_client.dart';

final consumetRepositoryProvider = Provider<ConsumetRepository>((ref) {
  return ConsumetRepository(ref.read(apiClientProvider));
});

/// Repository for Consumet API interactions (anime streaming sources).
/// Handles search, info, episode listing, and stream URL resolution
/// for providers like animeunity, gogoanime, etc.
class ConsumetRepository {
  final ApiClient _apiClient;

  ConsumetRepository(this._apiClient);

  String get _baseUrl => AppConstants.consumetBaseUrl;

  /// Search anime on a specific Consumet provider.
  Future<List<Map<String, dynamic>>> searchAnime(
      String query, String provider) async {
    try {
      final response = await _apiClient.get<dynamic>(
        '$_baseUrl/anime/$provider/${Uri.encodeComponent(query)}',
      );
      final results = ApiHelpers.parseListResponse(
          response.data, dataKey: 'results');
      return results
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      ApiHelpers.logError('ConsumetRepository.searchAnime($provider)', e);
      return [];
    }
  }

  /// Get anime info (details + episode list) from a Consumet provider.
  Future<Map<String, dynamic>?> getAnimeInfo(
      String animeId, String provider) async {
    try {
      final response = await _apiClient.get<dynamic>(
        '$_baseUrl/anime/$provider/info',
        queryParameters: {'id': animeId},
      );
      return ApiHelpers.parseMapResponse(response.data);
    } catch (e) {
      ApiHelpers.logError('ConsumetRepository.getAnimeInfo($provider)', e);
      return null;
    }
  }

  /// Get episode list from anime info response.
  Future<List<Map<String, dynamic>>> getEpisodes(
      String animeId, String provider) async {
    final info = await getAnimeInfo(animeId, provider);
    if (info == null) return [];

    final episodes = info['episodes'];
    if (episodes is! List) return [];

    return episodes
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// Get streaming links for a specific episode.
  Future<Map<String, dynamic>?> getStreamingLinks(
      String episodeId, String provider) async {
    try {
      final response = await _apiClient.get<dynamic>(
        '$_baseUrl/anime/$provider/watch/$episodeId',
      );
      return ApiHelpers.parseMapResponse(response.data);
    } catch (e) {
      ApiHelpers.logError('ConsumetRepository.getStreamingLinks($provider)', e);
      return null;
    }
  }

  /// Get recent episodes from a Consumet provider.
  Future<List<Episode>> getRecentEpisodes(
      String provider, {int page = 1}) async {
    try {
      final response = await _apiClient.get<dynamic>(
        '$_baseUrl/anime/$provider/recent-episodes',
        queryParameters: {'page': page},
      );

      final results = ApiHelpers.parseListResponse(
          response.data, dataKey: 'results');

      return results.map((e) {
        if (e is! Map<String, dynamic>) return null;

        final rawId = e['id']?.toString() ?? '';
        final rawTitle = e['title']?.toString();
        final episodeNum = (e['episodeNumber'] as num?)?.toInt() ?? 0;

        String displayTitle = rawTitle ?? '';
        if (displayTitle.isEmpty ||
            displayTitle.toLowerCase().startsWith('episode')) {
          displayTitle = rawId
              .replaceAll('-', ' ')
              .replaceAll(RegExp(r'\d+$'), '')
              .trim();
          if (displayTitle.isNotEmpty) {
            displayTitle = displayTitle[0].toUpperCase() +
                displayTitle.substring(1);
          }
        }

        return Episode(
          id: e['episodeId']?.toString() ?? rawId,
          animeId: rawId,
          number: episodeNum,
          title: displayTitle,
          thumbnail: e['image']?.toString(),
          duration: 0,
          streamUrl: '',
        );
      }).whereType<Episode>().toList();
    } catch (e) {
      ApiHelpers.logError('ConsumetRepository.getRecentEpisodes($provider)', e);
      return [];
    }
  }

  /// Get top airing anime from a Consumet provider.
  Future<List<Anime>> getTopAiring(String provider, {int page = 1}) async {
    try {
      final response = await _apiClient.get<dynamic>(
        '$_baseUrl/anime/$provider/top-airing',
        queryParameters: {'page': page},
      );

      final results = ApiHelpers.parseListResponse(
          response.data, dataKey: 'results');

      return results.map((e) {
        if (e is! Map<String, dynamic>) return null;
        return Anime.fromJson(e);
      }).whereType<Anime>().toList();
    } catch (e) {
      ApiHelpers.logError('ConsumetRepository.getTopAiring($provider)', e);
      return [];
    }
  }

  /// Resolve the best stream URL from streaming links.
  /// Returns {url, quality, isM3U8, headers} or null.
  Future<Map<String, dynamic>?> resolveStreamUrl(
      String episodeId, String provider) async {
    final links = await getStreamingLinks(episodeId, provider);
    if (links == null) return null;

    final sources = links['sources'];
    if (sources is! List || sources.isEmpty) return null;

    // Prefer highest quality non-backup source
    Map<String, dynamic>? best;
    for (final source in sources) {
      if (source is! Map<String, dynamic>) continue;
      final quality = source['quality']?.toString() ?? '';

      if (best == null) {
        best = source;
        continue;
      }

      // Prefer 1080p > 720p > default > backup
      if (quality.contains('1080')) {
        best = source;
        break;
      } else if (quality.contains('720') &&
          !(best['quality']?.toString().contains('1080') ?? false)) {
        best = source;
      }
    }

    if (best == null) return null;

    return {
      'url': best['url']?.toString(),
      'quality': best['quality']?.toString() ?? 'default',
      'isM3U8': best['isM3U8'] ?? true,
      'headers': links['headers'] ?? {},
    };
  }
}
