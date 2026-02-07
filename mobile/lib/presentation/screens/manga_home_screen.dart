import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../domain/entities/manga.dart';
import '../../domain/providers/manga_provider.dart';
import '../widgets/section_header.dart';
import '../widgets/app_loader.dart';
import '../widgets/manga_card.dart';

class MangaHomeScreen extends ConsumerStatefulWidget {
  const MangaHomeScreen({super.key});

  @override
  ConsumerState<MangaHomeScreen> createState() => _MangaHomeScreenState();
}

class _MangaHomeScreenState extends ConsumerState<MangaHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(mangaSearchQueryProvider);
    final topMangaAsync = ref.watch(topMangaProvider);
    final searchResultsAsync = searchQuery.isNotEmpty
        ? ref.watch(mangaSearchProvider(searchQuery))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Cerca manga...',
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.white),
                onSubmitted: (value) {
                  ref.read(mangaSearchQueryProvider.notifier).state = value;
                },
              )
            : Row(
                children: [
                  const Icon(Icons.menu_book, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Manga',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(mangaSearchQueryProvider.notifier).state = '';
                }
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(topMangaProvider);
        },
        child: searchResultsAsync != null
            ? _buildSearchResults(searchResultsAsync)
            : _buildMainContent(topMangaAsync),
      ),
    );
  }

  Widget _buildSearchResults(AsyncValue<List<Manga>> searchAsync) {
    return searchAsync.when(
      data: (mangaList) {
        if (mangaList.isEmpty) {
          return const Center(child: Text('Nessun risultato trovato'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.55,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: mangaList.length,
          itemBuilder: (context, index) => MangaCard(
            manga: mangaList[index],
            width: double.infinity,
            height: double.infinity,
            showTitle: true,
            margin: EdgeInsets.zero,
          ),
        );
      },
      loading: () => Center(child: AppLoader(width: 80, height: 80)),
      error: (err, _) => Center(child: Text('Errore: $err')),
    );
  }

  Widget _buildMainContent(AsyncValue<List<Manga>> topMangaAsync) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Top Manga Section
          SectionHeader(
            title: 'Top Manga',
            onSeeAll: () {
              context.pushNamed('mangaList', queryParameters: {
                'title': 'Top Manga',
                'type': 'top',
              });
            },
          ),
          SizedBox(
            height: 400,
            child: topMangaAsync.when(
              data: (mangaList) {
                if (mangaList.isEmpty) {
                  return const Center(child: Text('Nessun manga disponibile'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: mangaList.length,
                  itemBuilder: (context, index) {
                    return MangaCard(manga: mangaList[index]);
                  },
                );
              },
              loading: () => _buildLoadingList(),
              error: (err, _) => Center(child: Text('Errore: $err')),
            ),
          ),

          const SizedBox(height: 24),

          // Trending Manga Section
          SectionHeader(
            title: 'Manga di Tendenza',
            onSeeAll: () {
              context.pushNamed('mangaList', queryParameters: {
                'title': 'Manga di Tendenza',
                'type': 'trending',
              });
            },
          ),
          SizedBox(
            height: 400,
            child: Consumer(
              builder: (context, ref, child) {
                final trendingAsync = ref.watch(trendingMangaProvider);
                return trendingAsync.when(
                  data: (mangaList) {
                    if (mangaList.isEmpty) {
                      return const Center(
                          child: Text('Nessun trending disponibile'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: mangaList.length,
                      itemBuilder: (context, index) {
                        return MangaCard(manga: mangaList[index]);
                      },
                    );
                  },
                  loading: () => _buildLoadingList(),
                  error: (err, _) => Center(child: Text('Errore: $err')),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Recently Updated Section
          SectionHeader(
            title: 'Ultimi Aggiornamenti',
            onSeeAll: () {
              context.pushNamed('mangaList', queryParameters: {
                'title': 'Ultimi Aggiornamenti',
                'type': 'updated',
              });
            },
          ),
          SizedBox(
            height: 400,
            child: Consumer(
              builder: (context, ref, child) {
                final updatedAsync = ref.watch(recentlyUpdatedMangaProvider);
                return updatedAsync.when(
                  data: (mangaList) {
                    if (mangaList.isEmpty) {
                      return const Center(
                          child: Text('Nessun aggiornamento disponibile'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: mangaList.length,
                      itemBuilder: (context, index) {
                        return MangaCard(manga: mangaList[index]);
                      },
                    );
                  },
                  loading: () => _buildLoadingList(),
                  error: (err, _) => Center(child: Text('Errore: $err')),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Top Manhwa Section
          SectionHeader(
            title: 'Top Manhwa (Coreani)',
            onSeeAll: () {
              context.pushNamed('mangaList', queryParameters: {
                'title': 'Top Manhwa (Coreani)',
                'type': 'manhwa',
              });
            },
          ),
          SizedBox(
            height: 400,
            child: Consumer(
              builder: (context, ref, child) {
                final manhwaAsync = ref.watch(manhwaMangaProvider);
                return manhwaAsync.when(
                  data: (mangaList) {
                    if (mangaList.isEmpty) {
                      return const Center(
                          child: Text('Nessun Manhwa disponibile'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: mangaList.length,
                      itemBuilder: (context, index) {
                        return MangaCard(manga: mangaList[index]);
                      },
                    );
                  },
                  loading: () => _buildLoadingList(),
                  error: (err, _) => Center(child: Text('Errore: $err')),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Top Manhua Section
          SectionHeader(
            title: 'Top Manhua (Cinesi)',
            onSeeAll: () {
              context.pushNamed('mangaList', queryParameters: {
                'title': 'Top Manhua (Cinesi)',
                'type': 'manhua',
              });
            },
          ),
          SizedBox(
            height: 400,
            child: Consumer(
              builder: (context, ref, child) {
                final manhuaAsync = ref.watch(manhuaMangaProvider);
                return manhuaAsync.when(
                  data: (mangaList) {
                    if (mangaList.isEmpty) {
                      return const Center(
                          child: Text('Nessun Manhua disponibile'));
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: mangaList.length,
                      itemBuilder: (context, index) {
                        return MangaCard(manga: mangaList[index]);
                      },
                    );
                  },
                  loading: () => _buildLoadingList(),
                  error: (err, _) => Center(child: Text('Errore: $err')),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Genres Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Generi',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                _buildGenreChip('Azione'),
                _buildGenreChip('Avventura'),
                _buildGenreChip('Commedia'),
                _buildGenreChip('Drama'),
                _buildGenreChip('Fantasy'),
                _buildGenreChip('Horror'),
                _buildGenreChip('Romance'),
                _buildGenreChip('Sci-Fi'),
                _buildGenreChip('Slice of Life'),
                _buildGenreChip('Isekai'),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGenreChip(String genre) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(genre),
        backgroundColor: AppTheme.surfaceColor,
        onPressed: () {
          // TODO: Filter by genre
        },
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          width: 120,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }
}
