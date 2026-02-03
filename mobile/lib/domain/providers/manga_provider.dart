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
