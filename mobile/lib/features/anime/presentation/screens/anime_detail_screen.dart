import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme.dart';
import '../../../../core/constants.dart';
import '../../../../domain/entities/episode.dart';
import '../../../../domain/providers/anime_provider.dart';

class AnimeDetailScreen extends ConsumerStatefulWidget {
  final String animeId;

  const AnimeDetailScreen({super.key, required this.animeId});

  @override
  ConsumerState<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends ConsumerState<AnimeDetailScreen> {
  int _selectedSeason = 1;
  int _selectedRangeIndex = 0;

  // Group episodes by season ONLY if they have season data from API
  // If no season data, return single group with all episodes
  Map<int, List<Episode>> _groupEpisodesBySeason(List<Episode> episodes) {
    // Check if any episode has actual season data from API
    final hasSeasonData = episodes.any((ep) => ep.season != null);

    if (!hasSeasonData) {
      // No season info from API - return all episodes as single group (season 1)
      return {1: episodes};
    }

    // API provided season data - group by it
    final Map<int, List<Episode>> grouped = {};
    for (final ep in episodes) {
      final season = ep.season ?? 1;
      grouped.putIfAbsent(season, () => []).add(ep);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final animeAsync = ref.watch(animeDetailsProvider(widget.animeId));
    final episodesAsync = ref.watch(animeEpisodesProvider(widget.animeId));

    return Scaffold(
      body: animeAsync.when(
        data: (anime) {
          debugPrint('DEBUG: Selected Anime Titles:');
          debugPrint('Display Title: ${anime.title}');
          debugPrint('English Title: ${anime.titleEnglish}');
          debugPrint('Japanese Title: ${anime.titleJapanese}');

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    anime.title,
                    style: const TextStyle(
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: _getProxiedUrl(anime.coverUrl),
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildInfoItem(Icons.movie, 'Episodi',
                              '${anime.totalEpisodes == 0 ? '?' : anime.totalEpisodes}'),
                          _buildInfoItem(Icons.calendar_today, 'Anno',
                              '${anime.releaseYear == 0 ? '?' : anime.releaseYear}'),
                          _buildInfoItem(Icons.star, 'Rating',
                              '${anime.rating == 0.0 ? '?' : anime.rating}'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: anime.genres
                            .map((g) => Chip(
                                  label: Text(g),
                                  backgroundColor: AppTheme.surfaceColor,
                                  labelStyle: const TextStyle(fontSize: 12),
                                  padding: EdgeInsets.zero,
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Trama',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        anime.description
                            .replaceAll(
                                RegExp(
                                    r'\[EXTERNAL_LINK\].*?\[/EXTERNAL_LINK\]',
                                    multiLine: true,
                                    dotAll: true),
                                '')
                            .trim(),
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Episodi',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          IconButton(
                            icon: const Icon(Icons.bookmark_border),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Season Selector
              episodesAsync.when(
                data: (episodes) {
                  final episodeList = episodes.cast<Episode>();
                  final grouped = _groupEpisodesBySeason(episodeList);
                  final seasons = grouped.keys.toList()..sort();

                  if (seasons.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Center(child: Text('Nessun episodio disponibile')),
                    );
                  }

                  // Ensure selected season is valid
                  if (!seasons.contains(_selectedSeason)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _selectedSeason = seasons.first;
                          _selectedRangeIndex = 0;
                        });
                      }
                    });
                  }

                  var currentEpisodes = grouped[_selectedSeason] ?? [];

                  // Pagination logic
                  const int pageSize = 50;
                  final int totalCount = currentEpisodes.length;
                  final int totalPages = (totalCount / pageSize).ceil();

                  if (_selectedRangeIndex >= totalPages && totalPages > 0) {
                    _selectedRangeIndex = 0;
                  }

                  List<Episode> displayedEpisodes = currentEpisodes;
                  if (totalPages > 1) {
                    final int start = _selectedRangeIndex * pageSize;
                    final int end = (start + pageSize) < totalCount
                        ? (start + pageSize)
                        : totalCount;
                    displayedEpisodes = currentEpisodes.sublist(start, end);
                  }

                  return SliverList(
                    delegate: SliverChildListDelegate([
                      // Season chips
                      if (seasons.length > 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: seasons.map((season) {
                                final isSelected = season == _selectedSeason;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text('Stagione $season'),
                                    selected: isSelected,
                                    onSelected: (_) => setState(() {
                                      _selectedSeason = season;
                                      _selectedRangeIndex = 0;
                                    }),
                                    selectedColor: AppTheme.primaryColor,
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),

                      // Range Selector (Pagination)
                      if (totalPages > 1)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Seleziona Episodi',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: List.generate(totalPages, (index) {
                                    final isSelected =
                                        index == _selectedRangeIndex;
                                    final start = index * pageSize + 1;
                                    final end = (index + 1) * pageSize;
                                    final label =
                                        '$start-${end > totalCount ? totalCount : end}';

                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(label),
                                        selected: isSelected,
                                        onSelected: (_) => setState(() {
                                          _selectedRangeIndex = index;
                                        }),
                                        selectedColor: AppTheme.accentColor,
                                        labelStyle: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 8),
                      // Episode list
                      ...displayedEpisodes.map((episode) => ListTile(
                            leading: Stack(
                              alignment: Alignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: _getProxiedUrl(episode.thumbnail),
                                    width: 100,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const Icon(Icons.play_circle_outline,
                                    color: Colors.white70),
                              ],
                            ),
                            title: Text(
                              'Ep. ${episode.number} - ${episode.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              episode.durationFormatted,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                            onTap: () =>
                                context.pushNamed('player', pathParameters: {
                              'animeId': widget.animeId,
                              'episodeId': episode.id,
                            }),
                          )),
                      const SizedBox(height: 40),
                    ]),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator())),
                error: (err, stack) => SliverToBoxAdapter(
                    child: Center(
                        child: Text('Errore caricamento episodi: $err'))),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Errore: $err')),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _getProxiedUrl(String? url) {
    if (url == null || url.isEmpty)
      return 'https://upload.wikimedia.org/wikipedia/commons/c/ca/1x1.png';
    if (url.contains('animeunity.so') ||
        url.contains('img.animeunity') ||
        url.contains('cdn.noitatnemucod.net')) {
      return '${AppConstants.apiBaseUrl}/stream/proxy-image?url=${Uri.encodeComponent(url)}';
    }
    return url;
  }
}
