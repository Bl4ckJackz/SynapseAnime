import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/anime.dart';
import '../../domain/entities/episode.dart';
import '../../domain/entities/anime_source.dart';
import '../../core/constants.dart';
import '../api_client.dart';

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
    return [
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
        String? bestMatchId;

        // Manual overrides for problematic anime (Jikan ID -> AnimeUnity ID)
        final manualOverrides = <String, String>{
          '1735': '430-naruto-shippuden', // Naruto: Shippuuden
          '59064':
              '7209-jujutsu-kaisen-3-the-culling-game-part-1', // Jujutsu Kaisen: The Culling Game (Season 3)
          '51009': '5765-jujutsu-kaisen-2', // Jujutsu Kaisen Season 2
        };

        if (manualOverrides.containsKey(animeId)) {
          bestMatchId = manualOverrides[animeId];
          print('Using manual override ID: $bestMatchId');
        } else {
          final jikanAnime = await _getJikanAnimeById(animeId);

          // Extract season number from titles for smarter matching
          final extractedSeason = _extractSeasonNumber(
            jikanAnime.title,
            jikanAnime.titleEnglish,
            jikanAnime.titleRomaji,
          );
          print('DEBUG: Extracted season number: $extractedSeason');

          // Build list of title variants to try
          final titlesToTry = <String>[
            if (jikanAnime.titleRomaji != null &&
                jikanAnime.titleRomaji!.isNotEmpty)
              _cleanTitle(jikanAnime.titleRomaji!),
            if (jikanAnime.titleEnglish != null &&
                jikanAnime.titleEnglish!.isNotEmpty)
              _cleanTitle(jikanAnime.titleEnglish!),
            _cleanTitle(jikanAnime.title),
          ].toSet().toList(); // Remove duplicates

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
          // e.g. "Shingeki no Kyojin Season 3 Part 2" -> "Shingeki no Kyojin 3", "Shingeki no Kyojin"
          final currentTitles = List<String>.from(titlesToTry);
          for (final t in currentTitles) {
            // Remove "Part X" suffix: "Season 3 Part 2" -> "Season 3"
            final withoutPart = t
                .replaceAll(
                    RegExp(r'\s*Part\.?\s*\d+', caseSensitive: false), '')
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
                .replaceAll(
                    RegExp(r'\s*Season\s*\d+', caseSensitive: false), '')
                .replaceAll(
                    RegExp(r'\s*Part\.?\s*\d+', caseSensitive: false), '')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
            if (baseTitle != t &&
                baseTitle.isNotEmpty &&
                baseTitle.length > 3) {
              titlesToTry.add(baseTitle);
            }

            // Remove subtitle after ":" or " - " for base title
            // e.g. "Jujutsu Kaisen: The Culling Game Part 1" -> "Jujutsu Kaisen"
            if (t.contains(':')) {
              final mainTitle = t.split(':').first.trim();
              if (mainTitle.isNotEmpty && mainTitle.length > 3) {
                titlesToTry.add(mainTitle);
                // Also try with season number appended (for sequels)
                // Detect if it's a sequel based on keywords
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

          // Collect all candidates from all search variants
          final List<Map<String, dynamic>> allCandidates = [];

          // Try each title variant to collect results
          for (final titleVariant in titlesToTry) {
            print('Searching AnimeUnity with title variant: $titleVariant');
            try {
              final searchResponse = await _apiClient.get(
                '${AppConstants.consumetBaseUrl}/anime/animeunity/${Uri.encodeComponent(titleVariant)}',
              );
              final results =
                  searchResponse.data['results'] as List<dynamic>? ?? [];

              // Add all results to candidates list
              for (final r in results) {
                allCandidates.add(r as Map<String, dynamic>);
              }
            } catch (e) {
              print('Search failed for "$titleVariant": $e');
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

          print('DEBUG: Found ${allCandidates.length} unique candidates');

          // Score each candidate based on season match
          if (allCandidates.isNotEmpty) {
            int bestScore = -1000;
            Map<String, dynamic>? bestCandidate;

            for (final candidate in allCandidates) {
              int score = 0;
              final candId = candidate['id'].toString().toLowerCase();
              final candTitle = candidate['title'].toString();
              final candTitleLower = candTitle.toLowerCase();

              // Extract season number from AnimeUnity ID
              // Examples: "attack-on-titan-3" -> 3, "attack-on-titan-3-part-2" -> 3 (not 2!)
              // We need to find the SEASON number, not the PART number
              // Remove "part-X" and "ita" suffixes before extracting
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

              // Check if we're looking for Part 2 specifically
              final originalHasPart2 =
                  titlesToTry.first.toLowerCase().contains('part 2');

              // Check if original title has a subtitle (suggesting it's a sequel)
              // e.g., "Jujutsu Kaisen: The Culling Game" or "Title - Subtitle"
              final hasSubtitle = titlesToTry.first.contains(':') ||
                  titlesToTry.first.contains(' - ');

              // If we detected a season from Jikan title
              if (extractedSeason != null && extractedSeason > 1) {
                // Prefer candidates with matching season number
                if (candSeasonFromId == extractedSeason) {
                  score += 200; // Strong match
                  print(
                      'DEBUG: $candId - season $candSeasonFromId matches extracted season (+200)');

                  // Additional check for Part 2 within the same season
                  if (originalHasPart2) {
                    if (hasPart2) {
                      score += 100; // Perfect match - same season AND Part 2
                      print('DEBUG: $candId - has Part 2 as expected (+100)');
                    } else {
                      score -= 50; // Right season but wrong part
                      print('DEBUG: $candId - missing Part 2 (-50)');
                    }
                  }
                } else if (candSeasonFromId != null &&
                    candSeasonFromId != extractedSeason) {
                  score -= 100; // Wrong season
                  print(
                      'DEBUG: $candId - season $candSeasonFromId != extracted season $extractedSeason (-100)');
                } else if (candSeasonFromId == null) {
                  // No season in ID - likely season 1
                  score -= 50;
                  print('DEBUG: $candId - no season in ID (likely S1) (-50)');
                }
              } else if (hasSubtitle) {
                // Original has subtitle but we couldn't extract season number
                // This might be a sequel with a unique subtitle (like "The Culling Game")
                // Prefer candidates that ALSO have numbers in their ID
                if (candSeasonFromId != null && candSeasonFromId > 1) {
                  score += 100; // Bonus for having a season number
                  print(
                      'DEBUG: $candId - has season $candSeasonFromId and original has subtitle (+100)');
                } else if (candSeasonFromId == null) {
                  // No season in ID but original has subtitle - likely wrong
                  score -= 30;
                  print(
                      'DEBUG: $candId - no season in ID but original has subtitle (-30)');
                }
              } else {
                // Looking for season 1 - prefer IDs WITHOUT numbers
                if (candSeasonFromId == null || candSeasonFromId == 1) {
                  score += 50;
                } else if (candSeasonFromId != null && candSeasonFromId > 1) {
                  score -= 100; // This is a sequel, not what we want
                }
              }

              // Penalize ITA (dubbed) versions
              if (candTitleLower.contains('ita')) {
                score -= 30;
              }

              // EXACT title match bonus - but only for PRIMARY search variants
              // (original titles before derived variants were added)
              // We want to reward matching "Jujutsu Kaisen: The Culling Game Part 1"
              // but NOT matching just "Jujutsu Kaisen" when looking for a sequel
              final primaryVariants =
                  titlesToTry.take(originalTitleCount).toList();
              final derivedVariants =
                  titlesToTry.skip(originalTitleCount).toList();

              bool isPrimaryMatch = false;
              for (final searchVariant in primaryVariants) {
                if (candTitleLower == searchVariant.toLowerCase()) {
                  score += 150; // Strong bonus for exact match to primary title
                  isPrimaryMatch = true;
                  print('DEBUG: $candId - EXACT PRIMARY title match (+150)');
                  break;
                }
              }

              // For derived variants (base titles like "Jujutsu Kaisen"),
              // only give a small bonus if no season mismatch
              if (!isPrimaryMatch) {
                for (final searchVariant in derivedVariants) {
                  if (candTitleLower == searchVariant.toLowerCase()) {
                    // This is likely a base title match - could be wrong season
                    // Only give small bonus if we think it's season 1
                    if (extractedSeason == null || extractedSeason == 1) {
                      score += 30; // Smaller bonus for derived match
                      print('DEBUG: $candId - exact derived title match (+30)');
                    } else {
                      // We're looking for a sequel but matched base title - likely wrong!
                      print(
                          'DEBUG: $candId - derived match but looking for season $extractedSeason (no bonus)');
                    }
                    break;
                  }
                }
              }

              // Base title match bonus (partial match)
              final baseSearchTitle = titlesToTry.first
                  .toLowerCase()
                  .split(':')
                  .first
                  .split(' - ')
                  .first
                  .trim();
              if (candTitleLower.contains(baseSearchTitle)) {
                score += 10;
              }

              print('DEBUG: Candidate $candId ("$candTitle") = score $score');

              if (score > bestScore) {
                bestScore = score;
                bestCandidate = candidate;
              }
            }

            if (bestCandidate != null) {
              bestMatchId = bestCandidate['id'].toString();
              print(
                  'Selected best match: ${bestCandidate['title']} ($bestMatchId) with score $bestScore');
            }
          }
        } // Close else block

        if (bestMatchId != null) {
          // Fetch ALL pages of episodes
          final List<Episode> allEpisodes = [];
          int currentPage = 1;
          bool hasNextPage = true;
          String? coverImage;
          int? totalEpisodes;

          while (hasNextPage) {
            print('Fetching episodes page $currentPage for $bestMatchId');
            final infoResponse = await _apiClient.get(
              '${AppConstants.consumetBaseUrl}/anime/animeunity/info',
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
                          thumbnail: e['image'] ?? coverImage,
                          duration: 0,
                          streamUrl: '',
                        ))
                    .toList() ??
                [];

            if (pageEpisodes.isEmpty) {
              hasNextPage = false;
            } else {
              allEpisodes.addAll(pageEpisodes);

              // Continue if explicit hasNextPage is true OR we haven't reached total episodes yet
              hasNextPage = (data['hasNextPage'] == true) ||
                  (totalEpisodes != null && allEpisodes.length < totalEpisodes);

              currentPage++;
            }

            // Safety limit to prevent infinite loops (increased to 50 pages ~ 6000 episodes)
            if (currentPage > 50) break;
          }

          print(
              'Total episodes loaded: ${allEpisodes.length} / ${totalEpisodes ?? '?'}');
          return allEpisodes;
        }
      } catch (e) {
        print('Error fetching episodes: $e');
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

    // keep alphanumeric, spaces, hyphens, slashes, colons, and apostrophes. Remove brackets and special symbols.
    // e.g. "One Piece (TV)" -> "One Piece"
    // Preserve "/" for titles like "Fate/strange Fake", "Fate/stay night"
    cleaned = cleaned.replaceAll(RegExp(r'\s*\([^)]*\)'), ''); // Remove (...)
    cleaned = cleaned.replaceAll(RegExp(r"[^a-zA-Z0-9\s\-/:']"),
        ' '); // Replace special chars with space (allow colon, apostrophe, slash)
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim(); // Collapse spaces
  }

  Future<String> resolveStreamUrl(String episodeId) async {
    final active =
        getActiveSource() == 'jikan' ? 'animeunity' : getActiveSource();
    // Encode ID: slashes should be encoded (2549-demon-slayer/44417 -> 2549-demon-slayer%2F44417)
    final encodedId = Uri.encodeComponent(episodeId);

    // Consumet Watch API: http://localhost:3002/anime/[provider]/watch/[encoded_id]
    final response = await _apiClient.get(
      '${AppConstants.consumetBaseUrl}/anime/$active/watch/$encodedId',
    );

    final sources = response.data['sources'] as List<dynamic>?;
    if (sources != null && sources.isNotEmpty) {
      // Prefer highest quality or just the first one
      return sources.first['url'];
    }
    return '';
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

  /// Fetches anime schedule for a specific day of the week
  Future<List<Anime>> getSchedule(String day) async {
    try {
      final response = await _apiClient.get(
        '/jikan/anime/schedule',
        queryParameters: {'day': day.toLowerCase()},
      );

      final List<dynamic> results = response.data is List
          ? response.data as List<dynamic>
          : (response.data['data'] as List<dynamic>? ?? []);

      return results
          .map((e) => Anime.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching schedule for $day: $e');
      return [];
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
