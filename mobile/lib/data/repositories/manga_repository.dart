import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_client.dart';
import '../../core/constants.dart';
import '../../domain/entities/manga.dart';
import '../../domain/entities/chapter.dart';

/// Provider for manga repository
final mangaRepositoryProvider = Provider<MangaRepository>((ref) {
  return MangaRepository(ref.watch(apiClientProvider));
});

/// Manga repository for API calls
class MangaRepository {
  final ApiClient _apiClient;

  MangaRepository(this._apiClient);

  /// Get top manga from Jikan
  Future<List<Manga>> getTopManga(
      {int page = 1, String? type, int limit = 20}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      AppConstants.jikanMangaTop,
      queryParameters: {
        'page': page,
        if (type != null) 'type': type,
      },
    );

    final data = (response.data?['data'] as List<dynamic>? ?? []);
    return data
        .take(limit)
        .map((json) => Manga.fromJikanJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Search manga via Jikan
  Future<List<Manga>> searchManga(String query, {int page = 1}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      AppConstants.jikanMangaSearch,
      queryParameters: {
        'q': query,
        'page': page,
      },
    );

    final data = response.data?['data'] as List<dynamic>? ?? [];
    return data
        .map((json) => Manga.fromJikanJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get manga details from Jikan by MAL ID
  Future<Manga> getMangaDetails(String id) async {
    try {
      if (RegExp(r'^\d+$').hasMatch(id)) {
        // Jikan
        final response = await _apiClient.get<Map<String, dynamic>>(
          '/jikan/manga/$id',
        );
        return Manga.fromJikanJson(response.data ?? {});
      } else {
        // MangaDex
        final response = await _apiClient.get('/mangadex/manga/$id');
        return Manga.fromMangaDexJson(response.data as Map<String, dynamic>);
      }
    } catch (e) {
      throw Exception('Failed to load manga details: $e');
    }
  }

  /// Get manga list from MangaHook
  Future<List<Manga>> getMangaHookList(
      {int page = 1, String? type, String? category}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      AppConstants.mangahookMangaList,
      queryParameters: {
        'page': page,
        if (type != null) 'type': type,
        if (category != null) 'category': category,
      },
    );

    final data = response.data?['data'] as List<dynamic>? ?? [];
    return data
        .map((json) => Manga.fromMangaHookJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get manga chapters (Switching to MangaDex via search)
  /// If [mangaId] is numeric (Jikan/MAL ID), we search MangaDex by [title] to get the correct ID.
  /// Get manga chapters from Consumet Manga API with MangaReader fallback
  Future<List<MangaChapter>> getChapters(String mangaId,
      {String? title, String? titleEnglish}) async {
    // Try MangaDex first
    final mangaDexChapters = await _getChaptersFromMangaDex(mangaId, title: title, titleEnglish: titleEnglish);
    if (mangaDexChapters.isNotEmpty) {
      return mangaDexChapters;
    }
    
    // Fallback to MangaReader
    print('MangaDex failed, trying MangaReader fallback for: ${title ?? mangaId}');
    return _getChaptersFromMangaReader(title ?? titleEnglish ?? mangaId);
  }

  /// Internal: Get chapters from MangaDex
  Future<List<MangaChapter>> _getChaptersFromMangaDex(String mangaId,
      {String? title, String? titleEnglish}) async {
    try {
      String targetId = mangaId;

      // If it looks like a Jikan ID (numeric), resolve MangaDex ID via search
      if (RegExp(r'^\d+$').hasMatch(mangaId)) {
        final searchResults =
            await searchMangaOnMangaDex(title ?? titleEnglish ?? '');
        if (searchResults.isNotEmpty) {
          targetId = searchResults[0].id;
        } else {
          return [];
        }
      }

      final response = await _apiClient.get(
        '${AppConstants.consumetBaseUrl}/manga/mangadex/info/$targetId',
      );

      final data = response.data;
      final chaptersRaw = data['chapters'] as List<dynamic>? ?? [];

      // Filter chapters by language (e.g., prefer 'it', then 'en')
      final filteredChapters = chaptersRaw.where((json) {
        final lang = (json['language'] as String? ?? '').toLowerCase();
        return lang.isEmpty || lang == 'it' || lang == 'en' || lang == 'gb';
      }).toList();

      final displayChapters =
          filteredChapters.isEmpty ? chaptersRaw : filteredChapters;

      return displayChapters
          .map((json) {
            return MangaChapter(
              id: json['id'].toString(),
              mangaId: targetId,
              title: json['title'] ??
                  'Chapter ${json['chapterNumber'] ?? json['number']}',
              number: double.tryParse(
                      (json['chapterNumber'] ?? json['number'] ?? 0)
                          .toString()) ??
                  0.0,
            );
          })
          .toList()
          .reversed
          .toList();
    } catch (e) {
      print('Error fetching chapters from MangaDex: $e');
      return [];
    }
  }

  /// Internal: Get chapters from MangaReader (fallback)
  Future<List<MangaChapter>> _getChaptersFromMangaReader(String query) async {
    try {
      // Search for manga on MangaReader
      final searchResponse = await _apiClient.get(
        '${AppConstants.consumetBaseUrl}/manga/mangareader/${Uri.encodeComponent(query)}',
      );

      final results = searchResponse.data['results'] as List<dynamic>? ?? [];
      if (results.isEmpty) return [];

      final mangaReaderId = results.first['id'].toString();
      print('Found MangaReader manga: $mangaReaderId');

      // Get manga info with chapters
      final infoResponse = await _apiClient.get(
        '${AppConstants.consumetBaseUrl}/manga/mangareader/info/$mangaReaderId',
      );

      final chaptersRaw = infoResponse.data['chapters'] as List<dynamic>? ?? [];

      return chaptersRaw.map((json) {
        return MangaChapter(
          id: 'mangareader:${json['id']}', // Prefix to identify source
          mangaId: mangaReaderId,
          title: json['title'] ?? 'Chapter ${json['chapterNumber'] ?? json['number']}',
          number: double.tryParse(
                  (json['chapterNumber'] ?? json['number'] ?? 0).toString()) ??
              0.0,
        );
      }).toList().reversed.toList();
    } catch (e) {
      print('Error fetching chapters from MangaReader: $e');
      return [];
    }
  }

  Future<List<Manga>> searchMangaOnMangaDex(String query) async {
    try {
      final response = await _apiClient.get(
        '${AppConstants.consumetBaseUrl}/manga/mangadex/$query',
      );

      final List<dynamic> results =
          response.data['results'] as List<dynamic>? ??
              (response.data is List ? response.data : []);

      return results
          .map<Manga>((e) => Manga.fromMangaDexJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error searching MangaDex via Consumet: $e');
      return [];
    }
  }

  /// Get chapter pages from Consumet Manga API (handles both MangaDex and MangaReader)
  Future<List<String>> getChapterPages(String mangaId, String chapterId) async {
    try {
      // Check if this is a MangaReader chapter
      if (chapterId.startsWith('mangareader:')) {
        final actualChapterId = chapterId.replaceFirst('mangareader:', '');
        return _getChapterPagesFromMangaReader(actualChapterId);
      }
      
      // Default: MangaDex
      final response = await _apiClient.get(
        '${AppConstants.consumetBaseUrl}/manga/mangadex/read/$chapterId',
      );

      // Consumet usually returns a list of { page: 1, img: "..." } or similar
      final List<dynamic> images = response.data is List
          ? response.data
          : (response.data['results'] ?? []);

      return images.map((img) => img['img'].toString()).toList();
    } catch (e) {
      print('Error fetching pages: $e');
      return [];
    }
  }

  /// Internal: Get chapter pages from MangaReader
  Future<List<String>> _getChapterPagesFromMangaReader(String chapterId) async {
    try {
      final response = await _apiClient.get(
        '${AppConstants.consumetBaseUrl}/manga/mangareader/read/$chapterId',
      );

      final List<dynamic> images = response.data is List
          ? response.data
          : (response.data['results'] ?? response.data['pages'] ?? []);

      return images.map((img) {
        if (img is String) return img;
        return (img['img'] ?? img['url'] ?? '').toString();
      }).where((url) => url.isNotEmpty).toList();
    } catch (e) {
      print('Error fetching pages from MangaReader: $e');
      return [];
    }
  }

  /// Get trending manga from Jikan (popular filter)
  Future<List<Manga>> getTrendingManga({int limit = 20}) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.jikanMangaTop,
        queryParameters: {
          'filter': 'bypopularity',
          'page': 1,
        },
      );
      final data = (response.data?['data'] as List<dynamic>? ?? []);
      return data
          .take(limit)
          .map((json) => Manga.fromJikanJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return getTopManga(limit: limit);
    }
  }

  /// Get recently updated manga (Using MangaDex search proxy)
  Future<List<Manga>> getRecentlyUpdatedManga({int limit = 20}) async {
    try {
      // In a real scenario, we'd have a specific endpoint.
      // For now, search MangaDex with empty query or similar if supported,
      // or just use page 2 of top manga for variety.
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.jikanMangaTop,
        queryParameters: {
          'page': 2,
        },
      );
      final data = (response.data?['data'] as List<dynamic>? ?? []);
      return data
          .take(limit)
          .map((json) => Manga.fromJikanJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return getTopManga(limit: limit);
    }
  }

  /// Get manga genres from Jikan
  Future<List<Map<String, dynamic>>> getGenres() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      AppConstants.jikanMangaGenres,
    );

    return (response.data?['data'] as List<dynamic>? ?? [])
        .map((g) => g as Map<String, dynamic>)
        .toList();
  }
}
