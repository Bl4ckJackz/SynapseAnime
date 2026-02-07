import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/manga.dart';
import '../entities/chapter.dart';
import '../../data/repositories/manga_repository.dart';

/// Provider for top manga from Jikan
final topMangaProvider = FutureProvider.autoDispose<List<Manga>>((ref) async {
  final repository = ref.watch(mangaRepositoryProvider);
  return repository.getTopManga();
});

/// Provider for trending manga
final trendingMangaProvider =
    FutureProvider.autoDispose<List<Manga>>((ref) async {
  final repository = ref.watch(mangaRepositoryProvider);
  return repository.getTrendingManga();
});

/// Provider for recently updated manga
final recentlyUpdatedMangaProvider =
    FutureProvider.autoDispose<List<Manga>>((ref) async {
  final repository = ref.watch(mangaRepositoryProvider);
  return repository.getRecentlyUpdatedManga();
});

/// Provider for popular Manhwa (Korean)
final manhwaMangaProvider =
    FutureProvider.autoDispose<List<Manga>>((ref) async {
  final repository = ref.watch(mangaRepositoryProvider);
  return repository.getTopManga(type: 'manhwa', limit: 20);
});

/// Provider for popular Manhua (Chinese)
final manhuaMangaProvider =
    FutureProvider.autoDispose<List<Manga>>((ref) async {
  final repository = ref.watch(mangaRepositoryProvider);
  return repository.getTopManga(type: 'manhua', limit: 20);
});

/// Provider for manga search
final mangaSearchProvider =
    FutureProvider.autoDispose.family<List<Manga>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final repository = ref.watch(mangaRepositoryProvider);
  return repository.searchManga(query);
});

/// Provider for MangaDex search
final mangaDexSearchProvider =
    FutureProvider.autoDispose.family<List<Manga>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final repository = ref.watch(mangaRepositoryProvider);
  return repository.searchMangaOnMangaDex(query);
});

/// Provider for manga details
final mangaDetailsProvider =
    FutureProvider.autoDispose.family<Manga, String>((ref, id) async {
  final repository = ref.watch(mangaRepositoryProvider);
  return repository.getMangaDetails(id);
});

/// Provider for manga chapters
final mangaChaptersProvider = FutureProvider.autoDispose
    .family<List<MangaChapter>, ChapterListRequest>((ref, request) async {
  final repository = ref.watch(mangaRepositoryProvider);
  return repository.getChapters(
    request.mangaId,
    title: request.title,
    titleEnglish: request.titleEnglish,
    preferredSource: request.preferredSource,
  );
});

/// Provider for chapter pages
final chapterPagesProvider = FutureProvider.autoDispose
    .family<List<String>, ChapterRequest>((ref, request) async {
  final repository = ref.watch(mangaRepositoryProvider);
  return repository.getChapterPages(request.mangaId, request.chapterId);
});

/// Provider for MangaHook manga list
final mangaHookListProvider = FutureProvider.autoDispose
    .family<List<Manga>, MangaListFilter>((ref, filter) async {
  final repository = ref.watch(mangaRepositoryProvider);
  return repository.getMangaHookList(
    page: filter.page,
    type: filter.type,
    category: filter.category,
  );
});

/// Provider for manga genres
final mangaGenresProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(mangaRepositoryProvider);
  return repository.getGenres();
});

/// State notifier for manga search query
final mangaSearchQueryProvider = StateProvider<String>((ref) => '');

/// Request class for chapter pages
class ChapterRequest {
  final String mangaId;
  final String chapterId;

