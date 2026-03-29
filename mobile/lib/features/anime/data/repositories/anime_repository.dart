import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants.dart';
import '../../../../core/utils/api_helpers.dart';
import '../../../../core/utils/title_matcher.dart';
import '../../../../domain/entities/anime.dart';
import '../../../../domain/entities/episode.dart';
import '../../../../domain/entities/anime_source.dart';
import '../../../../data/api_client.dart';
import '../../../../core/config/source_config.dart';

final animeRepositoryProvider = Provider<AnimeRepository>((ref) {
  return AnimeRepository(ref.read(apiClientProvider));
});

class AnimeRepository {
  final ApiClient _apiClient;
  String? _activeSource;

  AnimeRepository(this._apiClient);

  Future<void> setActiveSource(String sourceId) async {
    _activeSource = sourceId;
  }

  String? getActiveSource() {
    return _activeSource ?? 'jikan';
  }

  Future<List<AnimeSource>> getAvailableSources() async {
    final List<AnimeSource> sources = [
      AnimeSource(
        id: 'jikan',
        name: 'Jikan (MyAnimeList)',
        description: 'Global anime database',
        isActive: getActiveSource() == 'jikan',
      ),
      AnimeSource(
        id: 'animeunity',
        name: 'AnimeUnity',
        description: 'Italian Source (AnimeUnity)',
        isActive: getActiveSource() == 'animeunity',
      ),
      AnimeSource(
        id: 'hianime',
        name: 'HiAnime',
        description: 'Global Source (HiAnime)',
        isActive: getActiveSource() == 'hianime',
      ),
      AnimeSource(
        id: 'animekai',
        name: 'AnimeKai',
        description: 'Global Source (AnimeKai)',
        isActive: getActiveSource() == 'animekai',
      ),
      AnimeSource(
        id: 'animesaturn',
        name: 'AnimeSaturn',
        description: 'Italian Source (AnimeSaturn)',
        isActive: getActiveSource() == 'animesaturn',
      ),
      AnimeSource(
        id: 'kickassanime',
        name: 'KickAssAnime',
        description: 'Global Source (KickAssAnime)',
        isActive: getActiveSource() == 'kickassanime',
      ),
    ];

    return sources
        .where((s) => SourceConfig.isAnimeSourceEnabled(s.id))
        .toList();
  }

