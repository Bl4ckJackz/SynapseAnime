import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/anime.dart';
import '../../data/repositories/anime_repository.dart';
import '../../domain/providers/active_source_provider.dart';

import '../../domain/entities/episode.dart';

final animeListProvider = FutureProvider.autoDispose
    .family<List<Anime>, AnimeFilter>((ref, filter) async {
  // Watch the active source ID so this provider re-runs when it changes
  ref.watch(activeSourceIdProvider);
  final repository = ref.watch(animeRepositoryProvider);

  if (filter.type == FilterType.newReleases) {
    return repository.getNewReleases();
  } else if (filter.type == FilterType.topRated) {
    return repository.getTopRated();
  } else if (filter.type == FilterType.airing) {
    return repository.getAiringAnime();
  } else if (filter.type == FilterType.classics) {
    return repository.getClassicsAnime();
  } else if (filter.type == FilterType.popular) {
    return repository.getPopularAnime();
  } else if (filter.type == FilterType.upcoming) {
    return repository.getUpcomingAnime();
  } else {
    // Default search/filter
    final response = await repository.getAnimeList(
      genre: filter.genre,
      status: filter.status,
      search: filter.search,
      page: filter.page,
    );
    return response.data;
  }
});

final animeDetailsProvider =
    FutureProvider.autoDispose.family<Anime, String>((ref, id) async {
  ref.watch(activeSourceIdProvider);
  return ref.watch(animeRepositoryProvider).getAnimeById(id);
});

final animeEpisodesProvider = AsyncNotifierProvider.autoDispose
    .family<AnimeEpisodesNotifier, List<Episode>, String>(
        AnimeEpisodesNotifier.new);

class AnimeEpisodesNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<Episode>, String> {
  @override
  Future<List<Episode>> build(String arg) async {
    ref.watch(activeSourceIdProvider);
    final repository = ref.watch(animeRepositoryProvider);

    // Use getAllEpisodes for automatic pagination - loads all pages
    return repository.getAllEpisodes(arg);
  }

  /// Force refresh all episodes
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build(arg));
  }
}

enum FilterType {
  list,
  newReleases,
  topRated,
  search,
  airing,
  classics,
  popular,
  upcoming
}

class AnimeFilter {
  final FilterType type;
  final String? genre;
  final String? status;
  final String? search;
  final int page;

  const AnimeFilter({
    this.type = FilterType.list,
    this.genre,
    this.status,
    this.search,
    this.page = 1,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnimeFilter &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          genre == other.genre &&
          status == other.status &&
          search == other.search &&
          page == other.page;

  @override
  int get hashCode =>
      type.hashCode ^
      genre.hashCode ^
      status.hashCode ^
      search.hashCode ^
      page.hashCode;
}
