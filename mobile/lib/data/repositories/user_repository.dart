import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/anime.dart';
import '../../domain/entities/episode.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/manga.dart';
import '../../core/constants.dart';
import '../api_client.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.read(apiClientProvider));
});

class UserRepository {
  final ApiClient _apiClient;

  UserRepository(this._apiClient);

  // Profile
  Future<User> getProfile() async {
    final response = await _apiClient.get(AppConstants.usersProfile);
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  Future<User> updateProfile({
    String? username,
    String? email,
    String? avatar,
  }) async {
    final response = await _apiClient.put(
      AppConstants.usersProfile,
      data: {
        if (username != null) 'username': username,
        if (email != null) 'email': email,
        if (avatar != null) 'avatar': avatar,
      },
    );
    return User.fromJson(response.data as Map<String, dynamic>);
  }

  // Watchlist
  Future<List<WatchlistItem>> getWatchlist() async {
    final response = await _apiClient.get(AppConstants.usersWatchlist);
    return (response.data as List<dynamic>)
        .map((e) => WatchlistItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addToWatchlist(String animeId) async {
    await _apiClient.post('${AppConstants.usersWatchlist}/$animeId');
  }

  Future<void> removeFromWatchlist(String animeId) async {
    await _apiClient.delete('${AppConstants.usersWatchlist}/$animeId');
  }

  Future<bool> isInWatchlist(String animeId) async {
    final response =
        await _apiClient.get('${AppConstants.usersWatchlist}/$animeId/check');
    return (response.data as Map<String, dynamic>)['inWatchlist'] as bool;
  }

  // Manga Watchlist
  Future<void> addMangaToWatchlist(String mangaId) async {
    await _apiClient.post('${AppConstants.usersWatchlist}/manga/$mangaId');
  }

  Future<void> removeMangaFromWatchlist(String mangaId) async {
    await _apiClient.delete('${AppConstants.usersWatchlist}/manga/$mangaId');
  }

  Future<bool> isMangaInWatchlist(String mangaId) async {
    final response = await _apiClient
        .get('${AppConstants.usersWatchlist}/manga/$mangaId/check');
    return (response.data as Map<String, dynamic>)['inWatchlist'] as bool;
  }

  // Watch History & Continue Watching
  Future<List<WatchHistoryItem>> getContinueWatching({int limit = 10}) async {
    final response = await _apiClient.get(
      AppConstants.usersContinueWatching,
      queryParameters: {'limit': limit},
    );
    return (response.data as List<dynamic>)
        .map((e) => WatchHistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateProgress({
    required String episodeId,
    required int progressSeconds,
    required String? animeId,
    required String? animeTitle,
    required String? animeCover,
    required int? animeTotalEpisodes,
    required int? episodeNumber,
    required String? episodeTitle,
    required String? episodeThumbnail,
    required int duration,
    String? source,
  }) async {
    await _apiClient.post(
      AppConstants.usersProgress,
      data: {
        'episodeId': episodeId,
        'progressSeconds': progressSeconds,
        'duration': duration,
        if (animeId != null) 'animeId': animeId,
        if (animeTitle != null) 'animeTitle': animeTitle,
        if (animeCover != null) 'animeCover': animeCover,
        if (animeTotalEpisodes != null)
          'animeTotalEpisodes': animeTotalEpisodes,
        if (episodeNumber != null) 'episodeNumber': episodeNumber,
        if (episodeTitle != null) 'episodeTitle': episodeTitle,
        if (episodeThumbnail != null) 'episodeThumbnail': episodeThumbnail,
        if (source != null) 'source': source,
      },
    );
  }

  Future<ProgressInfo> getEpisodeProgress(String episodeId) async {
    final response =
        await _apiClient.get('${AppConstants.usersProgress}/$episodeId');
    return ProgressInfo.fromJson(response.data as Map<String, dynamic>);
  }

  // Preferences
  Future<void> updatePreferences({
    List<String>? preferredLanguages,
    List<String>? preferredGenres,
  }) async {
    print('UserRepository: sending update request. Genres: $preferredGenres');
    await _apiClient.put(
      AppConstants.usersPreferences,
      data: {
        if (preferredLanguages != null)
          'preferredLanguages': preferredLanguages,
        if (preferredGenres != null) 'preferredGenres': preferredGenres,
      },
    );
  }
}

class WatchlistItem {
  final String id;
  final Anime? anime;
  final Manga? manga;
  // Wait, we need Manga entity import.
  // Actually, we should import Manga entity from domain.
  final DateTime addedAt;

  WatchlistItem(
      {required this.id, this.anime, this.manga, required this.addedAt});

  factory WatchlistItem.fromJson(Map<String, dynamic> json) {
    return WatchlistItem(
      id: json['id'] as String,
      anime: json['anime'] != null
          ? Anime.fromJson(json['anime'] as Map<String, dynamic>)
          : null,
      // Assuming Manga entity has fromJson.
      // We need to check if Manga entity is available in this file context or import it.
      // We will likely need to cast it to dynamic map.
      // Since I haven't imported Manga entity here yet, I should checkimports.
      // But let's assume I will fix imports in next step or use dynamic for now if needed.
      // Better: Add import at top and use it.
      manga: json['manga'] != null
          ? Manga.fromJson(json['manga'] as Map<String, dynamic>)
          : null, // Error: LocalAnime is for files.
      // We need the Domain Manga entity.
      addedAt: DateTime.parse(json['addedAt'] as String),
    );
  }
}

class WatchHistoryItem {
  final String id;
  final Episode episode;
  final Anime? anime;
  final int progressSeconds;
  final bool completed;
  final DateTime updatedAt;

  WatchHistoryItem({
    required this.id,
    required this.episode,
    this.anime,
    required this.progressSeconds,
    required this.completed,
    required this.updatedAt,
  });

  factory WatchHistoryItem.fromJson(Map<String, dynamic> json) {
    final episodeData = json['episode'] as Map<String, dynamic>;
    return WatchHistoryItem(
      id: json['id'] as String,
      episode: Episode.fromJson(episodeData),
      anime: episodeData['anime'] != null
          ? Anime.fromJson(episodeData['anime'] as Map<String, dynamic>)
          : null,
      progressSeconds: json['progressSeconds'] as int,
      completed: json['completed'] as bool,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  double get progressPercent {
    if (episode.duration == 0) return 0;
    return progressSeconds / episode.duration;
  }
}

class ProgressInfo {
  final int progressSeconds;
  final bool completed;

  ProgressInfo({required this.progressSeconds, required this.completed});

  factory ProgressInfo.fromJson(Map<String, dynamic> json) {
    return ProgressInfo(
      progressSeconds: json['progressSeconds'] as int,
      completed: json['completed'] as bool,
    );
  }
}