  Future<AnimeListResponse> getAnimeList({
    String? genre,
    String? status,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final active = getActiveSource();

    if (active == 'jikan' || (search == null && genre == null)) {
      // Use Jikan for general lists or if it's the active source
      final queryParams = <String, dynamic>{
        'page': page,
        'q': search ?? '',
      };

      // Map genres if present
      if (genre != null) {
        final genreId = _getJikanGenreId(genre);
        if (genreId != null) {
          queryParams['genres'] = genreId;
        }
      }

      final response = await _apiClient.get(
        AppConstants.animeList,
        queryParameters: queryParams,
      );

      final List<Anime> dataList =
          ApiHelpers.parseAndMap(response.data, Anime.fromJson);

      final pagination = response.data is Map
          ? response.data['pagination']
          : null;
      final hasNextPage = pagination?['hasNextPage'] ?? false;

      return AnimeListResponse(
        data: dataList,
        total: 0,
        page: page,
        limit: limit,
        totalPages: hasNextPage ? page + 1 : page,
      );
    } else {
      // Use Consumet API for searching on a specific provider
      // Note: Consumet generic search might not support genre filtering directly in the same way
      // But we generally fallback to Jikan for genre lists anyway in the app logic logic
      // if the user specifically requested a genre list.
      final response = await _apiClient.get(
        '${AppConstants.consumetBaseUrl}/anime/$active/$search',
        queryParameters: {'page': page},
      );

      // Consumet usually returns { results: [...] } or just [...]
      final results = ApiHelpers.parseListResponse(
          response.data, dataKey: 'results');

      final List<Anime> dataList = results
          .map<Anime>((e) => Anime(
                id: e['id'].toString(),
                title: e['title'].toString(),
                description: '',
                coverUrl: e['image'] ?? e['cover'],
                genres: [],
                status: AnimeStatus.ongoing,
                releaseYear: 0,
                rating: (e['rating'] as num?)?.toDouble() ?? 0.0,
                totalEpisodes: (e['totalEpisodes'] as num?)?.toInt() ?? 0,
                source: active,
              ))
          .toList();

      return AnimeListResponse(
        data: dataList,
        total: dataList.length,
        page: page,
        limit: limit,
        totalPages: page, // Simplification
      );
    }
  }

  String? _getJikanGenreId(String genre) {
    final Map<String, int> genreMap = {
      'azione': 1,
      'avventura': 2,
      'commedia': 4,
      'drama': 8,
      'fantasy': 10,
      'horror': 14,
      'romance': 22,
      'sci-fi': 24,
      'slice of life': 36,
      'supernatural': 37,
      'sport': 30,
    };
    final id = genreMap[genre.toLowerCase()];
    return id?.toString();
  }

  Future<Anime> getAnimeById(String id) async {
    final active = getActiveSource();

    // If we have a numeric ID (Jikan format), ALWAYS use Jikan for metadata
    // This ensures correct titles regardless of which streaming source is active
    // The streaming source only affects episode/stream loading, not anime metadata
    if (RegExp(r'^\d+$').hasMatch(id)) {
      return _getJikanAnimeById(id);
    }

    // For non-numeric IDs (Consumet format like "2616-attack-on-titan"),
    // use Consumet API to get anime info    // For non-numeric IDs (Consumet format like "2616-attack-on-titan"),
    // use Consumet API to get anime info

    // Determine effective source - use animeunity as default if source is jikan
    final effectiveSource = active == 'jikan' ? 'animeunity' : active;

    // Consumet Info API: http://localhost:3002/anime/[provider]/info?id=[id]
    final List<dynamic> allEpisodes = [];
    int currentPage = 1;
    bool hasNextPage = true;
    Map<String, dynamic> mainData = {};

    while (hasNextPage) {
      final response = await _apiClient.get(
        '${AppConstants.consumetBaseUrl}/anime/$effectiveSource/info',
        queryParameters: {'id': id, 'page': currentPage},
      );

      final data = response.data;
      if (currentPage == 1) {
        mainData = data;
      }

      if (data['episodes'] != null) {
        allEpisodes.addAll(data['episodes']);
      }

      hasNextPage = data['hasNextPage'] == true;
      currentPage++;
    }

    final data = mainData;
    return Anime(
      id: data['id'].toString(),
      title: data['title'].toString(),
      titleEnglish: data['title_english'] ?? data['titleEnglish'],
      titleJapanese: data['title_japanese'] ?? data['titleJapanese'],
      description: data['description']?.toString() ?? '',
      coverUrl: data['image'] ?? data['cover'],
      genres: (data['genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: (data['status']?.toString().toLowerCase() ?? '') == 'completed'
          ? AnimeStatus.completed
          : AnimeStatus.ongoing,
      releaseYear: int.tryParse(data['releaseDate']?.toString() ?? '0') ?? 0,
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      totalEpisodes:
          (data['totalEpisodes'] as num?)?.toInt() ?? allEpisodes.length,
      source: effectiveSource,
      episodes: allEpisodes
          .map((e) => Episode(
                id: e['id'].toString(),
                animeId: data['id'].toString(),
                number: (e['number'] as num?)?.toInt() ?? 0,
                title: e['title'] ?? 'Episode ${e['number']}',
                thumbnail: e['image'] ?? data['image'],
                duration: 0,
                streamUrl: '',
                source: effectiveSource,
              ))
          .toList(),
    );
  }

  Future<Anime> _getJikanAnimeById(String id) async {
    // For full details including relations, we need to use the 'full' endpoint or just ensure main endpoint includes it
    try {
      final response =
          await _apiClient.get('${AppConstants.animeDetails}/$id/full');
      // Ensure data is correctly mapped from Jikan response
      final data = response.data['data'] ?? response.data;
      return Anime.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Fallback to non-full endpoint
        final response =
            await _apiClient.get('${AppConstants.animeDetails}/$id');
        final data = response.data?['data'] ?? response.data;
        if (data == null) {
          throw Exception('Anime data not found in fallback');
        }
        return Anime.fromJson(data as Map<String, dynamic>);
      }
      rethrow;
    }
  }

  /// Fetches ALL episodes by loading all pages automatically.
  /// Tries multiple title variants for better AnimeUnity matching.
  Future<List<Episode>> getAllEpisodes(String animeId) async {
    // If we have a numeric ID (Jikan format), search on AnimeUnity for episodes
    // This works for both 'jikan' and 'animeunity' as active source
    if (RegExp(r'^\d+$').hasMatch(animeId)) {
      try {
        final activeSource = getActiveSource();
        if (kDebugMode) debugPrint(
            'DEBUG: getAllEpisodes called for $animeId with activeSource: $activeSource');
        // Define sources to try, prioritizing the active source
        final List<String> availableSources = [
          'animeunity',
          'hianime',
          'kickassanime',
          'animekai',
          // 'animesaturn', // REMOVED: Causing default source issues
        ].where((s) => SourceConfig.isAnimeSourceEnabled(s)).toList();

        final List<String> sourcesToTry = [];
        if (activeSource != 'jikan' &&
            activeSource != null &&
            availableSources.contains(activeSource)) {
          sourcesToTry.add(activeSource);
          availableSources.remove(activeSource);
        }
        sourcesToTry.addAll(availableSources);

        if (kDebugMode) debugPrint('DEBUG: Sources to try for episodes: $sourcesToTry');

        // Pre-fetch Jikan info once for title generation
        final jikanAnime = await _getJikanAnimeById(animeId);

        // Manual overrides for problematic anime (Jikan ID -> AnimeUnity ID)
        final manualOverrides = <String, String>{
          '1735': '430-naruto-shippuden', // Naruto: Shippuuden
          '59064':
              '7209-jujutsu-kaisen-3-the-culling-game-part-1', // Jujutsu Kaisen: The Culling Game (Season 3)
          '51009': '5765-jujutsu-kaisen-2', // Jujutsu Kaisen Season 2
        };

        // Build list of title variants to try ONCE
        // Extract season number from titles for smarter matching
        final extractedSeason = _extractSeasonNumber(
          jikanAnime.title,
          jikanAnime.titleEnglish,
          jikanAnime.titleRomaji,
        );
        if (kDebugMode) debugPrint('DEBUG: Extracted season number: $extractedSeason');

        final titlesToTry = <String>[
          if (jikanAnime.titleRomaji != null &&
              jikanAnime.titleRomaji!.isNotEmpty)
            _cleanTitle(jikanAnime.titleRomaji!),
          if (jikanAnime.titleEnglish != null &&
              jikanAnime.titleEnglish!.isNotEmpty)
            _cleanTitle(jikanAnime.titleEnglish!),
          _cleanTitle(jikanAnime.title),
        ].toSet().toList(); // Remove duplicates

        // Explicitly add lowercase raw title if it contains semicolon (for Steins;Gate etc)
        if (jikanAnime.title.contains(';')) {
          titlesToTry.add(jikanAnime.title.toLowerCase());
        }

        // Track the number of ORIGINAL titles (before adding derived variants)
        final originalTitleCount = titlesToTry.length;

        if (kDebugMode) debugPrint('DEBUG: Search Variants: $titlesToTry');

        // Add variants for Shippuuden <-> Shippuden (handles common Consumet issues)
        final shippuudenTitles =
            titlesToTry.where((t) => t.contains('Shippuuden')).toList();
        for (final t in shippuudenTitles) {
          titlesToTry.add(t.replaceAll('Shippuuden', 'Shippuden'));
        }
        final shippudenTitles =
            titlesToTry.where((t) => t.contains('Shippuden')).toList();
        for (final t in shippudenTitles) {
          titlesToTry.add(t.replaceAll('Shippuden', 'Shippuuden'));
        }

        // Add simplified variants for Season/Part patterns
        final currentTitles = List<String>.from(titlesToTry);
        for (final t in currentTitles) {
          // Remove "Part X" suffix: "Season 3 Part 2" -> "Season 3"
          final withoutPart = t
              .replaceAll(RegExp(r'\s*Part\.?\s*\d+', caseSensitive: false), '')
              .trim();
          if (withoutPart != t && withoutPart.isNotEmpty) {
            titlesToTry.add(withoutPart);
          }

          // Simplify "Season X" to just "X": "Shingeki no Kyojin Season 3" -> "Shingeki no Kyojin 3"
          final simplifiedSeason = t
              .replaceAllMapped(
                RegExp(r'\s*Season\s*(\d+)', caseSensitive: false),
                (m) => ' ${m.group(1)}',
              )
              .trim();
          if (simplifiedSeason != t && simplifiedSeason.isNotEmpty) {
            titlesToTry.add(simplifiedSeason);
          }

          // Remove both Season and Part completely for base title search
          final baseTitle = t
              .replaceAll(RegExp(r'\s*Season\s*\d+', caseSensitive: false), '')
              .replaceAll(RegExp(r'\s*Part\.?\s*\d+', caseSensitive: false), '')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          if (baseTitle != t && baseTitle.isNotEmpty && baseTitle.length > 3) {
            titlesToTry.add(baseTitle);
          }

          // Remove subtitle after ":" or " - " for base title
          if (t.contains(':')) {
            final mainTitle = t.split(':').first.trim();
            if (mainTitle.isNotEmpty && mainTitle.length > 3) {
              titlesToTry.add(mainTitle);
              // Also try with season number appended (for sequels)
              if (t.toLowerCase().contains('2') ||
                  t.toLowerCase().contains('second') ||
                  t.toLowerCase().contains('ii')) {
                titlesToTry.add('$mainTitle 2');
              }
              if (t.toLowerCase().contains('3') ||
                  t.toLowerCase().contains('third') ||
                  t.toLowerCase().contains('iii')) {
                titlesToTry.add('$mainTitle 3');
              }
            }
          }
          if (t.contains(' - ')) {
            final mainTitle = t.split(' - ').first.trim();
            if (mainTitle.isNotEmpty && mainTitle.length > 3) {
              titlesToTry.add(mainTitle);
            }
          }
        }

        // Remove duplicates after adding variants
        final uniqueTitles = titlesToTry.toSet().toList();
        titlesToTry.clear();
        titlesToTry.addAll(uniqueTitles);
        if (kDebugMode) debugPrint('DEBUG: All Search Variants: $titlesToTry');

        // Loop through sources
        for (final source in sourcesToTry) {
          if (kDebugMode) debugPrint('DEBUG: Trying source: $source');
          String? bestMatchId;

          if (source == 'animeunity' && manualOverrides.containsKey(animeId)) {
            bestMatchId = manualOverrides[animeId];
            if (kDebugMode) debugPrint('Using manual override ID for AnimeUnity: $bestMatchId');
          } else {
            // Collect all candidates from all search variants
            final List<Map<String, dynamic>> allCandidates = [];

            // Try each title variant to collect results
            for (final titleVariant in titlesToTry) {
              if (kDebugMode) debugPrint('Searching $source with title variant: $titleVariant');
              try {
                final searchResponse = await _apiClient.get(
                  '${AppConstants.consumetBaseUrl}/anime/$source/${Uri.encodeComponent(titleVariant)}',
                );
                final results = ApiHelpers.parseListResponse(
                    searchResponse.data, dataKey: 'results');

                // Add all results to candidates list
                for (final r in results) {
                  if (r is Map<String, dynamic>) {
                    allCandidates.add(r);
                  } else if (r is Map) {
                    allCandidates.add(Map<String, dynamic>.from(r));
                  }
                }
              } catch (e) {
                if (kDebugMode) debugPrint('Search failed for "$titleVariant" on $source: $e');
              }
            }

            // Remove duplicates based on ID
            final seenIds = <String>{};
            allCandidates.removeWhere((c) {
              final id = c['id'].toString();
              if (seenIds.contains(id)) return true;
              seenIds.add(id);
              return false;
            });

            if (kDebugMode) {
              debugPrint(
                  'TitleMatcher: Found ${allCandidates.length} unique candidates on $source');
            }

            // Score each candidate using shared TitleMatcher
            if (allCandidates.isNotEmpty) {
              int bestScore = -1000;
              Map<String, dynamic>? bestCandidate;

              for (final candidate in allCandidates) {
                final score = TitleMatcher.scoreAnimeCandidate(
                  candidate: candidate,
                  titlesToTry: titlesToTry,
                  originalTitleCount: originalTitleCount,
                  extractedSeason: extractedSeason,
                  referenceYear: jikanAnime.releaseYear,
                  referenceType: jikanAnime.type,
                );

                if (score > bestScore) {
                  bestScore = score;
                  bestCandidate = candidate;
                }
              }

              if (bestCandidate != null) {
                // Strict threshold check
                if (bestScore < 100) {
                  if (kDebugMode) debugPrint(
                      'DEBUG: Best candidate ${bestCandidate['title']} (${bestCandidate['id']}) rejected due to low score ($bestScore)');
                  continue; // Skip this source, try next
                }

                bestMatchId = bestCandidate['id'].toString();
                if (kDebugMode) debugPrint(
                    'Selected best match on $source: ${bestCandidate['title']} ($bestMatchId) with score $bestScore');
              }
            }
          }

          if (bestMatchId != null) {
            // Fetch ALL pages of episodes
            final List<Episode> allEpisodes = [];
            int currentPage = 1;
            bool hasNextPage = true;
            String? coverImage;
            int? totalEpisodes;

            try {
              while (hasNextPage) {
                if (kDebugMode) debugPrint(
                    'Fetching episodes page $currentPage for $bestMatchId on $source');
                final infoResponse = await _apiClient.get(
                  '${AppConstants.consumetBaseUrl}/anime/$source/info',
                  queryParameters: {'id': bestMatchId, 'page': currentPage},
                );

                final data = infoResponse.data;
                coverImage ??= data['image'];
                totalEpisodes ??= data['totalEpisodes'];

                final episodesRaw = ApiHelpers.parseListResponse(
                    data, dataKey: 'episodes');
                final pageEpisodes = episodesRaw
                    .whereType<Map<String, dynamic>>()
                    .map((e) => Episode(
                          id: e['id'].toString(),
                          animeId: animeId,
                          number: (e['number'] as num?)?.toInt() ?? 0,
                          title: e['title']?.toString() ??
                              'Episode ${e['number']}',
                          thumbnail: e['image']?.toString() ?? coverImage,
                          duration: 0,
                          streamUrl: '',
                          source: source,
                        ))
                    .toList();

                if (pageEpisodes.isEmpty) {
                  hasNextPage = false;
                } else {
                  allEpisodes.addAll(pageEpisodes);
                  hasNextPage = (data['hasNextPage'] == true) ||
                      (totalEpisodes != null &&
                          allEpisodes.length < totalEpisodes);
                  currentPage++;
                }
                if (currentPage > 50) break;
              }

              if (allEpisodes.isNotEmpty) {
                if (kDebugMode) debugPrint(
                    'Found ${allEpisodes.length} episodes on $source. Returning.');
                return allEpisodes;
              }
            } catch (e) {
              if (kDebugMode) debugPrint('Error fetching episodes info from $source: $e');
            }
          }
        } // End source loop
      } catch (e) {
        if (kDebugMode) debugPrint('Error in getAllEpisodes fallback logic: $e');
      }
    }

    // Default fallback
    final anime = await getAnimeById(animeId);
    return anime.episodes ?? [];
  }

  /// Single-page episode fetch for manual pagination (kept for compatibility)
  Future<PaginatedEpisodes> getEpisodes(String animeId, {int page = 1}) async {
    // If we have a numeric ID (Jikan format), search on AnimeUnity for episodes
    if (RegExp(r'^\d+$').hasMatch(animeId)) {
      try {
        final jikanAnime = await _getJikanAnimeById(animeId);

        // Build list of title variants to try
        final titlesToTry = <String>[
          _cleanTitle(jikanAnime.title),
          if (jikanAnime.titleEnglish != null &&
              jikanAnime.titleEnglish!.isNotEmpty)
            _cleanTitle(jikanAnime.titleEnglish!),
          if (jikanAnime.titleJapanese != null &&
              jikanAnime.titleJapanese!.isNotEmpty)
            _cleanTitle(jikanAnime.titleJapanese!),
        ].toSet().toList();

        String? bestMatchId;

        for (final titleVariant in titlesToTry) {
          try {
            final searchResponse = await _apiClient.get(
              '${AppConstants.consumetBaseUrl}/anime/animeunity/${Uri.encodeComponent(titleVariant)}',
            );
            final results = ApiHelpers.parseListResponse(
                searchResponse.data, dataKey: 'results');
            if (results.isNotEmpty && results.first is Map) {
              bestMatchId = (results.first as Map)['id']?.toString();
              if (bestMatchId != null) break;
            }
          } catch (_) {}
        }

        if (bestMatchId != null) {
          final infoResponse = await _apiClient.get(
            '${AppConstants.consumetBaseUrl}/anime/animeunity/info',
            queryParameters: {'id': bestMatchId, 'page': page},
          );

          final data = infoResponse.data;
          final episodesRaw = ApiHelpers.parseListResponse(
              data, dataKey: 'episodes');
          final episodes = episodesRaw
              .whereType<Map<String, dynamic>>()
              .map((e) => Episode(
                    id: e['id'].toString(),
                    animeId: animeId,
                    number: (e['number'] as num?)?.toInt() ?? 0,
                    title: e['title']?.toString() ??
                        'Episode ${e['number']}',
                    thumbnail: e['image']?.toString() ??
                        (data is Map ? data['image']?.toString() : null),
                    duration: 0,
                    streamUrl: '',
                    source: 'animeunity',
                  ))
              .toList();

          return PaginatedEpisodes(
            episodes: episodes,
            hasNextPage: data['hasNextPage'] == true,
          );
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Error mapping Jikan episodes: $e');
      }
    }

    // Default fallback
    final anime = await getAnimeById(animeId);
    return PaginatedEpisodes(
      episodes: anime.episodes ?? [],
      hasNextPage: false,
    );
  }

  String _cleanTitle(String title) => TitleMatcher.cleanTitle(title);

  Future<List<String>> getGenres() async {
    try {
      final response = await _apiClient.get(AppConstants.animeGenres);
      final list = ApiHelpers.parseListResponse(response.data);
      return list.map((e) => e.toString()).toList();
    } catch (e) {
      ApiHelpers.logError('getGenres', e);
      return [];
    }
  }

  Future<List<Anime>> getNewReleases({int limit = 20, int page = 1}) async {
    try {
      final response = await _apiClient.get(
        AppConstants.animeNewReleases,
        queryParameters: {'limit': limit, 'page': page},
      );
      return ApiHelpers.parseAndMap(response.data, Anime.fromJson);
    } catch (e) {
      ApiHelpers.logError('getNewReleases', e);
      return [];
    }
  }

  Future<List<Anime>> getTopRated({int limit = 20, int page = 1}) async {
    try {
      final response = await _apiClient.get(
        AppConstants.animeTopRated,
        queryParameters: {'limit': limit, 'page': page},
      );
      return ApiHelpers.parseAndMap(response.data, Anime.fromJson);
    } catch (e) {
      ApiHelpers.logError('getTopRated', e);
      return [];
    }
  }

  Future<List<Anime>> getTrendingAnime({int limit = 20, int page = 1}) async {
    return getTopRated(limit: limit, page: page);
  }

  Future<List<Anime>> getPopularAnime({int limit = 20, int page = 1}) async {
    return getTopRated(limit: limit, page: page);
  }

  Future<List<Anime>> getUpcomingAnime({int limit = 20, int page = 1}) async {
    try {
      final response = await _apiClient.get(
        AppConstants.animeTopRated,
        queryParameters: {'filter': 'upcoming', 'page': page, 'limit': limit},
      );
      return ApiHelpers.parseAndMap(response.data, Anime.fromJson);
    } catch (e) {
      ApiHelpers.logError('getUpcomingAnime', e);
      return [];
    }
  }

  Future<List<Anime>> getAiringAnime({int limit = 20, int page = 1}) async {
    try {
      final response = await _apiClient.get(
        AppConstants.animeTopRated,
        queryParameters: {'filter': 'airing', 'page': page, 'limit': limit},
      );
      return ApiHelpers.parseAndMap(response.data, Anime.fromJson);
    } catch (e) {
      ApiHelpers.logError('getAiringAnime', e);
      return getNewReleases(limit: limit);
    }
  }

  Future<List<Anime>> getClassicsAnime({int limit = 20, int page = 1}) async {
    try {
      final response = await _apiClient.get(
        AppConstants.animeTopRated,
        queryParameters: {'filter': 'favorite', 'page': page, 'limit': limit},
      );
      return ApiHelpers.parseAndMap(response.data, Anime.fromJson);
    } catch (e) {
      ApiHelpers.logError('getClassicsAnime', e);
      return getTopRated(limit: limit);
    }
  }

  /// Get recently released episodes (raw from provider)
  Future<List<Episode>> getRecentEpisodes({int page = 1}) async {
    final activeSource = getActiveSource() ?? 'animeunity';
    // Use 'animeunity' if 'jikan' is active, as AnimeSaturn lacks recent-episodes endpoint
    // in the format we want for "new releases" usually.
    final sourceToUse = activeSource == 'jikan' ? 'animeunity' : activeSource;

    try {
      final response = await _apiClient.get(
        '${AppConstants.consumetBaseUrl}/anime/$sourceToUse/recent-episodes',
        queryParameters: {'page': page},
      );

      final results = ApiHelpers.parseListResponse(
          response.data, dataKey: 'results');

      return results.map((e) {
        // Consumet recent-episodes structure usually:
        // {
        //   "id": "anime-id", // e.g., "7101-gnosia"
        //   "episodeId": "anime-id-episode-1",
        //   "episodeNumber": 1,
        //   "title": "Anime Title" or null or "Episode X"
        // }

        final rawId = e['id']?.toString() ?? '';
        final rawTitle = e['title']?.toString();
        final episodeNum = (e['episodeNumber'] as num?)?.toInt() ?? 0;

        String displayTitle = rawTitle ?? '';

        // If title is missing or generic "Episode X", try to extract from ID
        if (displayTitle.isEmpty ||
            displayTitle.toLowerCase().startsWith('episode')) {
          // ID format: "123-slug-name"
          final match = RegExp(r'^\d+-(.+)$').firstMatch(rawId);
          if (match != null) {
            String slug = match.group(1)!;
            // Convert "slug-name" to "Slug Name"
            displayTitle = slug.split('-').map((word) {
              if (word.isEmpty) return '';
              return '${word[0].toUpperCase()}${word.substring(1)}';
            }).join(' ');
          } else {
            displayTitle =
                displayTitle.isEmpty ? 'Anime Unknown' : displayTitle;
          }
        }

        return Episode(
          id: e['episodeId']?.toString() ?? '',
          animeId: rawId,
          number: episodeNum,
          title: displayTitle,
          thumbnail: e['image'],
          duration: 0,
          streamUrl: e['url'] ?? '',
          source: sourceToUse,
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching recent episodes from $sourceToUse: $e');
      return [];
    }
  }

  int? _extractSeasonNumber(
      String title, String? titleEnglish, String? titleRomaji) {
    return TitleMatcher.extractSeasonNumber(title,
        titleEnglish: titleEnglish, titleRomaji: titleRomaji);
  }

  /// Get anime schedule for a specific day
  Future<List<Anime>> getSchedule(String day) async {
    try {
      // Always use Jikan for schedule as it's the only source that supports it
      // The backend endpoint is /jikan/anime/schedule?day=monday
      final response = await _apiClient.get(
        '/jikan/anime/schedule',
        queryParameters: {'day': day},
      );

      if (response.statusCode == 200) {
        return ApiHelpers.parseAndMap(response.data, Anime.fromJson);
      }
      return [];
    } catch (e) {
      ApiHelpers.logError('getSchedule($day)', e);
      return [];
    }
  }

  /// Resolve the actual stream URL for a given episode
  Future<Map<String, dynamic>> resolveStreamUrl(String episodeId,
      {String? source}) async {
    var activeSource = source ?? getActiveSource();
    if (activeSource == 'jikan' || activeSource == 'animesaturn') {
      activeSource = 'animeunity';
    }

    // For Animeworld/AnimeUnity scenarios
    try {
      final response = await _apiClient.get(
        '${AppConstants.consumetBaseUrl}/anime/$activeSource/watch/$episodeId',
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // Handle potentially different response structures
        if (data is Map<String, dynamic>) {
          String? url;
          Map<String, String>? headers;

          if (data['sources'] is List && (data['sources'] as List).isNotEmpty) {
            final sources = data['sources'] as List;
            // Try to find auto or best quality
            final bestSource = sources.firstWhere(
              (s) => s['quality'] == 'auto' || s['quality'] == 'default',
              orElse: () => sources.first,
            );
            url = bestSource['url'].toString();
          } else if (data['url'] != null) {
            url = data['url'].toString();
          }

          if (data['headers'] is Map) {
            headers = Map<String, String>.from(data['headers']);
          }

          if (url != null) {
            return {
              'url': url,
              'headers': headers,
            };
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error resolving stream URL: $e');
    }

    return {'url': '', 'headers': null};
  }
}

class AnimeListResponse {
  final List<Anime> data;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  AnimeListResponse({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory AnimeListResponse.fromJson(Map<String, dynamic> json) {
    return AnimeListResponse(
      data: ApiHelpers.parseAndMap(json, Anime.fromJson),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
      totalPages: json['totalPages'] as int? ?? 1,
    );
  }
}

class PaginatedEpisodes {
  final List<Episode> episodes;
  final bool hasNextPage;

  PaginatedEpisodes({
    required this.episodes,
    required this.hasNextPage,
  });
}
