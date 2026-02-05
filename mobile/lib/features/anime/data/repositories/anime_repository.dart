import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants.dart';
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

      final List<Anime> dataList = (response.data['data'] as List<dynamic>)
          .map<Anime>((e) => Anime.fromJson(e as Map<String, dynamic>))
          .toList();

      final pagination = response.data['pagination'];
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
      final results = response.data['results'] as List<dynamic>? ??
          (response.data is List ? response.data : []);

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
              ))
          .toList(),
    );
  }

  Future<Anime> _getJikanAnimeById(String id) async {
    final response = await _apiClient.get('${AppConstants.animeDetails}/$id');
    // Ensure data is correctly mapped from Jikan response
    final data = response.data['data'] ?? response.data;
    return Anime.fromJson(data as Map<String, dynamic>);
  }

  /// Fetches ALL episodes by loading all pages automatically.
  /// Tries multiple title variants for better AnimeUnity matching.
  Future<List<Episode>> getAllEpisodes(String animeId) async {
    // If we have a numeric ID (Jikan format), search on AnimeUnity for episodes
    // This works for both 'jikan' and 'animeunity' as active source
    if (RegExp(r'^\d+$').hasMatch(animeId)) {
      try {
        final activeSource = getActiveSource();
        // Define sources to try, prioritizing the active source
        final List<String> availableSources = [
          'animeunity',
          'hianime',
          'animesaturn',
          'kickassanime',
          'animekai'
        ].where((s) => SourceConfig.isAnimeSourceEnabled(s)).toList();

        final List<String> sourcesToTry = [];
        if (activeSource != 'jikan' &&
            activeSource != null &&
            availableSources.contains(activeSource)) {
          sourcesToTry.add(activeSource);
          availableSources.remove(activeSource);
        }
        sourcesToTry.addAll(availableSources);

        print('DEBUG: Sources to try for episodes: $sourcesToTry');

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
        print('DEBUG: Extracted season number: $extractedSeason');

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

        print('DEBUG: Search Variants: $titlesToTry');

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
        print('DEBUG: All Search Variants: $titlesToTry');

        // Loop through sources
        for (final source in sourcesToTry) {
          print('DEBUG: Trying source: $source');
          String? bestMatchId;

          if (source == 'animeunity' && manualOverrides.containsKey(animeId)) {
            bestMatchId = manualOverrides[animeId];
            print('Using manual override ID for AnimeUnity: $bestMatchId');
          } else {
            // Collect all candidates from all search variants
            final List<Map<String, dynamic>> allCandidates = [];

            // Try each title variant to collect results
            for (final titleVariant in titlesToTry) {
              print('Searching $source with title variant: $titleVariant');
              try {
                final searchResponse = await _apiClient.get(
                  '${AppConstants.consumetBaseUrl}/anime/$source/${Uri.encodeComponent(titleVariant)}',
                );
                final results =
                    searchResponse.data['results'] as List<dynamic>? ?? [];

                // Add all results to candidates list
                for (final r in results) {
                  allCandidates.add(r as Map<String, dynamic>);
                }
              } catch (e) {
                print('Search failed for "$titleVariant" on $source: $e');
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

            print(
                'DEBUG: Found ${allCandidates.length} unique candidates on $source');

            // Score each candidate based on season match
            if (allCandidates.isNotEmpty) {
              int bestScore = -1000;
              Map<String, dynamic>? bestCandidate;

              for (final candidate in allCandidates) {
                int score = 0;
                final candId = candidate['id'].toString().toLowerCase();
                final candTitle = candidate['title'].toString();
                final candTitleLower = candTitle.toLowerCase();

                // Extract season number from ID (logic varies by source but generally similar)
                final idWithoutPart = candId
                    .replaceAll(RegExp(r'-part-\d+'), '')
                    .replaceAll('-ita', '');

                final idSeasonMatch =
                    RegExp(r'-(\d+)(?:-|$)').firstMatch(idWithoutPart);
                int? candSeasonFromId;
                if (idSeasonMatch != null) {
                  candSeasonFromId = int.tryParse(idSeasonMatch.group(1)!);
                }

                // Also detect if this is a "Part 2" of a season
                final hasPart2 = candId.contains('-part-2') ||
                    candTitleLower.contains('part 2');

                final originalHasPart2 =
                    titlesToTry.first.toLowerCase().contains('part 2');

                final hasSubtitle = titlesToTry.first.contains(':') ||
                    titlesToTry.first.contains(' - ');

                // STRICT TITLE VERIFICATION
                // Determine core keywords from the base title ("Swallowed Star" from "Swallowed Star 4")
                // We typically assume the first part of the first title to try is the most accurate "base"
                // But we need to be careful with "Part X" or "Season X" removal
                final baseTitleForCheck = titlesToTry.first
                    .replaceAll(
                        RegExp(r'\s*Season\s*\d+', caseSensitive: false), '')
                    .replaceAll(
                        RegExp(r'\s*Part\s*\d+', caseSensitive: false), '')
                    .replaceAll(RegExp(r'\d+$'),
                        '') // Remove trailing numbers (e.g. " 4")
                    .trim()
                    .toLowerCase();

                // Split into significant words (ignore "the", "no", "ni", "wo" etc if needed, but simple split is ok for now)
                final coreKeywords = baseTitleForCheck
                    .split(RegExp(r'[^a-z0-9]+'))
                    .where((w) => w.length > 2) // Ignore short words
                    .toList();

                // Check if candidate title contains at least ONE of the core sequences or significant overlap
                // "The Rising of the Shield Hero" vs "Swallowed Star" -> No overlap
                // "Tunshi Xingkong" vs "Swallowed Star" -> This is hard! We trust that "titlesToTry" includes both.
                // We loop through ALL titlesToTry to check if ANY of them match the candidate.

                bool matchesAnyVariant = false;
                for (final variant in titlesToTry) {
                  final variantClean = variant
                      .replaceAll(
                          RegExp(r'\s*Season\s*\d+', caseSensitive: false), '')
                      .replaceAll(
                          RegExp(r'\s*Part\s*\d+', caseSensitive: false), '')
                      .replaceAll(RegExp(r'\d+$'), '')
                      .trim()
                      .toLowerCase();

                  // Check if candidate title (or its parts) contains this variant
                  if (candTitleLower.contains(variantClean)) {
                    matchesAnyVariant = true;
                    break;
                  }

                  // Also check individual keywords if the variant is multi-word
                  final variantKeywords = variantClean
                      .split(' ')
                      .where((w) => w.length > 3)
                      .toList();
                  if (variantKeywords.isNotEmpty) {
                    int keywordMatches = 0;
                    for (final k in variantKeywords) {
                      if (candTitleLower.contains(k)) keywordMatches++;
                    }
                    // If matches > 50% of keywords, assume match
                    if (keywordMatches >= (variantKeywords.length / 2).ceil()) {
                      matchesAnyVariant = true;
                      break;
                    }
                  }
                }

                if (!matchesAnyVariant) {
                  score = -10000; // DISQUALIFY
                  print(
                      'DEBUG: $candId - ($candTitle) disqualified: title mismatch (-10000)');
                } else {
                  print('DEBUG: $candId - passed strict title check');
                }

                // If we detected a season from Jikan title
                if (extractedSeason != null && extractedSeason > 1) {
                  if (candSeasonFromId == extractedSeason) {
                    score += 200; // Strong match
                    if (originalHasPart2) {
                      if (hasPart2) {
                        score += 100;
                      } else {
                        score -= 50;
                      }
                    }
                  } else if (candSeasonFromId != null &&
                      candSeasonFromId != extractedSeason) {
                    score -= 100; // Wrong season
                  } else if (candSeasonFromId == null) {
                    score -= 50; // Likely S1
                  }
                } else if (hasSubtitle) {
                  final subtitle = titlesToTry.first.contains(':')
                      ? titlesToTry.first.split(':').last.trim().toLowerCase()
                      : titlesToTry.first
                          .split(' - ')
                          .last
                          .trim()
                          .toLowerCase();

                  final bool idHasSubtitle =
                      candId.contains(subtitle.replaceAll(' ', '-'));
                  final bool titleHasSubtitle =
                      candTitleLower.contains(subtitle);

                  if (idHasSubtitle || titleHasSubtitle) {
                    score += 150;
                  } else if (candSeasonFromId != null && candSeasonFromId > 1) {
                    score += 100;
                  } else if (candSeasonFromId == null) {
                    score -= 30;
                  }
                } else {
                  // Looking for season 1
                  if (candSeasonFromId == null || candSeasonFromId == 1) {
                    score += 50;
                  } else if (candSeasonFromId != null && candSeasonFromId > 1) {
                    score -= 100;
                  }
                }

                if (candTitleLower.contains('ita')) {
                  score -= 30;
                }

                // Check matches against primary/derived variants logic...
                // (Simplified for brevity, reusing core logic logic operates same)
                // ...
                // Clean candidate title for fair comparison
                final candTitleClean = _cleanTitle(candTitle).toLowerCase();

                // Check matches against primary/derived variants logic...
                // (Simplified for brevity, reusing core logic logic operates same)
                // ...
                final primaryVariants =
                    titlesToTry.take(originalTitleCount).toList();

                bool isPrimaryMatch = false;
                for (final searchVariant in primaryVariants) {
                  final searchVariantClean =
                      _cleanTitle(searchVariant).toLowerCase();

                  // EXACT MATCH BONUS
                  if (candTitleClean == searchVariantClean) {
                    score += 150;
                    isPrimaryMatch = true;
                    print('DEBUG: $candId - Exact Match Bonus (+150)');
                    break;
                  }

                  // Check for extra words/numbers in candidate that are NOT in search variant
                  // e.g. Search: "Steins Gate", Candidate: "Steins Gate 0"
                  // This prevents "Steins Gate 0" from matching "Steins Gate" too strongly
                  if (candTitleClean.startsWith(searchVariantClean)) {
                    final suffix = candTitleClean
                        .substring(searchVariantClean.length)
                        .trim();
                    // If suffix contains numbers, it's likely a sequel/different season
                    if (RegExp(r'\d+').hasMatch(suffix)) {
                      score -= 50; // Penalize mismatching number suffix
                      print(
                          'DEBUG: $candId - Penalized for extra number suffix (-50): "$suffix"');
                    } else if (suffix.isNotEmpty) {
                      score -= 10; // Penalize text suffix slightly
                    } else {
                      // Suffix is empty, so it's a match? (handled by exact match above usually)
                    }
                  }
                }

                if (!isPrimaryMatch) {
                  // Check derived...
                  // Just give base title match bonus
                  final baseSearchTitle = titlesToTry.first
                      .toLowerCase()
                      .split(':')
                      .first
                      .split(' - ')
                      .first
                      .trim();

                  // Clean base title too if needed, but simple contains is often enough for fallback
                  if (candTitleLower.contains(baseSearchTitle)) {
                    score += 10;
                  }
                }

                if (score > bestScore) {
                  bestScore = score;
                  bestCandidate = candidate;
                }
              }

              if (bestCandidate != null) {
                bestMatchId = bestCandidate['id'].toString();
                print(
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
                print(
                    'Fetching episodes page $currentPage for $bestMatchId on $source');
                final infoResponse = await _apiClient.get(
                  '${AppConstants.consumetBaseUrl}/anime/$source/info',
                  queryParameters: {'id': bestMatchId, 'page': currentPage},
                );

                final data = infoResponse.data;
                coverImage ??= data['image'];
                totalEpisodes ??= data['totalEpisodes'];

                final pageEpisodes = (data['episodes'] as List<dynamic>?)
                        ?.map((e) => Episode(
                              id: e['id'].toString(),
                              animeId: animeId,
                              number: (e['number'] as num?)?.toInt() ?? 0,
                              title: e['title'] ?? 'Episode ${e['number']}',
                              // Some sources like HiAnime don't return image per episode often
                              thumbnail: e['image'] ?? coverImage,
                              duration: 0,
                              streamUrl: '',
                              source: source,
                            ))
                        .toList() ??
                    [];

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
                print(
                    'Found ${allEpisodes.length} episodes on $source. Returning.');
                return allEpisodes;
              }
            } catch (e) {
              print('Error fetching episodes info from $source: $e');
            }
          }
        } // End source loop
      } catch (e) {
        print('Error in getAllEpisodes fallback logic: $e');
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
            final results =
                searchResponse.data['results'] as List<dynamic>? ?? [];
            if (results.isNotEmpty) {
              bestMatchId = results.first['id'].toString();
              break;
            }
          } catch (_) {}
        }

        if (bestMatchId != null) {
          final infoResponse = await _apiClient.get(
            '${AppConstants.consumetBaseUrl}/anime/animeunity/info',
            queryParameters: {'id': bestMatchId, 'page': page},
          );

          final data = infoResponse.data;
          final episodes = (data['episodes'] as List<dynamic>?)
                  ?.map((e) => Episode(
                        id: e['id'].toString(),
                        animeId: animeId,
                        number: (e['number'] as num?)?.toInt() ?? 0,
                        title: e['title'] ?? 'Episode ${e['number']}',
                        thumbnail: e['image'] ?? data['image'],
                        duration: 0,
                        streamUrl: '',
                      ))
                  .toList() ??
              [];

          return PaginatedEpisodes(
            episodes: episodes,
            hasNextPage: data['hasNextPage'] == true,
          );
        }
      } catch (e) {
        print('Error mapping Jikan episodes: $e');
      }
    }

    // Default fallback
    final anime = await getAnimeById(animeId);
    return PaginatedEpisodes(
      episodes: anime.episodes ?? [],
      hasNextPage: false,
    );
  }

  String _cleanTitle(String title) {
    // Transform "2nd Season" -> "2" (e.g. "Sousou no Frieren 2nd Season" -> "Sousou no Frieren 2")
    var cleaned = title.replaceAllMapped(
        RegExp(r'(\d+)(?:st|nd|rd|th)\s+(?:Season|season)',
            caseSensitive: false),
        (Match m) => '${m.group(1)}');

    // keep alphanumeric, spaces, hyphens, slashes, colons, apostrophes AND SEMICOLONS. Remove brackets and special symbols.
    // e.g. "One Piece (TV)" -> "One Piece"
    // Preserve "/" for titles like "Fate/strange Fake", "Fate/stay night"
    cleaned = cleaned.replaceAll(RegExp(r'\s*\([^)]*\)'), ''); // Remove (...)
    cleaned = cleaned.replaceAll(RegExp(r"[^a-zA-Z0-9\s\-/:';]"),
        ' '); // Replace special chars with space (allow colon, apostrophe, slash, semicolon)
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim(); // Collapse spaces
  }

  Future<List<String>> getGenres() async {
    try {
      final response = await _apiClient.get(AppConstants.animeGenres);
      return (response.data as List<dynamic>).map((e) => e.toString()).toList();
    } catch (e) {
      print('Error fetching genres: $e');
      return [];
    }
  }

  Future<List<Anime>> getNewReleases({int limit = 20, int page = 1}) async {
    try {
      final response = await _apiClient.get(
        AppConstants.animeNewReleases,
        queryParameters: {'limit': limit, 'page': page},
      );

      final List<dynamic> results = response.data is List
          ? response.data as List<dynamic>
          : (response.data['data'] as List<dynamic>? ?? []);
      return results
          .map<Anime>((e) => Anime.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching new releases: $e');
      return [];
    }
  }

  Future<List<Anime>> getTopRated({int limit = 20, int page = 1}) async {
    try {
      final response = await _apiClient.get(
        AppConstants.animeTopRated,
        queryParameters: {'limit': limit, 'page': page},
      );

      final List<dynamic> results = response.data is List
          ? response.data as List<dynamic>
          : (response.data['data'] as List<dynamic>? ?? []);
      return results
          .map<Anime>((e) => Anime.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching top rated: $e');
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
      final List<dynamic> results = response.data is List
          ? response.data as List<dynamic>
          : (response.data['data'] as List<dynamic>? ?? []);
      return results
          .map((e) => Anime.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Anime>> getAiringAnime({int limit = 20, int page = 1}) async {
    try {
      final response = await _apiClient.get(
        AppConstants.animeTopRated,
        queryParameters: {'filter': 'airing', 'page': page, 'limit': limit},
      );
      final List<dynamic> results = response.data is List
          ? response.data as List<dynamic>
          : (response.data['data'] as List<dynamic>? ?? []);
      return results
          .map((e) => Anime.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return getNewReleases(limit: limit);
    }
  }

  Future<List<Anime>> getClassicsAnime({int limit = 20, int page = 1}) async {
    try {
      final response = await _apiClient.get(
        AppConstants.animeTopRated,
        queryParameters: {
          'filter': 'favorite',
          'page': page,
          'limit': limit,
        },
      );
      final List<dynamic> results = response.data is List
          ? response.data as List<dynamic>
          : (response.data['data'] as List<dynamic>? ?? []);
      return results
          .map((e) => Anime.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return getTopRated(limit: limit);
    }
  }

  /// Extract season number from title strings
  int? _extractSeasonNumber(
      String title, String? titleEnglish, String? titleRomaji) {
    final allTitles = [title, titleEnglish, titleRomaji].whereType<String>();

    for (final t in allTitles) {
      // Pattern: "Season X" or "Season X Part Y"
      final seasonMatch =
          RegExp(r'Season\s*(\d+)', caseSensitive: false).firstMatch(t);
      if (seasonMatch != null) {
        return int.tryParse(seasonMatch.group(1)!);
      }

      // Pattern: "Title 2", "Title 3" at the end (but NOT "Part 1", "Part 2")
      // Match number at end of string, or before a colon, but NOT if preceded by "Part"
      final numSuffixMatch = RegExp(r'(?<!Part\s)(\d+)\s*$').firstMatch(t);
      if (numSuffixMatch != null) {
        final num = int.tryParse(numSuffixMatch.group(1)!);
        // Only return if it's a reasonable season number (2-10)
        if (num != null && num >= 2 && num <= 10) {
          return num;
        }
      }

      // Pattern: "2nd Season", "3rd Season"
      final ordinalMatch =
          RegExp(r'(\d+)(?:st|nd|rd|th)\s*Season', caseSensitive: false)
              .firstMatch(t);
      if (ordinalMatch != null) {
        return int.tryParse(ordinalMatch.group(1)!);
      }

      // Pattern: Roman numerals at end "Title II", "Title III"
      final romanMatch =
          RegExp(r'\s+(II|III|IV|V|VI|VII|VIII|IX|X)\s*$', caseSensitive: false)
              .firstMatch(t);
      if (romanMatch != null) {
        final roman = romanMatch.group(1)!.toUpperCase();
        const romanMap = {
          'II': 2,
          'III': 3,
          'IV': 4,
          'V': 5,
          'VI': 6,
          'VII': 7,
          'VIII': 8,
          'IX': 9,
          'X': 10
        };
        return romanMap[roman];
      }

      // Pattern: "Part X" when no season specified often means sequel
      final partMatch =
          RegExp(r'Part\s*(\d+)', caseSensitive: false).firstMatch(t);
      if (partMatch != null) {
        // Part alone usually means it's a continuation
        // Check if title also has "Season" - if not, part number might indicate season
        if (!t.toLowerCase().contains('season')) {
          final partNum = int.tryParse(partMatch.group(1)!);
          // "Part 1" of a titled sequel (e.g., "Jujutsu Kaisen: The Culling Game Part 1")
          // is likely season 3 - but we can't know for sure without more context
          // For now, just return null and let other heuristics handle it
        }
      }
    }

    // Check by subtitle patterns that indicate sequels
    for (final t in allTitles) {
      // Common sequel subtitle patterns
      if (t.toLowerCase().contains('shippuden') ||
          t.toLowerCase().contains('next generation') ||
          t.toLowerCase().contains('the final season') ||
          t.toLowerCase().contains('final season')) {
        return 2; // These are typically "second" iterations
      }

      // "Z" suffix often means sequel (like Dragon Ball Z)
      if (RegExp(r'\sZ\s*$', caseSensitive: false).hasMatch(t)) {
        return 2;
      }
    }

    return null; // Season 1 or unknown
  }

  /// Get anime schedule for a specific day
  Future<List<Anime>> getSchedule(String day) async {
    try {
      // If using Jikan
      if (getActiveSource() == 'jikan') {
        final response = await _apiClient.get(
          '${AppConstants.jikanSchedules}/$day',
        );

        if (response.statusCode == 200) {
          final data = response.data['data'] as List<dynamic>?;
          if (data != null) {
            return data
                .map((e) => Anime.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
      }
      // Fallback or implementation for other sources if available
      // For now returning empty list if not Jikan as other sources might not support schedule
      return [];
    } catch (e) {
      print('Error fetching schedule for $day: $e');
      return [];
    }
  }

  /// Resolve the actual stream URL for a given episode
  Future<Map<String, dynamic>> resolveStreamUrl(String episodeId,
      {String? source}) async {
    final activeSource = source ?? getActiveSource();

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
      print('Error resolving stream URL: $e');
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
      data: (json['data'] as List<dynamic>)
          .map<Anime>((e) => Anime.fromJson(e as Map<String, dynamic>))
          .toList(),
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