  const ChapterRequest({required this.mangaId, required this.chapterId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterRequest &&
          mangaId == other.mangaId &&
          chapterId == other.chapterId;

  @override
  int get hashCode => mangaId.hashCode ^ chapterId.hashCode;
}

/// Filter for manga list
class MangaListFilter {
  final int page;
  final String? type;
  final String? category;

  const MangaListFilter({
    this.page = 1,
    this.type,
    this.category,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MangaListFilter &&
          page == other.page &&
          type == other.type &&
          category == other.category;

  @override
  int get hashCode => page.hashCode ^ type.hashCode ^ category.hashCode;
}

/// Request class for chapter list
class ChapterListRequest {
  final String mangaId;
  final String? title;
  final String? titleEnglish;
  final String? preferredSource;
  final String? preferredLanguage;

  const ChapterListRequest({
    required this.mangaId,
    this.title,
    this.titleEnglish,
    this.preferredSource,
    this.preferredLanguage,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChapterListRequest &&
          mangaId == other.mangaId &&
          title == other.title &&
          titleEnglish == other.titleEnglish &&
          preferredSource == other.preferredSource &&
          preferredLanguage == other.preferredLanguage;

  @override
  int get hashCode =>
      mangaId.hashCode ^
      title.hashCode ^
      titleEnglish.hashCode ^
      preferredSource.hashCode ^
      preferredLanguage.hashCode;
}

class PaginatedResult<T> {
  final List<T> items;
  final bool hasMore;

  const PaginatedResult(this.items, {this.hasMore = true});
}

enum MangaFilterType {
  top,
  trending,
  updated,
  manhwa,
  manhua,
  query,
}

class MangaFilter {
  final MangaFilterType type;
  final String title;
  final String? query;

  const MangaFilter({
    required this.type,
    required this.title,
    this.query,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MangaFilter &&
          type == other.type &&
          title == other.title &&
          query == other.query;

  @override
  int get hashCode => type.hashCode ^ title.hashCode ^ query.hashCode;
}

final paginatedMangaFilterProvider = AsyncNotifierProvider.autoDispose
    .family<PaginatedMangaFilterNotifier, PaginatedResult<Manga>, MangaFilter>(
        PaginatedMangaFilterNotifier.new);

class PaginatedMangaFilterNotifier extends AutoDisposeFamilyAsyncNotifier<
    PaginatedResult<Manga>, MangaFilter> {
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  Future<PaginatedResult<Manga>> build(MangaFilter arg) async {
    _page = 1;
    _hasMore = true;
    _isLoadingMore = false;
    final items = await _fetchPage(arg, 1);
    return PaginatedResult(items, hasMore: _hasMore);
  }

  Future<List<Manga>> _fetchPage(MangaFilter filter, int page) async {
    final repository = ref.read(mangaRepositoryProvider);
    const int limit = 20;
    List<Manga> results = [];

    try {
      switch (filter.type) {
        case MangaFilterType.top:
          results = await repository.getTopManga(page: page, limit: limit);
          break;
        case MangaFilterType.trending:
          // Trending (Popular) in Jikan logic usually supports page
          results = await repository.getTrendingManga(
              limit: limit); // Check if page arg exists in repo for trending
          // If repo method doesn't support page, we might need to update repo or just accept page 1 forever (bad).
          // Looking at repo code earlier:
          // getTrendingManga({int limit = 20}) async { ... queryParameters: {'filter': 'bypopularity', 'page': 1} ... }
          // It HARDCODES page 1. I need to fix repository first or override here.
          // I will fix repository method to accept page argument in next step. For now I assume it will support it.
          // results = await repository.getTrendingManga(page: page, limit: limit);
          break;
        case MangaFilterType.updated:
          results = await repository.getRecentlyUpdatedManga(
              limit: limit); // Check repo
          break;
        case MangaFilterType.manhwa:
          results = await repository.getTopManga(
              page: page, type: 'manhwa', limit: limit);
          break;
        case MangaFilterType.manhua:
          results = await repository.getTopManga(
              page: page, type: 'manhua', limit: limit);
          break;
        case MangaFilterType.query:
          if (filter.query != null && filter.query!.isNotEmpty) {
            results = await repository.searchManga(filter.query!, page: page);
          }
          break;
      }

      if (results.length < limit) {
        _hasMore = false;
      }
      return results;
    } catch (e) {
      _hasMore = false;
      return [];
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;

    _isLoadingMore = true;

    final newItems = await _fetchPage(arg, _page + 1);

    if (newItems.isNotEmpty) {
      _page++;
      final currentList = state.value?.items ?? [];

      final existingIds = currentList.map((e) => e.id).toSet();
      final uniqueNewItems =
          newItems.where((e) => !existingIds.contains(e.id)).toList();

      if (uniqueNewItems.isNotEmpty) {
        state = AsyncData(PaginatedResult(
          [...currentList, ...uniqueNewItems],
          hasMore: _hasMore,
        ));
      }
    } else {
      _hasMore = false;
      final currentList = state.value?.items ?? [];
      state = AsyncData(PaginatedResult(currentList, hasMore: false));
    }
    _isLoadingMore = false;
  }
}
