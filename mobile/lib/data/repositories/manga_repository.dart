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
  /// Get available manga sources
  List<String> get availableSources =>
      ['mangadex', 'mangareader', 'mangakakalot'];

  /// Get manga chapters using multi-source fallback
  Future<List<MangaChapter>> getChapters(String mangaId,
      {String? title, String? titleEnglish, String? preferredSource}) async {
    // 1. Determine titles to search
    final titlesToTry = <String>{};
    if (title != null && title.isNotEmpty) titlesToTry.add(title);
    if (titleEnglish != null && titleEnglish.isNotEmpty)
      titlesToTry.add(titleEnglish);
    // Add variations if needed (e.g. removing special chars)

    // 2. Determine source order
    List<String> sources = List.from(availableSources);
    if (preferredSource != null && availableSources.contains(preferredSource)) {
      sources.remove(preferredSource);
      sources.insert(0, preferredSource);
    }

    print(
        'DEBUG: getChapters called for $mangaId (Title: $title, TitleENG: $titleEnglish, Pref: $preferredSource)');
    print('DEBUG: Sources order: $sources');

    // 3. Iterate through sources
    for (final source in sources) {
      try {
        print('DEBUG: Trying source: $source');
        final chapters =
            await _getChaptersFromSource(source, mangaId, titlesToTry.toList());

        if (chapters.isNotEmpty) {
          print(
              'DEBUG: SUCCESS - Fetched ${chapters.length} chapters from $source');
          return chapters;
        } else {
          print('DEBUG: No chapters found on $source');
        }
      } catch (e) {
        print('DEBUG: Failed to fetch from $source: $e');
        // Continue to next source
      }
    }

    print('DEBUG: All sources failed or returned empty.');
    return [];
  }

  Future<List<MangaChapter>> _getChaptersFromSource(
      String source, String originalId, List<String> searchTitles) async {
    String? targetId;

    // Resolve ID: If originalId is numeric (Jikan), we MUST search.
    // If it's not numeric, it might be a specific ID for that source, but safer to search if source differs.
    // For simplicity: If source is 'mangadex' and ID looks like UUID, usage it.
    // If source is others, usually we need to search unless we stored the ID mapping.

    if (source == 'mangadex' && !RegExp(r'^\d+$').hasMatch(originalId)) {
      // Assume originalId is already a MangaDex ID if not numeric (and reasonable length)
      // But Jikan ID is numeric. content IDs are strings.
      targetId = originalId;
      print('DEBUG: Using original ID for MangaDex: $targetId');
    } else {
      // Need to search
      print('DEBUG: Searching on $source with queries: $searchTitles');
      for (final query in searchTitles) {
        try {
          final results = await _searchOnSource(source, query);
          if (results.isNotEmpty) {
            // Find best match
            final exactMatch = results.firstWhere(
              (m) => m['title'].toString().toLowerCase() == query.toLowerCase(),
              orElse: () => results.first,
            );
            targetId = exactMatch['id'].toString();
            print(
                'DEBUG: Found match on $source: ${exactMatch['title']} ($targetId)');
            break;
          }
        } catch (e) {
          print('DEBUG: Search failed on $source for $query: $e');
        }
      }
    }

    if (targetId == null) {
      print('DEBUG: Could not resolve ID for $source');
      return [];
    }

    if (targetId == null) {
      print('DEBUG: Could not resolve ID for $source');
      return [];
    }

    // Fetch Info (Chapters)
    final url = _buildInfoUrl(source, targetId);
    print('DEBUG: Fetching info from $url');

    final response = await _apiClient.get(url);

    final data = response.data;
    final chaptersRaw = data['chapters'] as List<dynamic>? ?? [];

    // MangaDex specific filtering
    if (source == 'mangadex') {
      return chaptersRaw
          .where((json) {
            final lang = (json['language'] as String? ?? '').toLowerCase();
            // Prefer IT, then EN
            return lang == 'it' ||
                lang == 'en' ||
                lang == 'gb' ||
                lang == ''; // relax filter
          })
          .map((json) {
            return MangaChapter(
              id: '$source:${json['id']}', // Prefix ID
              mangaId: originalId,
              title: json['title'] ??
                  'Chapter ${json['chapterNumber'] ?? json['number']}',
              number: _parseChapterNumber(json),
            );
          })
          .toList()
          .reversed
          .toList();
    }

    // Generic mapping
    return chaptersRaw
        .map((json) {
          return MangaChapter(
            id: '$source:${json['id']}',
            mangaId: originalId,
            title: json['title'] ??
                'Chapter ${json['chapterNumber'] ?? json['number']}',
            number: _parseChapterNumber(json),
          );
        })
        .toList()
        .reversed
        .toList();
  }

  double _parseChapterNumber(Map<String, dynamic> json) {
    if (json['chapterNumber'] != null)
      return double.tryParse(json['chapterNumber'].toString()) ?? 0.0;
    if (json['number'] != null)
      return double.tryParse(json['number'].toString()) ?? 0.0;

    // Fallback: extract from title
    final title = (json['title'] ?? '').toString();
    // Match "Chapter 123", "Ch. 123", "123" etc.
    final match = RegExp(r'(?:Chapter|Ch\.|Ep\.|Vol\.)?\s*(\d+(?:\.\d+)?)',
            caseSensitive: false)
        .firstMatch(title);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 0.0;
    }
    return 0.0;
  }

  Future<List<dynamic>> _searchOnSource(String source, String query) async {
    final provider = _mapSourceToProvider(source);
    final response = await _apiClient.get(
      '${AppConstants.consumetBaseUrl}/manga/$provider/${Uri.encodeComponent(query)}',
    );
    return response.data['results'] as List<dynamic>? ?? [];
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
  /// Get chapter pages using source prefix in chapterID
  Future<List<String>> getChapterPages(String mangaId, String chapterId) async {
    try {
      String source = 'mangadex'; // default
      String actualChapterId = chapterId;

      if (chapterId.contains(':')) {
        final parts = chapterId.split(':');
        // Handle source prefix
        if (availableSources.contains(parts[0])) {
          source = parts[0];
          actualChapterId = parts.sublist(1).join(':');
        }
      }

      print('Fetching pages for $actualChapterId from $source');

      final url = _buildReadUrl(source, actualChapterId);
      print('DEBUG: Fetching pages from $url');

      final response = await _apiClient.get(url);

      // Consumet response standardization attempt
      // Usually returns list of objects { img: url } or { url: url } or just string urls
      // Key might be 'results', 'images', 'pages', 'data'

      final data = response.data;
      List<dynamic> pagesRaw = [];

      if (data is List) {
        pagesRaw = data;
      } else if (data is Map<String, dynamic>) {
        if (data.containsKey('results') && data['results'] is List)
          pagesRaw = data['results'];
        else if (data.containsKey('images') && data['images'] is List)
          pagesRaw = data['images'];
        else if (data.containsKey('pages') && data['pages'] is List)
          pagesRaw = data['pages'];
        else if (data.containsKey('data') && data['data'] is List)
          pagesRaw = data['data'];
      }

      return pagesRaw
          .map((page) {
            if (page is String) return page;
            if (page is Map<String, dynamic>) {
              return (page['img'] ?? page['url'] ?? page['link'] ?? '')
                  .toString();
            }
            return '';
          })
          .where((url) => url.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error fetching pages: $e');
      return [];
    }
  }

  // Helper to map source names (fixing typos in API)
  String _mapSourceToProvider(String source) {
    if (source == 'mangareader') return 'managreader'; // Fix API typo
    return source;
  }

  // Helper to build info URL based on provider
  String _buildInfoUrl(String source, String id) {
    final provider = _mapSourceToProvider(source);
    if (source == 'mangadex') {
      return '${AppConstants.consumetBaseUrl}/manga/$provider/info/$id';
    } else {
      // MangaReader, MangaKakalot etc use query params
      return '${AppConstants.consumetBaseUrl}/manga/$provider/info?id=$id';
    }
  }

  // Helper to build read URL based on provider
  String _buildReadUrl(String source, String chapterId) {
    final provider = _mapSourceToProvider(source);
    if (source == 'mangadex') {
      return '${AppConstants.consumetBaseUrl}/manga/$provider/read/$chapterId';
    } else {
      // MangaReader, MangaKakalot etc use query params
      return '${AppConstants.consumetBaseUrl}/manga/$provider/read?chapterId=$chapterId';
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
