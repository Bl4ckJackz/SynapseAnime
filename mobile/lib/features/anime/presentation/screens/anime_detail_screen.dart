import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme.dart';
import '../../../../core/constants.dart';
import '../../../../domain/entities/episode.dart';
import '../../../../domain/entities/media_relation.dart';
import '../../../../domain/providers/anime_provider.dart';
import '../../../../domain/providers/download_provider.dart';
import '../../../../domain/providers/anime_progress_provider.dart';
import '../../../../presentation/widgets/related_media_card.dart';
import '../../../../presentation/widgets/app_navigation_drawer.dart';
import '../../../../presentation/widgets/comment_section.dart';
import '../../../../data/repositories/user_repository.dart';
import '../../../../domain/providers/watchlist_provider.dart';
import '../../../../presentation/widgets/detail_bottom_nav_bar.dart';
import '../../data/repositories/anime_repository.dart';

final isInWatchlistProvider =
    FutureProvider.family<bool, String>((ref, animeId) {
  return ref.watch(userRepositoryProvider).isInWatchlist(animeId);
});

class AnimeDetailScreen extends ConsumerStatefulWidget {
  final String animeId;

  const AnimeDetailScreen({super.key, required this.animeId});

  @override
  ConsumerState<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends ConsumerState<AnimeDetailScreen> {
  int _selectedSeason = 1;
  int _selectedRangeIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
    final isInWatchlistAsync = ref.watch(isInWatchlistProvider(widget.animeId));
    final progressAsync = ref.watch(animeProgressProvider(widget.animeId));

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: const AppNavigationDrawer(),
      bottomNavigationBar: const DetailBottomNavBar(),
      floatingActionButton: animeAsync.asData?.value != null
          ? FloatingActionButton(
              onPressed: () {
                final isInWatchlist = isInWatchlistAsync.value ?? false;
                if (isInWatchlist) {
                  ref
                      .read(userRepositoryProvider)
                      .removeFromWatchlist(widget.animeId)
                      .then((_) {
                    ref.refresh(isInWatchlistProvider(widget.animeId));
                    ref.invalidate(watchlistProvider);
                  });
                } else {
                  ref
                      .read(userRepositoryProvider)
                      .addToWatchlist(widget.animeId)
                      .then((_) {
                    ref.refresh(isInWatchlistProvider(widget.animeId));
                    ref.invalidate(watchlistProvider);
                  });
                }
              },
              child: isInWatchlistAsync.isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Icon(
                      isInWatchlistAsync.value == true
                          ? Icons.favorite
                          : Icons.favorite_border,
                    ),
            )
          : null,
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
                actions: [
                  IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                    },
                  ),
                ],
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
                      ClipRect(
                        child: CachedNetworkImage(
                          imageUrl: _getProxiedUrl(anime.coverUrl),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
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
                      if (anime.relations.isNotEmpty) ...[
                        Text(
                          'Correlati',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: anime.relations.length,
                            itemBuilder: (context, index) {
                              final relation = anime.relations[index];
                              // Check if we have valid entries
                              if (relation.entries.isEmpty)
                                return const SizedBox.shrink();

                              // Use the first entry to display
                              final entry = relation.entries.first;

                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: RelatedMediaCard(
                                  malId: entry.malId,
                                  type: entry.type,
                                  title: entry.title,
                                  relationType: relation.relationType,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      // Completion percentage section
                      progressAsync.when(
                        data: (progress) {
                          if (progress == null ||
                              progress.episodeProgress.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Progresso',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      '${progress.completionPercentage}%',
                                      style: TextStyle(
                                        color:
                                            progress.completionPercentage == 100
                                                ? AppTheme.successColor
                                                : AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value:
                                        progress.completionPercentage / 100.0,
                                    backgroundColor: AppTheme.cardColor,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      progress.completionPercentage == 100
                                          ? AppTheme.successColor
                                          : AppTheme.primaryColor,
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${progress.watchedEpisodes} completati',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '${progress.inProgressEpisodes} in corso',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      '${progress.totalEpisodes} totali',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Episodi',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          IconButton(
                            icon: const Icon(Icons.download,
                                color: AppTheme.primaryColor),
                            tooltip: 'Scarica tutti gli episodi',
                            onPressed: () {
                              // Get source and animeId from the first episode
                              // Episode has the source-specific animeId (e.g., AnimeUnity ID)
                              final episodes =
                                  episodesAsync.asData?.value ?? [];
                              if (episodes.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Nessun episodio disponibile'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                              final source = episodes.first.source;
                              // Use episode's animeId (source-specific) instead of widget.animeId (MAL ID)
                              final sourceAnimeId = episodes.first.animeId;
                              print(
                                  '[Download] Using source: $source, animeId: $sourceAnimeId (original: ${widget.animeId})');
                              _showDownloadConfirmDialog(
                                  context, anime.title, sourceAnimeId,
                                  source: source, allEpisodes: episodes);
                            },
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
                  print(
                      'DEBUG: AnimeDetailScreen received ${episodes.length} episodes');
                  if (episodes.isNotEmpty) {
                    print(
                        'DEBUG: First episode source: ${episodes.first.source}');
                    print('DEBUG: First episode ID: ${episodes.first.id}');
                  }
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
                      ...displayedEpisodes.map((episode) {
                        // Get progress for this episode
                        final episodeProgress = progressAsync.valueOrNull
                            ?.getProgressForEpisode(episode.id);
                        final hasProgress = episodeProgress != null &&
                            episodeProgress.progressPercent > 0;

                        return ListTile(
                          leading: SizedBox(
                            width: 100,
                            height: 56,
                            child: Stack(
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
                                // Play icon or check icon if completed
                                if (episodeProgress?.completed == true)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.check_circle,
                                        color: Colors.green, size: 30),
                                  )
                                else
                                  const Icon(Icons.play_circle_outline,
                                      color: Colors.white70),
                                // Progress bar overlay at bottom
                                if (hasProgress)
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(8),
                                        bottomRight: Radius.circular(8),
                                      ),
                                      child: LinearProgressIndicator(
                                        value: episodeProgress.progressFraction,
                                        backgroundColor: Colors.black54,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          episodeProgress.completed
                                              ? AppTheme.successColor
                                              : AppTheme.primaryColor,
                                        ),
                                        minHeight: 4,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          title: Text(
                            'Ep. ${episode.number} - ${episode.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: episodeProgress?.completed == true
                                    ? Colors.grey
                                    : null),
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                episode.durationFormatted,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                              if (hasProgress) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '${episodeProgress.progressPercent}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: episodeProgress.completed
                                        ? AppTheme.successColor
                                        : AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          onTap: () =>
                              context.pushNamed('player', pathParameters: {
                            'animeId': widget.animeId,
                            'episodeId': episode.id,
                          }, queryParameters: {
                            if (episode.source != null)
                              'source': episode.source!,
                          }),
                          trailing: IconButton(
                            icon: const Icon(Icons.cloud_download_rounded),
                            onPressed: () => _downloadEpisode(episode),
                            tooltip: 'Scarica episodio',
                          ),
                        );
                      }),
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
              // Comment section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: CommentSection(animeId: widget.animeId),
                ),
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

  Future<void> _downloadEpisode(Episode episode) async {
    if (episode.id.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Operazione in corso...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final repo = ref.read(animeRepositoryProvider);
      // Resolve stream URL for this single episode
      final streamData =
          await repo.resolveStreamUrl(episode.id, source: episode.source);

      if (streamData['url'] != null &&
          streamData['url'].toString().isNotEmpty) {
        final url = streamData['url'].toString();

        // Get anime title from widget or state if possible.
        // We can access widget.animeId but getting full title is harder here without passing it.
        // But we are in State class, we can try to find it.
        // Actually, for individual download, just use generic name if needed or formatted.
        // But we want it to look good in downloads.
        // Let's iterate providers? No.
        // We will assume the parent list has the title or we pass it?
        // Episode object doesn't have anime title usually.
        // But we have access to 'episodesAsync' value in the build method.
        // We can store animeTitle in state? Or just read it.
        final animeTitle =
            ref.read(animeDetailsProvider(widget.animeId)).value?.title ??
                "Anime";

        final success =
            await ref.read(downloadProvider.notifier).downloadFromUrl(
                  url: url,
                  animeName: animeTitle,
                  episodeNumber: episode.number,
                  episodeTitle: episode.title,
                );

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Download avviato: Ep. ${episode.number}'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Errore nell\'avvio del download'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Nessuno stream trovato per il download')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')),
        );
      }
    }
  }

  Future<void> _downloadSeasonDirectly(
      String animeName, int season, List<Episode> allEpisodes) async {
    final grouped = _groupEpisodesBySeason(allEpisodes);
    final seasonEpisodes = grouped[season] ?? [];

    if (seasonEpisodes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Nessun episodio trovato per la stagione $season')),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Preparazione download di ${seasonEpisodes.length} episodi...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    int queuedCount = 0;
    final repo = ref.read(animeRepositoryProvider);
    final downloadNotifier = ref.read(downloadProvider.notifier);

    // Process sequentially to be safe
    for (final episode in seasonEpisodes) {
      if (!mounted) break;

      try {
        final streamData =
            await repo.resolveStreamUrl(episode.id, source: episode.source);

        if (streamData['url'] != null &&
            streamData['url'].toString().isNotEmpty) {
          await downloadNotifier.downloadFromUrl(
            url: streamData['url'].toString(),
            animeName: animeName,
            episodeNumber: episode.number,
            episodeTitle: episode.title,
          );
          queuedCount++;
        }
      } catch (e) {
        print('Error handling episode ${episode.number}: $e');
      }

      // Small delay
      await Future.delayed(const Duration(milliseconds: 200));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Accodati $queuedCount/${seasonEpisodes.length} episodi'),
          backgroundColor: queuedCount > 0 ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  void _showDownloadConfirmDialog(
      BuildContext context, String animeName, String animeId,
      {String? source, required List<Episode> allEpisodes}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Scarica Episodi'),
        backgroundColor: AppTheme.surfaceColor,
        content: Text(
          'Vuoi scaricare tutti gli episodi di "$animeName"?\n\n'
          'Puoi anche scaricare singole stagioni selezionando il pulsante download accanto alla stagione.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            onPressed: () {
              Navigator.pop(context);
              // Download all seasons (season 1 for anime without season info)
              _downloadSeasonDirectly(animeName, _selectedSeason, allEpisodes);
            },
            child: Text('Scarica Stagione $_selectedSeason'),
          ),
        ],
      ),
    );
  }

  void _downloadSeasonWithFeedback(
      BuildContext context, String animeId, int season) async {
    final success = await ref
        .read(downloadProvider.notifier)
        .downloadSeason(animeId, season);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Download avviato per la stagione $season'
                : 'Errore nell\'avvio del download',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
