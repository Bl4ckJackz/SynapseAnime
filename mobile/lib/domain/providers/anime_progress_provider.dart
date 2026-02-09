import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_client.dart';
import '../../core/constants.dart';

class AnimeProgress {
  final String animeId;
  final int totalEpisodes;
  final int watchedEpisodes;
  final int inProgressEpisodes;
  final int completionPercentage;
  final Map<String, EpisodeProgress> episodeProgress;

  AnimeProgress({
    required this.animeId,
    required this.totalEpisodes,
    required this.watchedEpisodes,
    required this.inProgressEpisodes,
    required this.completionPercentage,
    required this.episodeProgress,
  });

  factory AnimeProgress.fromJson(Map<String, dynamic> json) {
    final episodeProgressList = json['episodeProgress'] as List<dynamic>? ?? [];
    final Map<String, EpisodeProgress> progressMap = {};

    for (final ep in episodeProgressList) {
      final episodeId = ep['episodeId'] as String;
      progressMap[episodeId] =
          EpisodeProgress.fromJson(ep as Map<String, dynamic>);
    }

    return AnimeProgress(
      animeId: json['animeId'] as String,
      totalEpisodes: json['totalEpisodes'] as int? ?? 0,
      watchedEpisodes: json['watchedEpisodes'] as int? ?? 0,
      inProgressEpisodes: json['inProgressEpisodes'] as int? ?? 0,
      completionPercentage: json['completionPercentage'] as int? ?? 0,
      episodeProgress: progressMap,
    );
  }

  EpisodeProgress? getProgressForEpisode(String episodeId) {
    return episodeProgress[episodeId];
  }
}

class EpisodeProgress {
  final String episodeId;
  final int? episodeNumber;
  final int progressSeconds;
  final int duration;
  final bool completed;
  final int progressPercent;

  EpisodeProgress({
    required this.episodeId,
    this.episodeNumber,
    required this.progressSeconds,
    required this.duration,
    required this.completed,
    required this.progressPercent,
  });

  factory EpisodeProgress.fromJson(Map<String, dynamic> json) {
    return EpisodeProgress(
      episodeId: json['episodeId'] as String,
      episodeNumber: json['episodeNumber'] as int?,
      progressSeconds: json['progressSeconds'] as int? ?? 0,
      duration: json['duration'] as int? ?? 0,
      completed: json['completed'] as bool? ?? false,
      progressPercent: json['progressPercent'] as int? ?? 0,
    );
  }

  double get progressFraction => progressPercent / 100.0;
}

class AnimeProgressNotifier extends StateNotifier<AsyncValue<AnimeProgress?>> {
  final ApiClient _apiClient;
  final String animeId;

  AnimeProgressNotifier(this._apiClient, this.animeId)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      state = const AsyncValue.loading();
      final response = await _apiClient
          .get('${AppConstants.usersPath}/anime/$animeId/progress');
      final progress =
          AnimeProgress.fromJson(response.data as Map<String, dynamic>);
      state = AsyncValue.data(progress);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void refresh() => load();
}

final animeProgressProvider = StateNotifierProvider.family<
    AnimeProgressNotifier, AsyncValue<AnimeProgress?>, String>(
  (ref, animeId) {
    return AnimeProgressNotifier(ref.read(apiClientProvider), animeId);
  },
);
