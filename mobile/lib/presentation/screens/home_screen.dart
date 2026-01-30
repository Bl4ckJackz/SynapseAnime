import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/providers/anime_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/section_header.dart';
import '../widgets/anime_card.dart';
import '../widgets/featured_slider.dart';
import '../../domain/providers/active_source_provider.dart';
import '../../data/repositories/user_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anime AI Player',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Consumer(
              builder: (context, ref, child) {
                final activeSourceId = ref.watch(activeSourceIdProvider);
                return Text(
                  'Sorgente: ${activeSourceId.toUpperCase()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.source),
            tooltip: 'Cambia Sorgente',
            onPressed: () {
              context.pushNamed('sourceSelection');
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              context.pushNamed('search');
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Calendario Uscite',
            onPressed: () {
              context.pushNamed('calendar');
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => context.pushNamed('chat'),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.pushNamed('settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authServiceProvider.notifier).logout();
              if (context.mounted) context.goNamed('login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(animeListProvider(
              const AnimeFilter(type: FilterType.newReleases)));
          ref.invalidate(
              animeListProvider(const AnimeFilter(type: FilterType.topRated)));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Featured Slider
              Consumer(
                builder: (context, ref, child) {
                  final animeAsync = ref.watch(animeListProvider(
                      const AnimeFilter(type: FilterType.topRated)));
                  return animeAsync.when(
                    data: (list) =>
                        FeaturedSlider(animeList: list.take(5).toList()),
                    loading: () => const SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator())),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Continue Watching Section
              Consumer(
                builder: (context, ref, child) {
                  final historyFuture =
                      ref.watch(userRepositoryProvider).getContinueWatching();
                  return FutureBuilder<List<WatchHistoryItem>>(
                    future: historyFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader(title: 'Continua a guardare'),
                            SizedBox(
                              height: 160,
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                scrollDirection: Axis.horizontal,
                                itemCount: snapshot.data!.length,
                                itemBuilder: (context, index) {
                                  final item = snapshot.data![index];
                                  final anime = item.anime;
                                  if (anime == null)
                                    return const SizedBox.shrink();

                                  return GestureDetector(
                                    onTap: () => context.pushNamed('player',
                                        pathParameters: {
                                          'animeId': anime.id,
                                          'episodeId': item.episode.id
                                        }),
                                    child: Container(
                                      width: 200,
                                      margin: const EdgeInsets.only(right: 12),
                                      child: Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: CachedNetworkImage(
                                              imageUrl: anime.coverUrl ?? '',
                                              width: 200,
                                              height: 120,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.transparent,
                                                    Colors.black
                                                        .withOpacity(0.8),
                                                  ],
                                                ),
                                                borderRadius:
                                                    const BorderRadius.only(
                                                  bottomLeft:
                                                      Radius.circular(12),
                                                  bottomRight:
                                                      Radius.circular(12),
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    anime.title,
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    'Episodio ${item.episode.number}',
                                                    style: const TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 10),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  LinearProgressIndicator(
                                                    value: item.progressPercent,
                                                    backgroundColor:
                                                        Colors.white24,
                                                    valueColor:
                                                        const AlwaysStoppedAnimation<
                                                                Color>(
                                                            AppTheme
                                                                .primaryColor),
                                                    minHeight: 2,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  );
                },
              ),

              // In Arrivo Section (Upcoming)
              SectionHeader(
                title: 'In Arrivo',
                onSeeAll: () {
                  // Navigate to search with upcoming filter?
                  // context.pushNamed('search', queryParameters: {'filter': 'upcoming'});
                },
              ),
              SizedBox(
                height: 240,
                child: Consumer(
                  builder: (context, ref, child) {
                    final animeAsync = ref.watch(animeListProvider(
                        const AnimeFilter(type: FilterType.upcoming)));

                    return animeAsync.when(
                      data: (animeList) {
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: animeList.length,
                          itemBuilder: (context, index) {
                            return AnimeCard(anime: animeList[index]);
                          },
                        );
                      },
                      loading: () => _buildLoadingList(),
                      error: (err, stack) =>
                          Center(child: Text('Errore: $err')),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Novità Uscite Section (Recent Releases < 30 days)
              SectionHeader(
                title: 'Novità Uscite',
                onSeeAll: () {
                  context.pushNamed('search');
                },
              ),
              SizedBox(
                height: 240,
                child: Consumer(
                  builder: (context, ref, child) {
                    final animeAsync = ref.watch(animeListProvider(
                        const AnimeFilter(
                            type: FilterType.newReleases))); // maps to 'airing'

                    return animeAsync.when(
                      data: (animeList) {
                        // Filter specifically for items released in last 30 days
                        final recent = animeList.where((a) {
                          if (a.airedFrom == null) return false;
                          final diff =
                              DateTime.now().difference(a.airedFrom!).inDays;
                          return diff >= 0 && diff <= 30;
                        }).toList();

                        if (recent.isEmpty) {
                          // Fallback to first few items if filter is too strict?
                          // Or just show message
                          // return const Center(child: Text('Nessuna uscita recente (<30gg)'));
                          // Actually user requested specific logic. If empty, empty list.
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: recent.length,
                          itemBuilder: (context, index) {
                            return AnimeCard(anime: recent[index]);
                          },
                        );
                      },
                      loading: () => _buildLoadingList(),
                      error: (err, stack) =>
                          Center(child: Text('Errore: $err')),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Top Rated Section
              SectionHeader(
                title: 'I più votati',
                onSeeAll: () {
                  context.pushNamed('search');
                },
              ),
              SizedBox(
                height: 240,
                child: Consumer(
                  builder: (context, ref, child) {
                    final animeAsync = ref.watch(animeListProvider(
                        const AnimeFilter(type: FilterType.topRated)));

                    return animeAsync.when(
                      data: (animeList) {
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: animeList.length,
                          itemBuilder: (context, index) {
                            return AnimeCard(anime: animeList[index]);
                          },
                        );
                      },
                      loading: () => _buildLoadingList(),
                      error: (err, stack) =>
                          Center(child: Text('Errore: $err')),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Trending Section
              SectionHeader(
                title: 'Tendenza ora',
                onSeeAll: () {
                  context.pushNamed('search');
                },
              ),
              SizedBox(
                height: 240,
                child: Consumer(
                  builder: (context, ref, child) {
                    final animeAsync = ref.watch(animeListProvider(
                        const AnimeFilter(type: FilterType.popular)));

                    return animeAsync.when(
                      data: (animeList) {
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: animeList.length,
                          itemBuilder: (context, index) {
                            return AnimeCard(anime: animeList[index]);
                          },
                        );
                      },
                      loading: () => _buildLoadingList(),
                      error: (err, stack) =>
                          Center(child: Text('Errore: $err')),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Top Airing Section
              SectionHeader(
                title: 'I più attesi (In corso)',
                onSeeAll: () {
                  context.pushNamed('search');
                },
              ),
              SizedBox(
                height: 240,
                child: Consumer(
                  builder: (context, ref, child) {
                    final animeAsync = ref.watch(animeListProvider(
                        const AnimeFilter(type: FilterType.airing)));

                    return animeAsync.when(
                      data: (animeList) {
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: animeList.length,
                          itemBuilder: (context, index) {
                            return AnimeCard(anime: animeList[index]);
                          },
                        );
                      },
                      loading: () => _buildLoadingList(),
                      error: (err, stack) =>
                          Center(child: Text('Errore: $err')),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Classics Section
              SectionHeader(
                title: 'Grandi Classici',
                onSeeAll: () {
                  context.pushNamed('search');
                },
              ),
              SizedBox(
                height: 240,
                child: Consumer(
                  builder: (context, ref, child) {
                    final animeAsync = ref.watch(animeListProvider(
                        const AnimeFilter(type: FilterType.classics)));

                    return animeAsync.when(
                      data: (animeList) {
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: animeList.length,
                          itemBuilder: (context, index) {
                            return AnimeCard(anime: animeList[index]);
                          },
                        );
                      },
                      loading: () => _buildLoadingList(),
                      error: (err, stack) =>
                          Center(child: Text('Errore: $err')),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Popular Genres
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Generi Popolari',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildGenreChip(context, 'Azione', Icons.flash_on),
                    _buildGenreChip(context, 'Avventura', Icons.explore),
                    _buildGenreChip(
                        context, 'Commedia', Icons.sentiment_very_satisfied),
                    _buildGenreChip(context, 'Drama', Icons.theater_comedy),
                    _buildGenreChip(context, 'Fantasy', Icons.auto_stories),
                    _buildGenreChip(context, 'Horror', Icons.dangerous),
                    _buildGenreChip(context, 'Romance', Icons.favorite),
                    _buildGenreChip(context, 'Sci-Fi', Icons.science),
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenreChip(BuildContext context, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: AppTheme.primaryColor),
        label: Text(label),
        backgroundColor: AppTheme.surfaceColor,
        onPressed: () {
          // Navigate to search with genre filter
          context.pushNamed('search');
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
          width: 140,
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
