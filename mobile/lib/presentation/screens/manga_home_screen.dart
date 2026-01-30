import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../domain/entities/manga.dart';
import '../../domain/providers/manga_provider.dart';
import '../widgets/section_header.dart';

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
            crossAxisCount: 3,
            childAspectRatio: 0.55,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: mangaList.length,
          itemBuilder: (context, index) => _buildMangaCard(mangaList[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
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
              // TODO: Navigate to full list
            },
          ),
          SizedBox(
            height: 260,
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
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildMangaCard(mangaList[index]),
                    );
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
              // TODO: Navigate to full list
            },
          ),
          SizedBox(
            height: 260,
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
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _buildMangaCard(mangaList[index]),
                        );
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
              // TODO: Navigate to full list
            },
          ),
          SizedBox(
            height: 260,
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
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _buildMangaCard(mangaList[index]),
                        );
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
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMangaCard(Manga manga) {
    return GestureDetector(
      onTap: () {
        context.push('/manga/${manga.id}');
      },
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: manga.coverUrl ?? '',
                height: 170,
                width: 120,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppTheme.surfaceColor,
                  child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppTheme.surfaceColor,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              manga.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (manga.score != null)
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 14),
                  const SizedBox(width: 2),
                  Text(
                    manga.score!.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
          ],
        ),
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
