import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_client.dart';
import 'package:dio/dio.dart';
import '../../core/constants.dart';
import '../../core/utils/api_helpers.dart';
import '../../core/utils/title_matcher.dart';
import '../../domain/entities/manga.dart';
import '../../domain/entities/chapter.dart';
import '../../core/config/source_config.dart';

/// Provider for manga repository
final mangaRepositoryProvider = Provider<MangaRepository>((ref) {
  return MangaRepository(ref.watch(apiClientProvider));
});

/// Manga repository for API calls
class SourceSearchResult {
  final String source;
  final List<MangaChapter> chapters;
  final int matchScore;

  SourceSearchResult(this.source, this.chapters, this.matchScore);
}

class MangaRepository {
  final ApiClient _apiClient;

  MangaRepository(this._apiClient);

  String? _activeSource;

  Future<void> setActiveSource(String sourceId) async {
    _activeSource = sourceId;
  }

  String getActiveSource() {
    return _activeSource ?? 'jikan'; // Default to Jikan for metadata if not set
  }

  /// Get top manga from Jikan
  Future<List<Manga>> getTopManga(
      {int page = 1, String? type, int limit = 20}) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.jikanMangaTop,
        queryParameters: {
          'page': page,
          if (type != null) 'type': type,
        },
      );
      return ApiHelpers.parseAndMap(response.data, Manga.fromJikanJson)
          .take(limit)
          .toList();
    } catch (e) {
      ApiHelpers.logError('getTopManga', e);
      return [];
    }
  }

  /// Search manga via Jikan or Active Source
  Future<List<Manga>> searchManga(String query, {int page = 1}) async {
    final active = getActiveSource();

    // If active source is Jikan, use Jikan (Metadata rich)
    if (active == 'jikan') {
      try {
        final response = await _apiClient.get<Map<String, dynamic>>(
          AppConstants.jikanMangaSearch,
          queryParameters: {'q': query, 'page': page},
        );
        return ApiHelpers.parseAndMap(response.data, Manga.fromJikanJson);
      } catch (e) {
        ApiHelpers.logError('searchManga(jikan)', e);
        return [];
      }
    } else {
      // Search on the active source (Consumet)
      // This allows finding content specific to that source (e.g. Manhwa on MangaWorld)
      final results = await _searchOnSource(active, query);

      // Map generic results to Manga entities
      return results.map((e) {
        return Manga(
          id: e['id'].toString(),
          title: e['title'].toString(),
          synopsis: e['description']?.toString() ?? '',
          coverUrl: e['image']?.toString() ?? '',
          genres: [],
          status: MangaStatus.ongoing, // Unknown
          score: 0.0,
          authors: [],
          source: active,
        );
      }).toList();
    }
  }

  /// Get manga details from Jikan by MAL ID
  Future<Manga> getMangaDetails(String id) async {
    try {
      if (RegExp(r'^\d+$').hasMatch(id)) {
        // Jikan
        // Jikan
        try {
          final response = await _apiClient.get<Map<String, dynamic>>(
            '/jikan/manga/$id/full',
          );
          // Backend might return unwrapped DTO, or Jikan raw wrapped in 'data'
          final data = response.data?['data'] ?? response.data;

          if (data == null || (data is Map && data.isEmpty)) {
            throw Exception('Manga data is null/empty from /full endpoint');
          }
          return Manga.fromJikanJson(data as Map<String, dynamic>);
        } catch (e) {
          // Check if we should fallback (404 or null data)
          bool shouldFallback = false;
          if (e is DioException && e.response?.statusCode == 404) {
            shouldFallback = true;
          } else if (e.toString().contains('Manga data')) {
            shouldFallback = true;
          }

          if (shouldFallback) {
            final response = await _apiClient.get<Map<String, dynamic>>(
              '/jikan/manga/$id',
            );

            // Backend might return unwrapped DTO, or Jikan raw wrapped in 'data'
            final data = response.data?['data'] ?? response.data;

            if (data == null || (data is Map && data.isEmpty)) {
              if (e is DioException && e.response?.statusCode == 404) rethrow;
              throw Exception('Manga data not found in fallback');
            }
            // Basic validation: ensure it looks like manga data (has mal_id or malId)
            if (data['malId'] == null && data['mal_id'] == null) {
              // If completely invalid/empty
              if (e is DioException && e.response?.statusCode == 404) rethrow;
              throw Exception('Invalid manga data in fallback');
            }

            return Manga.fromJikanJson(data as Map<String, dynamic>);
          }
          rethrow;
        }
      } else {
        // MangaDex
        final response = await _apiClient.get('/mangadex/manga/$id');
        final data = ApiHelpers.parseMapResponse(response.data);
        if (data == null) throw Exception('MangaDex returned null data');
        return Manga.fromMangaDexJson(data);
      }
    } catch (e) {
      throw Exception('Failed to load manga details: $e');
    }
  }

  /// Get manga list from MangaHook
  Future<List<Manga>> getMangaHookList(
      {int page = 1, String? type, String? category}) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.mangahookMangaList,
        queryParameters: {
          'page': page,
          if (type != null) 'type': type,
          if (category != null) 'category': category,
        },
      );
      return ApiHelpers.parseAndMap(response.data, Manga.fromMangaHookJson);
    } catch (e) {
      ApiHelpers.logError('getMangaHookList', e);
      return [];
    }
  }

  /// Get available manga sources - prioritized for EN content first
  List<String> get availableSources {
    final defaultOrder = [
      'mangaworld', // Italian/Global
      'mangakatana',
      'mangasee',
      'mangahere',
      'mangapill',
      'asurascans',
      'mangadex',
      'mangareader',
      'mangakakalot',
      'weebcentral',
      'comick', // Moved to last due to frequent 404s/API issues
    ];

    return defaultOrder
        .where((id) => SourceConfig.isMangaSourceEnabled(id))
        .toList();
  }

  /// Get manga chapters using multi-source fallback
  Future<List<MangaChapter>> getChapters(String mangaId,
      {String? title, String? titleEnglish, String? preferredSource}) async {
    // Override preferredSource with active source if set and not 'jikan'
    final active = getActiveSource();
    if (active != 'jikan') {
      preferredSource = active;
    }
    // 1. Determine titles to search
    final titlesToTry = <String>{};
    if (title != null && title.isNotEmpty) titlesToTry.add(title);
    if (titleEnglish != null && titleEnglish.isNotEmpty)
      titlesToTry.add(titleEnglish);
    // Add variations if needed
    if (title != null && title.contains(':')) {
      titlesToTry.add(title.replaceAll(':', ''));
    }

    // DEBUG: Fetch Jikan Reference if ID is numeric
    Manga? jikanRef;
    if (RegExp(r'^\d+$').hasMatch(mangaId)) {
      try {
        jikanRef = await getMangaDetails(mangaId);
        if (kDebugMode) debugPrint(
            'DEBUG: Fetched Jikan Ref for matching: ${jikanRef.title} (Year: ${jikanRef.year}, Authors: ${jikanRef.authors})');
      } catch (e) {
        if (kDebugMode) debugPrint('DEBUG: Failed to fetch Jikan Ref: $e');
      }
    }

    // 2. Determine source order
    List<String> sources = List.from(availableSources);
    if (preferredSource != null && availableSources.contains(preferredSource)) {
      sources.remove(preferredSource);
      sources.insert(0, preferredSource);
    }

    if (kDebugMode) debugPrint(
        'DEBUG: getChapters called for $mangaId (Title: $title, TitleENG: $titleEnglish, Pref: $preferredSource)');

    // 3. Smart Fetch Strategy
    // If strict preference, just use that.
    if (preferredSource != null) {
      final result = await _fetchFromOneSource(
          preferredSource, mangaId, titlesToTry.toList());
      return result.chapters;
    }

    // Auto Mode: Parallel Race for top candidates
    int parallelCount = 3;
    final primarySources = sources.take(parallelCount).toList();
    final fallbackSources = sources.skip(parallelCount).toList();

    if (kDebugMode) debugPrint(
        'DEBUG: Auto Mode - Probing top $parallelCount sources: $primarySources');

    final results = await Future.wait(
      primarySources.map((source) => _getChaptersFromSource(
          source, mangaId, titlesToTry.toList(),
          refManga: jikanRef)),
    );

    // Filter valid results
    final candidates = results.where((r) => r.chapters.isNotEmpty).toList();

    if (candidates.isNotEmpty) {
      // PRIMARY SELECTION LOGIC
      // Sort by Match Score Descending
      candidates.sort((a, b) => b.matchScore.compareTo(a.matchScore));

      final bestCandidate = candidates.first;

      // If the best candidate has a "Perfect" or "Very High" score, and significantly better than others, take it.
      // E.g. 1950 vs 100.

      if (kDebugMode) debugPrint('DEBUG: Candidates ranked by score:');
      for (var c in candidates) {
        if (kDebugMode) debugPrint(
            ' - ${c.source}: Score ${c.matchScore}, Chapters ${c.chapters.length}');
      }

      // Selection Strategy:
      SourceSearchResult winner = bestCandidate;

      // Check if runner-up has comparable score but MORE chapters
      // Only verify against highly relevant matches (e.g. score > 800)
      if (candidates.length > 1) {
        for (int i = 1; i < candidates.length; i++) {
          final other = candidates[i];

          // If the score difference is significant, stick with the better match.
          // Lowered threshold to 150 to prevent 250 vs 50 swaps.
          if ((winner.matchScore - other.matchScore) > 150) {
            continue; // Winner is clearly better match
          }

          // CRITICAL: Never switch to a candidate with a very low score (< 100)
          // just because it has more chapters. It's likely an unrelated series
          // matching a common word (e.g. "no").
          if (other.matchScore < 100) {
            continue;
          }

          // If scores are relatively close (and the other isn't garbage), prefer chapter count
          if (other.chapters.length > winner.chapters.length) {
            // Switch winner if chapter count is better
            winner = other;
          }
        }
      }

      // FINAL SAFETY CHECK:
      // If the winner has a very low score (e.g. < 500) and it's not a direct ID lookup (2000),
      // we might want to be careful. But for now, we trust the relative ranking.

      if (kDebugMode) debugPrint(
          'DEBUG: Winner source is ${winner.source} with ${winner.chapters.length} chapters (Score: ${winner.matchScore})');

      // FINAL THRESHOLD CHECK
      // If the best match is still too weak (e.g. < 150), treat it as "Not Found"
      // to avoid showing completely wrong anime/manga.
      if (winner.matchScore < 150) {
        if (kDebugMode) debugPrint(
            'DEBUG: Winner rejected due to low score (< 150). Returning empty.');
        return [];
      }

      return _sanitizeChapters(winner.chapters);
    }

    // Fallback logic
    if (kDebugMode) debugPrint(
        'DEBUG: Primary sources failed. Trying fallback sources: $fallbackSources');
    for (final source in fallbackSources) {
      final result = await _getChaptersFromSource(
          source, mangaId, titlesToTry.toList(),
          refManga: jikanRef);
      if (result.chapters.isNotEmpty) {
        // In fallback, ensure we have a decent match
        if (result.matchScore >= 150 || result.matchScore == 2000) {
          return _sanitizeChapters(result.chapters);
        }
        if (kDebugMode) debugPrint(
            'DEBUG: Skipped fallback source $source due to low score: ${result.matchScore}');
      }
    }

    return [];
  }

  /// Sanitize chapters: Remove duplicates and sort by number (descending)
  List<MangaChapter> _sanitizeChapters(List<MangaChapter> chapters) {
    if (chapters.isEmpty) return [];

    // 1. Deduplicate by chapter number
    final uniqueChapters = <double, MangaChapter>{};
    for (final chapter in chapters) {
      if (chapter.number != null) {
        if (!uniqueChapters.containsKey(chapter.number) ||
            (uniqueChapters[chapter.number]!.title.length >
                chapter.title.length)) {
          uniqueChapters[chapter.number!] = chapter;
        }
      } else {
        uniqueChapters[-1.0 * chapter.hashCode] = chapter;
      }
    }

    // 2. Sort by number descending (newest first)
    final sorted = uniqueChapters.values.toList()
      ..sort((a, b) {
        final numA = a.number ?? 0;
        final numB = b.number ?? 0;
        return numA.compareTo(numB);
      });

    return sorted;
  }

  Future<SourceSearchResult> _fetchFromOneSource(
      String source, String mangaId, List<String> titles) async {
    try {
      final result = await _getChaptersFromSource(source, mangaId, titles);
      return SourceSearchResult(
          source, _sanitizeChapters(result.chapters), result.matchScore);
    } catch (e) {
      if (kDebugMode) debugPrint("DEBUG: Single source fetch failed: $e");
      return SourceSearchResult(source, [], -1);
    }
  }

  // Helper class for results
  // We'll define it here or outside. For simplicity keeping it implicit via logic or defining small class.
  // Actually, let's just make _getChaptersFromSource return SourceSearchResult directly.

  Future<SourceSearchResult> _getChaptersFromSource(
      String source, String originalId, List<String> searchTitles,
      {Manga? refManga}) async {
    String? targetId;
    int obtainedScore = 0;

    // Resolve ID
    if (source == 'mangadex' && !RegExp(r'^\d+$').hasMatch(originalId)) {
      targetId = originalId;
      obtainedScore = 2000; // TRUSTED DIRECT ID
      if (kDebugMode) debugPrint('DEBUG: Using original ID for MangaDex: $targetId (Score: 2000)');
    } else {
      // Need to search
      if (kDebugMode) debugPrint('DEBUG: Searching on $source with queries: $searchTitles');

      Map<String, dynamic>? bestGlobalMatch;
      int bestGlobalScore = -1;

      for (final query in searchTitles) {
        try {
          final results = await _searchOnSource(source, query);
          if (results.isNotEmpty) {
            final bestMatch =
                _findBestMatch(results, query, refManga: refManga);
            final int score = bestMatch['_score'] as int? ?? 0;

            if (score > bestGlobalScore) {
              bestGlobalScore = score;
              bestGlobalMatch = bestMatch;
            }
            if (score >= 1000) break;
          }
        } catch (e) {
          // ignore search error
        }
      }

      if (bestGlobalMatch != null) {
        targetId = bestGlobalMatch['id'].toString();
        obtainedScore = bestGlobalScore;
        if (kDebugMode) debugPrint(
            'DEBUG: Best Global Match on $source: ${bestGlobalMatch['title']} (score: $bestGlobalScore)');
      }
    }

    if (targetId == null) {
      return SourceSearchResult(source, [], -1);
    }

    // Safety: If score is very low, maybe don't even fetch chapters?
    // Let's allow fetching but let `getChapters` decide to discard.

    List<MangaChapter> fetchedChapters = [];

    try {
      // Use backend endpoint for MangaDex
      if (source == 'mangadex') {
        final url = '/mangadex/manga/$targetId/chapters?lang=en';
        final response = await _apiClient.get(url);
        final data = response.data;
        final List<dynamic> chaptersRaw = data is List
            ? data
            : (data is Map
                ? (data['chapters'] ?? data['data'] ?? <dynamic>[])
                : <dynamic>[]) as List<dynamic>;

        fetchedChapters = chaptersRaw.map((json) {
          final chapterNum = _parseChapterNumberFromBackend(json);
          return MangaChapter(
            id: 'mangadex:${json['mangadexChapterId'] ?? json['id']}',
            mangaId: originalId,
            title: json['title'] ?? 'Chapter $chapterNum',
            number: chapterNum,
            volume: json['volume'] != null
                ? (json['volume'] is int
                    ? json['volume']
                    : int.tryParse(json['volume'].toString()))
                : null,
          );
        }).toList();
      } else {
        // Consumet
        final url = _buildInfoUrl(source, targetId);
        final response = await _apiClient.get(url);
        final data = response.data;
        final chaptersRaw = ApiHelpers.parseListResponse(
            data, dataKey: 'chapters');

        fetchedChapters = chaptersRaw
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
    } catch (e) {
      if (kDebugMode) debugPrint('DEBUG: Error fetching chapters for $source: $e');
      return SourceSearchResult(source, [], obtainedScore);
    }

    return SourceSearchResult(source, fetchedChapters, obtainedScore);
  }

  double _parseChapterNumberFromBackend(Map<String, dynamic> json) {
    if (json['number'] != null) {
      return (json['number'] is num)
          ? (json['number'] as num).toDouble()
          : double.tryParse(json['number'].toString()) ?? 0.0;
    }
    return 0.0;
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

  Future<List<Map<String, dynamic>>> _searchOnSource(
      String source, String query) async {
    // For MangaDex, use our Backend Controller
    if (source == 'mangadex') {
      try {
        final response = await _apiClient.get('${AppConstants.mangadexSearch}',
            queryParameters: {'q': query});
        // The backend returns { data: Manga[], ... } or Manga[] directly depending on implementation
        // Controller searchManga returns `this.mangaDexService.searchManga(query)` which returns `Promise<Manga[]>`
        // So response.data is List<dynamic> (mangas).

        final data = response.data;
        final List<dynamic> list =
            data is List ? data : (data['data'] as List<dynamic>? ?? []);

        // Map to format expected by _findBestMatch (must have 'id' and 'title')
        return list
            .map((m) {
              if (m is! Map) return <String, dynamic>{};
              return <String, dynamic>{
                'id': (m['mangadexId'] ?? m['id'])?.toString() ?? '',
                'title': m['title']?.toString() ?? '',
                'description': m['description']?.toString() ?? '',
                'year': m['year'],
                'authors': m['authors'], // List<String> or List<Map>
                'status': m['status'],
              };
            })
            .where((m) => m['id'].toString().isNotEmpty)
            .toList();
      } catch (e) {
        if (kDebugMode) debugPrint('DEBUG: Backend Mangadex Search failed: $e');
        // Fallback to Consumet logic below? Or just return empty
        return [];
      }
    }

    final provider = _mapSourceToProvider(source);
    try {
      final response = await _apiClient.get(
        '${AppConstants.consumetBaseUrl}/manga/$provider/${Uri.encodeComponent(query)}',
      );
      final results = ApiHelpers.parseListResponse(
          response.data, dataKey: 'results');
      return results
          .whereType<Map<dynamic, dynamic>>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    } catch (e) {
      ApiHelpers.logError('_searchOnSource($source)', e);
      return [];
    }
  }

  Future<List<Manga>> searchMangaOnMangaDex(String query) async {
    try {
      final response = await _apiClient.get(
        '${AppConstants.consumetBaseUrl}/manga/mangadex/$query',
      );
      return ApiHelpers.parseAndMap(
        response.data,
        Manga.fromMangaDexJson,
        dataKey: 'results',
      );
    } catch (e) {
      ApiHelpers.logError('searchMangaOnMangaDex', e);
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

      if (kDebugMode) debugPrint('Fetching pages for $actualChapterId from $source');

      // Use Backend for MangaDex reading
      if (source == 'mangadex') {
        final url = '/mangadex/chapter/$actualChapterId/pages';
        if (kDebugMode) debugPrint('DEBUG: Fetching pages from backend: $url');
        final response = await _apiClient.get(url);
        final data = response.data;
        // Backend returns { images: [...] }
        final images = ApiHelpers.parseListResponse(data, dataKey: 'images');
        return images.map((e) => e.toString()).toList();
      }

      final url = _buildReadUrl(source, actualChapterId);
      if (kDebugMode) debugPrint('DEBUG: Fetching pages from $url');

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

      final pages = pagesRaw
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

      if (kDebugMode) debugPrint('DEBUG: Extracted ${pages.length} pages from response');
      return pages;
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching pages: $e');
      return [];
    }
  }

  // Helper to map source names (fixing typos in API)
  String _mapSourceToProvider(String source) {
    if (source == 'mangareader')
      return 'mangareader'; // Consumet usually uses 'mangareader'
    return source;
  }

  // Helper to build info URL based on provider
  String _buildInfoUrl(String source, String id) {
    final provider = _mapSourceToProvider(source);

    // Providers using path params: /info/{id}
    const pathParamSources = {
      'mangadex',
      'comick',
      'asurascans',
      'weebcentral'
    };

    if (pathParamSources.contains(source)) {
      return '${AppConstants.consumetBaseUrl}/manga/$provider/info/$id';
    } else {
      // Providers using query params: /info?id={id}
      // mangareader, mangakakalot, mangahere, mangapill
      return '${AppConstants.consumetBaseUrl}/manga/$provider/info?id=$id';
    }
  }

  // Helper to build read URL based on provider
  String _buildReadUrl(String source, String chapterId) {
    final provider = _mapSourceToProvider(source);

    // Providers using path params: /read/{chapterId}
    const pathParamSources = {
      'mangadex',
      'comick',
      'asurascans',
      'weebcentral'
    };

    if (pathParamSources.contains(source)) {
      return '${AppConstants.consumetBaseUrl}/manga/$provider/read/$chapterId';
    } else {
      // Providers using query params: /read?chapterId={chapterId}
      return '${AppConstants.consumetBaseUrl}/manga/$provider/read?chapterId=$chapterId';
    }
  }

  /// Get trending manga from Jikan (popular filter)
  Future<List<Manga>> getTrendingManga({int limit = 20, int page = 1}) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.jikanMangaTop,
        queryParameters: {'filter': 'bypopularity', 'page': page},
      );
      return ApiHelpers.parseAndMap(response.data, Manga.fromJikanJson)
          .take(limit)
          .toList();
    } catch (e) {
      ApiHelpers.logError('getTrendingManga', e);
      return getTopManga(limit: limit, page: page);
    }
  }

  /// Get recently updated manga
  Future<List<Manga>> getRecentlyUpdatedManga(
      {int limit = 20, int page = 1}) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.jikanMangaTop,
        queryParameters: {'page': page},
      );
      return ApiHelpers.parseAndMap(response.data, Manga.fromJikanJson)
          .take(limit)
          .toList();
    } catch (e) {
      ApiHelpers.logError('getRecentlyUpdatedManga', e);
      return getTopManga(limit: limit, page: page);
    }
  }

  /// Get manga genres from Jikan
  Future<List<Map<String, dynamic>>> getGenres() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        AppConstants.jikanMangaGenres,
      );
      final list = ApiHelpers.parseListResponse(response.data);
      return list
          .whereType<Map<dynamic, dynamic>>()
          .map((g) => Map<String, dynamic>.from(g))
          .toList();
    } catch (e) {
      ApiHelpers.logError('getGenres', e);
      return [];
    }
  }

  /// Find best match from search results using shared TitleMatcher scoring.
  Map<String, dynamic> _findBestMatch(
      List<Map<String, dynamic>> results, String query,
      {Manga? refManga}) {
    return TitleMatcher.findBestMangaMatch(
      results,
      query,
      referenceYear: refManga?.year,
      referenceAuthors: refManga?.authors,
    );
  }
}
