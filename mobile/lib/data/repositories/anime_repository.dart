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

    // ID Resolution: If we have a numeric ID (Jikan) but active source is a Consumet provider
    String targetId = id;
    if (active != 'jikan' && RegExp(r'^\d+$').hasMatch(id)) {
      try {
        // 1. Get title from Jikan first
        final jikanAnime = await _getJikanAnimeById(id);
        // 2. Search on active provider
        final searchResults = await getAnimeList(search: jikanAnime.title);
        if (searchResults.data.isNotEmpty) {
          // Use the first result's ID as the target provider ID
          targetId = searchResults.data.first.id;
        } else {
          // Fallback to Jikan if not found on provider
          return jikanAnime;
        }
      } catch (e) {
        print('Error resolving ID for $active: $e');
        // Fallback to Jikan
        return _getJikanAnimeById(id);
      }
    }

    if (active == 'jikan' && RegExp(r'^\d+$').hasMatch(targetId)) {
      return _getJikanAnimeById(targetId);
    } else {
      // If active is Jikan but ID is not numeric, it's likely a Consumet ID (e.g. from New Releases)
      // We'll default to 'hianime' or 'gogoanime' if active is 'jikan'
      final effectiveSource =
          (active == 'jikan' && !RegExp(r'^\d+$').hasMatch(targetId))
              ? 'animeunity' // Default fallback for string IDs
              : active;

      // Consumet Info API: http://localhost:3002/anime/[provider]/info?id=[id]
      final List<dynamic> allEpisodes = [];
      int currentPage = 1;
      bool hasNextPage = true;
      Map<String, dynamic> mainData = {};

      while (hasNextPage) {
        final response = await _apiClient.get(
          '${AppConstants.consumetBaseUrl}/anime/$effectiveSource/info',
          queryParameters: {'id': targetId, 'page': currentPage},
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
    final active = getActiveSource();

    if (active == 'jikan' && RegExp(r'^\d+$').hasMatch(animeId)) {
      try {
        String? bestMatchId;

        // Manual overrides for problematic anime (Jikan ID -> AnimeUnity ID)
        final manualOverrides = <String, String>{
          '1735': '430-naruto-shippuden', // Naruto: Shippuuden
        };

        if (manualOverrides.containsKey(animeId)) {
          bestMatchId = manualOverrides[animeId];
          print('Using manual override ID: $bestMatchId');
        } else {
          final jikanAnime = await _getJikanAnimeById(animeId);

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

          String? fallbackId;

          // Try each title variant until we find results
          for (final titleVariant in titlesToTry) {
            print('Searching AnimeUnity with title variant: $titleVariant');
            try {
              final searchResponse = await _apiClient.get(
                '${AppConstants.consumetBaseUrl}/anime/animeunity/${Uri.encodeComponent(titleVariant)}',
              );
              final results =
                  searchResponse.data['results'] as List<dynamic>? ?? [];

              if (results.isNotEmpty) {
                // Try to find EXACT match first
                // Find ALL exact matches
                final exactMatches = results.where((r) {
                  final resultTitle = _cleanTitle(r['title'].toString());
                  return resultTitle.toLowerCase() ==
                      titleVariant.toLowerCase();
                }).toList();

                if (exactMatches.isNotEmpty) {
                  // Sort: Prefer titles WITHOUT "ITA"
                  exactMatches.sort((a, b) {
                    final aTitle = a['title'].toString().toUpperCase();
                    final bTitle = b['title'].toString().toUpperCase();
                    final aHasIta = aTitle.contains('ITA');
                    final bHasIta = bTitle.contains('ITA');

                    if (aHasIta && !bHasIta) return 1; // b comes first
                    if (!aHasIta && bHasIta) return -1; // a comes first
                    return 0;
                  });

                  final bestMatch = exactMatches.first;
                  bestMatchId = bestMatch['id'].toString();
                  print(
                      'Found EXACT match (Preferred): ${bestMatch['title']} ($bestMatchId)');
                  break; // Found perfect match, stop searching
                }

                // If no exact match but we have results, store the first one as fallback
                if (fallbackId == null) {
                  fallbackId = results.first['id'].toString();
                  print('Stored fallback ID: $fallbackId');
                }
              }
            } catch (e) {
              print('Search failed for "$titleVariant": $e');
            }
          }

          // Use fallback if no exact match found
          bestMatchId ??= fallbackId;
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
    final active = getActiveSource();

    if (active == 'jikan' && RegExp(r'^\d+$').hasMatch(animeId)) {
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

    // keep alphanumeric, spaces, hyphens and COLONS. Remove brackets and special symbols.
    // e.g. "One Piece (TV)" -> "One Piece"
    cleaned = cleaned.replaceAll(RegExp(r'\s*\([^)]*\)'), ''); // Remove (...)
    cleaned = cleaned.replaceAll(RegExp(r"[^a-zA-Z0-9\s\-:']"),
        ' '); // Replace special chars with space (allow colon and apostrophe)
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
