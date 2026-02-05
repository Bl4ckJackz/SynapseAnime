import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/anime.dart';
import '../../features/anime/data/repositories/anime_repository.dart';
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

final animeGenreProvider = AsyncNotifierProvider.autoDispose
    .family<PaginatedGenreNotifier, List<Anime>, String>(
        PaginatedGenreNotifier.new);

class PaginatedGenreNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<Anime>, String> {
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  Future<List<Anime>> build(String arg) async {
    _page = 1;
    _hasMore = true;
    _isLoadingMore = false;
    ref.watch(activeSourceIdProvider);
    return _fetchPage(arg, 1);
  }

  Future<List<Anime>> _fetchPage(String genre, int page) async {
    final repository = ref.read(animeRepositoryProvider);
    try {
      final response = await repository.getAnimeList(
        genre: genre,
        page: page,
      );
      // If we got fewer items than limit (20), assume no more pages
      if (response.data.length < 20) {
        _hasMore = false;
      }
      return response.data;
    } catch (e) {
      // On error, if it's jikan 404/429 maybe stop?
      // For now just return empty, but keep hasMore true to retry?
      // Let's assume on error we stop only if specific conditions met
      return [];
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;

    _isLoadingMore = true;
    // Don't set state to loading, just append results
    // We can't easily notify "loading more" without changing state type to compound object
    // But simplistic approach: just append when done.

    final newItems = await _fetchPage(arg, _page + 1);

    if (newItems.isNotEmpty) {
      _page++;
      final currentList = state.value ?? [];
      state = AsyncData([...currentList, ...newItems]);
    } else {
      _hasMore = false;
    }
    _isLoadingMore = false;
  }
}
