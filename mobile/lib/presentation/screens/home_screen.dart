import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../domain/providers/anime_provider.dart';
import '../../domain/providers/active_source_provider.dart';
import '../../domain/providers/watch_history_provider.dart';
import '../../data/repositories/user_repository.dart';
import '../widgets/section_header.dart';
import '../widgets/anime_card.dart';
import '../widgets/featured_slider.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/episode_card.dart';
import '../widgets/glass_container.dart';

String _getProxiedImageUrl(String? url) {
  if (url == null || url.isEmpty) {
    return 'https://upload.wikimedia.org/wikipedia/commons/c/ca/1x1.png';
  }
  if (url.contains('img.animeunity') ||
      url.contains('animeunity.so') ||
      url.contains('cdn.noitatnemucod.net')) {
    return '${AppConstants.apiBaseUrl}/stream/proxy-image?url=${Uri.encodeComponent(url)}';
  }
  return url;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(animeListProvider(
              const AnimeFilter(type: FilterType.newReleases)));
          ref.invalidate(animeListProvider(
              const AnimeFilter(type: FilterType.topRated, page: 1)));
          ref.invalidate(animeListProvider(
              const AnimeFilter(type: FilterType.topRated, page: 2)));
          ref.invalidate(animeListProvider(
              const AnimeFilter(type: FilterType.popular, page: 3)));
          ref.invalidate(
              animeListProvider(const AnimeFilter(type: FilterType.airing)));
          ref.invalidate(
              animeListProvider(const AnimeFilter(type: FilterType.upcoming)));
          ref.invalidate(
              animeListProvider(const AnimeFilter(type: FilterType.classics)));
        },
        child: CustomScrollView(
          slivers: [
            // Glassmorphism AppBar
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              expandedHeight: 60,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    color: AppTheme.backgroundColor.withOpacity(0.7),
                  ),
                ),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SynapseAnime',
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
                  icon: const Icon(Icons.search),
                  tooltip: 'Cerca',
                  onPressed: () => context.pushNamed('search'),
                ),
                IconButton(
                  icon: const Icon(Icons.source),
                  tooltip: 'Cambia Sorgente',
                  onPressed: () => context.pushNamed('sourceSelection'),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_month),
                  tooltip: 'Calendario Uscite',
                  onPressed: () => context.pushNamed('calendar'),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  tooltip: 'Notifiche',
                  onPressed: () {},
                ),
              ],
            ),

            // Featured Slider
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Consumer(
                  builder: (context, ref, child) {
                    final animeAsync = ref.watch(animeListProvider(
                        const AnimeFilter(type: FilterType.topRated)));
                    return animeAsync.when(
                      data: (list) =>
                          FeaturedSlider(animeList: list.take(7).toList()),
                      loading: () => const SizedBox(
                          height: 220,
                          child: Center(child: PulsingDotIndicator())),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // Continue Watching
            SliverToBoxAdapter(
              child: Consumer(
                builder: (context, ref, child) {
                  final historyAsync = ref.watch(watchHistoryProvider);
                  return historyAsync.when(
                    data: (history) {
                      if (history.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'Continua a guardare'),
                          SizedBox(
                            height: 160,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemCount: history.length,
                              itemBuilder: (context, index) {
                                final item = history[index];
                                final anime = item.anime;
                                if (anime == null) return const SizedBox.shrink();
                                return GestureDetector(
                                  onTap: () => context.pushNamed('player',
                                      pathParameters: {
                                        'animeId': anime.id,
                                        'episodeId': item.episode.id,
                                      }),
                                  child: Container(
                                    width: 200,
                                    margin: const EdgeInsets.only(right: 12),
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: CachedNetworkImage(
                                            imageUrl: _getProxiedImageUrl(anime.coverUrl),
                                            width: 200,
                                            height: 120,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 400,
                                            fadeInDuration: const Duration(milliseconds: 200),
                                            placeholder: (context, url) =>
                                                Container(color: AppTheme.surfaceColor),
                                            errorWidget: (context, url, error) => Container(
                                              color: AppTheme.surfaceColor,
                                              child: const Icon(
                                                Icons.broken_image_outlined,
                                                color: AppTheme.textMuted,
                                              ),
                                            ),
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
                                                  Colors.black.withOpacity(0.8),
                                                ],
                                              ),
                                              borderRadius: const BorderRadius.only(
                                                bottomLeft: Radius.circular(12),
                                                bottomRight: Radius.circular(12),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  anime.title,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
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
                                                  backgroundColor: Colors.white24,
                                                  valueColor:
                                                      const AlwaysStoppedAnimation<Color>(
                                                          AppTheme.primaryColor),
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
                          const SizedBox(height: 32),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
            ),

            // Recent Episodes
            SliverToBoxAdapter(
              child: Consumer(
                builder: (context, ref, child) {
                  final recentEpisodesAsync = ref.watch(recentEpisodesProvider);
                  return recentEpisodesAsync.when(
                    data: (episodes) {
                      if (episodes.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            title: 'Episodi Usciti in Settimana',
                            onSeeAll: () => context.pushNamed('recentEpisodes'),
                          ),
                          SizedBox(
                            height: 180,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              scrollDirection: Axis.horizontal,
                              itemCount: episodes.length,
                              itemBuilder: (context, index) =>
                                  EpisodeCard(episode: episodes[index]),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                      );
                    },
                    loading: () => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: ShimmerAnimeCard(width: 200, height: 24),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 180,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: const [
                              ShimmerAnimeCard(width: 200, height: 112),
                              SizedBox(width: 12),
                              ShimmerAnimeCard(width: 200, height: 112),
                              SizedBox(width: 12),
                              ShimmerAnimeCard(width: 200, height: 112),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  );
                },
              ),
            ),

            // Anime sections
            ..._buildAnimeSection(
              context, ref,
              title: 'In Arrivo',
              filter: const AnimeFilter(type: FilterType.upcoming),
              seeAllType: 'upcoming',
              seeAllTitle: 'In Arrivo',
              sectionKey: 'upcoming',
            ),
            ..._buildAnimeSection(
              context, ref,
              title: 'I più votati',
              filter: const AnimeFilter(type: FilterType.topRated, page: 2),
              seeAllType: 'topRated',
              seeAllTitle: 'I più votati',
              sectionKey: 'topRated',
            ),
            ..._buildAnimeSection(
              context, ref,
              title: 'Tendenza ora',
              filter: const AnimeFilter(type: FilterType.popular, page: 3),
              seeAllType: 'popular',
              seeAllTitle: 'Tendenza ora',
              sectionKey: 'popular',
            ),
            ..._buildAnimeSection(
              context, ref,
              title: 'I più attesi (In corso)',
              filter: const AnimeFilter(type: FilterType.airing),
              seeAllType: 'airing',
              seeAllTitle: 'I più attesi (In corso)',
              sectionKey: 'airing',
            ),
            ..._buildAnimeSection(
              context, ref,
              title: 'Grandi Classici',
              filter: const AnimeFilter(type: FilterType.classics),
              seeAllType: 'classics',
              seeAllTitle: 'Grandi Classici',
              sectionKey: 'classics',
            ),

            // Genre Sections
            ..._buildGenreSections(context, ref),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAnimeSection(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required AnimeFilter filter,
    required String seeAllType,
    required String seeAllTitle,
    required String sectionKey,
  }) {
    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: title,
          onSeeAll: () {
            context.pushNamed('animeList',
                queryParameters: {'type': seeAllType, 'title': seeAllTitle});
          },
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 320,
          child: Consumer(
            builder: (context, ref, child) {
              final animeAsync = ref.watch(animeListProvider(filter));
              return animeAsync.when(
                data: (animeList) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: animeList.length,
                    itemBuilder: (context, index) {
                      return AnimeCard(
                        anime: animeList[index],
                        heroTagSuffix: sectionKey,
                      );
                    },
                  );
                },
                loading: () => const ShimmerAnimeList(),
                error: (err, stack) => Center(child: Text('Errore: $err')),
              );
            },
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }

  List<Widget> _buildGenreSections(BuildContext context, WidgetRef ref) {
    final genres = [
      'Azione',
      'Avventura',
      'Commedia',
      'Drama',
      'Fantasy',
      'Horror',
      'Romance',
      'Sci-Fi',
      'Sport',
    ];

    return genres.expand((genre) {
      return [
        SliverToBoxAdapter(
          child: SectionHeader(
            title: genre,
            onSeeAll: () {
              context.pushNamed('genreGrid',
                  pathParameters: {'genreName': genre});
            },
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 320,
            child: Consumer(
              builder: (context, ref, child) {
                final animeAsync = ref.watch(animeListProvider(
                    AnimeFilter(type: FilterType.list, genre: genre)));
                return animeAsync.when(
                  data: (animeList) {
                    if (animeList.isEmpty) return const SizedBox.shrink();
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: animeList.length,
                      itemBuilder: (context, index) {
                        return AnimeCard(
                          anime: animeList[index],
                          heroTagSuffix: genre,
                        );
                      },
                    );
                  },
                  loading: () => const ShimmerAnimeList(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ];
    }).toList();
  }
}
