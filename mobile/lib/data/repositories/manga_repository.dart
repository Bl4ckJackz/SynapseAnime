import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_client.dart';
import '../../core/constants.dart';
import '../../domain/entities/manga.dart';
import '../../domain/entities/chapter.dart';
import '../../core/config/source_config.dart';

/// Provider for manga repository
final mangaRepositoryProvider = Provider<MangaRepository>((ref) {
  return MangaRepository(ref.watch(apiClientProvider));
});

/// Manga repository for API calls
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

  /// Search manga via Jikan or Active Source
  Future<List<Manga>> searchManga(String query, {int page = 1}) async {
    final active = getActiveSource();

    // If active source is Jikan, use Jikan (Metadata rich)
    if (active == 'jikan') {
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

  /// Get available manga sources - prioritized for EN content first
  List<String> get availableSources {
    final defaultOrder = [
      'mangaworld', // Italian/Global
      'mangakatana',
      'mangasee',
      'comick',
      'mangahere',
      'mangapill',
      'asurascans',
      'mangadex',
      'mangareader',
      'mangakakalot',
      'weebcentral',
    ];

    return defaultOrder
        .where((id) => SourceConfig.isMangaSourceEnabled(id))
        .toList();
  }

  /// Get manga chapters using multi-source fallback
  Future<List<MangaChapter>> getChapters(String mangaId,
      {String? title, String? titleEnglish, String? preferredSource}) async {
    // Override preferredSource with active source if set and not 'jikan'
    // 'jikan' is not a reading source, so we shouldn't force it as preference for chapters
    final active = getActiveSource();
    if (active != 'jikan') {
      preferredSource = active;
    }
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
    // 3. Smart Fetch Strategy
    // If strict preference, just use that.
    if (preferredSource != null) {
      return await _fetchFromOneSource(
          preferredSource, mangaId, titlesToTry.toList());
    }

    // Auto Mode: "Parallel Race" for top candidates
    // We try the top 3 sources in parallel and pick the one with most chapters
    int parallelCount = 3;
    final primarySources = sources.take(parallelCount).toList();
    final fallbackSources = sources.skip(parallelCount).toList();

    print(
        'DEBUG: Auto Mode - Probing top $parallelCount sources: $primarySources');

    final results = await Future.wait(
      primarySources.map((source) =>
          _getChaptersFromSource(source, mangaId, titlesToTry.toList())),
    );

    // Filter results and find the best one
    List<MangaChapter> bestChapters = [];
    String bestSource = 'none';

    for (int i = 0; i < results.length; i++) {
      final chapters = _sanitizeChapters(results[i]); // Sanitize here
      final source = primarySources[i];

      if (chapters.isNotEmpty) {
        print('DEBUG: Source $source found ${chapters.length} chapters');
        if (chapters.length > bestChapters.length) {
          bestChapters = chapters;
          bestSource = source;
        }
      }
    }

    if (bestChapters.isNotEmpty) {
      print(
          'DEBUG: Winner source is $bestSource with ${bestChapters.length} chapters');
      return bestChapters;
    }

    // If primary sources failed, try fallback sources sequentially
    print(
        'DEBUG: Primary sources failed. Trying fallback sources: $fallbackSources');
    for (final source in fallbackSources) {
      final chapters =
          await _getChaptersFromSource(source, mangaId, titlesToTry.toList());
      if (chapters.isNotEmpty) {
        return _sanitizeChapters(chapters);
      }
    }

    print('DEBUG: All sources failed or returned empty.');
    return [];
  }

  Future<List<MangaChapter>> _fetchFromOneSource(
      String source, String mangaId, List<String> titles) async {
    try {
      final chapters = await _getChaptersFromSource(source, mangaId, titles);
      return _sanitizeChapters(chapters);
    } catch (e) {
      print("DEBUG: Single source fetch failed: $e");
      return [];
    }
  }

  /// Sanitize chapters: Remove duplicates and sort by number (descending)
  List<MangaChapter> _sanitizeChapters(List<MangaChapter> chapters) {
    if (chapters.isEmpty) return [];

    // 1. Deduplicate by chapter number
    final uniqueChapters = <double, MangaChapter>{};
    for (final chapter in chapters) {
      if (chapter.number != null) {
        // If duplicate, keep the one with a shorter/cleaner title or existing logic
        if (!uniqueChapters.containsKey(chapter.number) ||
            (uniqueChapters[chapter.number]!.title.length >
                chapter.title.length)) {
          uniqueChapters[chapter.number!] = chapter;
        }
      } else {
        // Keep chapters without numbers (rare)
        // We'll use ID as key to fallback
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

      Map<String, dynamic>? bestGlobalMatch;
      int bestGlobalScore = -1;

      for (final query in searchTitles) {
        try {
          final results = await _searchOnSource(source, query);
          if (results.isNotEmpty) {
            // _searchOnSource returns List<Map<String, dynamic>> directly
            final bestMatch = _findBestMatch(results, query);

            final int score = bestMatch['_score'] as int? ?? 0;
            print(
                'DEBUG: Match for "$query": ${bestMatch['title']} (score: $score)');

            // Update global best if this is better
            if (score > bestGlobalScore) {
              bestGlobalScore = score;
              bestGlobalMatch = bestMatch;
            }

            // If we found a perfect match, stop searching
            if (score >= 1000) {
              print('DEBUG: Found perfect match, stopping search');
              break;
            }
          }
        } catch (e) {
          print('DEBUG: Search failed on $source for $query: $e');
        }
      }

      if (bestGlobalMatch != null) {
        targetId = bestGlobalMatch['id'].toString();
        print(
            'DEBUG: Best Global Match on $source: ${bestGlobalMatch['title']} (score: $bestGlobalScore) ($targetId)');
      }
    }

    if (targetId == null) {
      print('DEBUG: Could not resolve ID for $source');
      return [];
    }

    // Use backend endpoint for MangaDex (has full pagination)
    if (source == 'mangadex') {
      final url = '/mangadex/manga/$targetId/chapters?lang=en';
      print('DEBUG: Fetching chapters from backend: $url');

      final response = await _apiClient.get(url);
      final data = response.data;

      // Backend returns array of Chapter objects directly
      final chaptersRaw = data is List
          ? data
          : (data['chapters'] ?? data['data'] ?? []) as List<dynamic>;

      print('DEBUG: Backend returned ${chaptersRaw.length} chapters');

      return chaptersRaw.map((json) {
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
    }

    // For other sources, use Consumet API
    final url = _buildInfoUrl(source, targetId);
    print('DEBUG: Fetching info from $url');

    final response = await _apiClient.get(url);

    final data = response.data;
    final chaptersRaw = data['chapters'] as List<dynamic>? ?? [];

    // Generic mapping for non-MangaDex sources
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
              };
            })
            .where((m) => m['id'].toString().isNotEmpty)
            .toList();
      } catch (e) {
        print('DEBUG: Backend Mangadex Search failed: $e');
        // Fallback to Consumet logic below? Or just return empty
        return [];
      }
    }

    final provider = _mapSourceToProvider(source);
    final response = await _apiClient.get(
      '${AppConstants.consumetBaseUrl}/manga/$provider/${Uri.encodeComponent(query)}',
    );
    final results = response.data['results'] as List<dynamic>? ?? [];
    // Convert to proper type
    return results
        .whereType<Map<dynamic, dynamic>>()
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
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

      // Use Backend for MangaDex reading
      if (source == 'mangadex') {
        final url = '/mangadex/chapter/$actualChapterId/pages';
        print('DEBUG: Fetching pages from backend: $url');
        final response = await _apiClient.get(url);
        final data = response.data;
        // Backend returns { images: [...] }
        final List<dynamic> images = (data['images'] as List<dynamic>?) ?? [];
        return images.map((e) => e.toString()).toList();
      }

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

      print('DEBUG: Extracted ${pages.length} pages from response');
      return pages;
    } catch (e) {
      print('Error fetching pages: $e');
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

  /// Find best match from search results using scoring
  Map<String, dynamic> _findBestMatch(
      List<Map<String, dynamic>> results, String query) {
    // Normalization helper
    String _normalize(String s) {
      return s
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    final queryNorm = _normalize(query);
    final queryLower = query.toLowerCase().trim();
    final queryWords = queryNorm.split(' ');

    int bestScore = -1000; // Allow negative scores
    Map<String, dynamic> bestMatch = results.first;

    print('DEBUG: Scoring candidates for query: "$query" (norm: "$queryNorm")');

    for (final result in results) {
      final title = (result['title'] ?? '').toString();
      final titleLower = title.toLowerCase().trim();
      final titleNorm = _normalize(title);

      int score = 0;

      // 1. Exact Match (Normalized)
      if (titleNorm == queryNorm) {
        score += 1000;
      }
      // Exact Match (Case-insensitive raw) - Higher bonus
      if (titleLower == queryLower) {
        score += 200;
      }

      // 2. Starts With
      if (titleNorm.startsWith(queryNorm)) {
        // Only valid if query is reasonably long OR follows word boundary
        if (queryNorm.length < 3) {
          score += 50; // Very weak bonus for short queries
        } else {
          score += 300;
        }
      }

      // 3. Contains (Normalized)
      if (titleNorm.contains(queryNorm)) {
        score += 200;
      }

      // 4. Word Overlap
      final titleWords = titleNorm.split(' ');
      int wordMatches = 0;
      for (final qWord in queryWords) {
        if (qWord.isEmpty) continue;
        if (titleWords.contains(qWord)) {
          score += 50;
          wordMatches++;
        }
      }
      if (wordMatches == queryWords.length && queryWords.isNotEmpty) {
        score += 100;
      }

      // --- PENALTIES ---

      // 1. Length/Ratio Penalty
      // If title is significantly longer, it's less likely to be the main entry
      // Normalized length used for reliability
      if (queryNorm.isNotEmpty) {
        final ratio = titleNorm.length / queryNorm.length;

        // Only apply strict ratio penalty if title has enough words to be a "long" title
        // This protects short synonyms like "86" -> "Eighty Six" (2 words) from being killed
        final isTitleLongInWords = titleWords.length > 3;

        if (queryNorm.length < 5) {
          // Strict mode for short queries (e.g. "86")
          if (isTitleLongInWords) {
            if (ratio > 2.0) score -= 500;
            if (ratio > 3.0) score -= 1000;
          }
        } else {
          // Normal mode
          if (ratio > 2.0) score -= 300;
          if (ratio > 3.0) score -= 500;
        }
      }

      // 2. Separators checking (Raw strings)
      // Spinoffs often usage " - ", ": " etc.
      // If title has separators that query doesn't, penalize.
      final separators = [' - ', ' – ', ' — ', ': '];
      bool hasExtraSeparator = false;
      for (final sep in separators) {
        if (title.contains(sep) && !query.contains(sep)) {
          hasExtraSeparator = true;
          break;
        }
      }
      if (hasExtraSeparator) {
        score -= 300; // Increased from 200
      }

      // 3. Spinoff Keywords
      final spinoffKeywords = [
        'doujinshi', 'dj', '(dj)', 'anthology', 'fan comic', 'fancomic',
        'parody', '4-koma', 'yonkoma', 'oneshot collection', 'extra',
        'side story', 'gaiden', 'spinoff', 'spin-off'
        // Removed 'official' as it often denotes main series on some sites
      ];
      for (final keyword in spinoffKeywords) {
        if (titleLower.contains(keyword)) {
          // If query ALSO contains it, don't penalize (user searching for spinoff)
          if (!queryLower.contains(keyword)) {
            score -= 500;
          }
        }
      }

      // 4. Word Count Penalty
      // If title has many more words than query
      if (titleWords.length > queryWords.length + 2) {
        // Changed +3 to +2
        score -= 200; // Increased from 100
      }

      // Penalize if it looks like a "Volume" or specific chapter entry
      // e.g. "86 - Eighty Six - Volume 1"
      if (titleLower.contains('volume') && !queryLower.contains('volume')) {
        score -= 200;
      }

      print('DEBUG: Candidate "${result['title']}" -> Score: $score');

      if (score > bestScore) {
        bestScore = score;
        bestMatch = result;
      }
    }

    bestMatch['_score'] = bestScore;
    return bestMatch;
  }
}
