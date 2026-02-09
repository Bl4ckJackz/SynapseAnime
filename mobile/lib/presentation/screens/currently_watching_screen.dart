import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../domain/providers/watchlist_provider.dart';
import '../../data/repositories/user_repository.dart';
import '../widgets/app_navigation_drawer.dart';

/// Screen for tracking currently watching anime/manga with episode checkboxes
class CurrentlyWatchingScreen extends ConsumerStatefulWidget {
  const CurrentlyWatchingScreen({super.key});

  @override
  ConsumerState<CurrentlyWatchingScreen> createState() =>
      _CurrentlyWatchingScreenState();
}

class _CurrentlyWatchingScreenState
    extends ConsumerState<CurrentlyWatchingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppNavigationDrawer(),
      appBar: AppBar(
        title: const Text('In Visione'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.play_circle_outline), text: 'Anime'),
            Tab(icon: Icon(Icons.menu_book_outlined), text: 'Manga'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _WatchingListTab(type: 'anime'),
          _WatchingListTab(type: 'manga'),
        ],
      ),
    );
  }
}

class _WatchingListTab extends ConsumerWidget {
  final String type;

  const _WatchingListTab({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlistAsync = ref.watch(watchlistProvider);

    return watchlistAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Errore: $error', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.invalidate(watchlistProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
      data: (watchlist) {
        // Filter by type
        final filteredItems = watchlist.where((item) {
          if (type == 'anime') {
            return item.anime != null;
          } else {
            return item.manga != null;
          }
        }).toList();

        if (filteredItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  type == 'anime' ? Icons.movie_outlined : Icons.book_outlined,
                  size: 64,
                  color: Colors.grey[600],
                ),
                const SizedBox(height: 16),
                Text(
                  type == 'anime'
                      ? 'Nessun anime in visione'
                      : 'Nessun manga in lettura',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aggiungi qualcosa alla tua watchlist!',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            return _WatchingItemCard(item: item, type: type);
          },
        );
      },
    );
  }
}

class _WatchingItemCard extends ConsumerStatefulWidget {
  final WatchlistItem item;
  final String type;

  const _WatchingItemCard({required this.item, required this.type});

  @override
  ConsumerState<_WatchingItemCard> createState() => _WatchingItemCardState();
}

class _WatchingItemCardState extends ConsumerState<_WatchingItemCard> {
  bool _isExpanded = false;
  Set<int> _watchedEpisodes = {};

  String get _id {
    if (widget.type == 'anime') {
      return widget.item.anime?.id ?? '';
    } else {
      return widget.item.manga?.id ?? '';
    }
  }

  String get _title {
    if (widget.type == 'anime') {
      return widget.item.anime?.title ?? 'Unknown';
    } else {
      return widget.item.manga?.title ?? 'Unknown';
    }
  }

  String get _imageUrl {
    if (widget.type == 'anime') {
      return widget.item.anime?.coverUrl ?? '';
    } else {
      return widget.item.manga?.coverUrl ?? '';
    }
  }

  int get _totalEpisodes {
    if (widget.type == 'anime') {
      return widget.item.anime?.totalEpisodes ?? 12;
    } else {
      return widget.item.manga?.chapters ?? 50;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadWatchedEpisodes();
  }

  void _loadWatchedEpisodes() {
    // Initialize with first few episodes for demo (in real app, load from backend)
    _watchedEpisodes = {};
  }

  void _toggleEpisode(int episodeNumber) {
    setState(() {
      if (_watchedEpisodes.contains(episodeNumber)) {
        _watchedEpisodes.remove(episodeNumber);
      } else {
        _watchedEpisodes.add(episodeNumber);
      }
    });
    // TODO: Persist to backend via watchlist update
  }

  void _markAllWatched(int totalEpisodes) {
    setState(() {
      _watchedEpisodes = Set.from(List.generate(totalEpisodes, (i) => i + 1));
    });
  }

  void _clearAll() {
    setState(() {
      _watchedEpisodes = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentEp = _watchedEpisodes.length;
    final totalEpisodes = _totalEpisodes;
    final progress = totalEpisodes > 0 ? currentEp / totalEpisodes : 0.0;

    return Card(
      color: AppTheme.cardColor,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Main row
          InkWell(
            onTap: () {
              if (widget.type == 'anime') {
                context.push('/anime/$_id');
              } else {
                context.push('/manga/$_id');
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Cover image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: _imageUrl,
                      width: 60,
                      height: 85,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 60,
                        height: 85,
                        color: AppTheme.surfaceColor,
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 60,
                        height: 85,
                        color: AppTheme.surfaceColor,
                        child:
                            const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.type == 'anime' ? 'Ep.' : 'Cap.'} $currentEp / $totalEpisodes',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            backgroundColor: AppTheme.surfaceColor,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1
                                  ? AppTheme.successColor
                                  : AppTheme.primaryColor,
                            ),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(progress * 100).toInt()}% completato',
                          style: TextStyle(
                            fontSize: 11,
                            color: progress >= 1
                                ? AppTheme.successColor
                                : AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Expand button
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: AppTheme.primaryColor,
                    ),
                    onPressed: () {
                      setState(() => _isExpanded = !_isExpanded);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Expanded episode checklist
          if (_isExpanded) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Segna ${widget.type == 'anime' ? 'episodi' : 'capitoli'} visti',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _clearAll,
                            child: const Text('Azzera',
                                style: TextStyle(fontSize: 12)),
                          ),
                          TextButton(
                            onPressed: () => _markAllWatched(
                                totalEpisodes > 100 ? 100 : totalEpisodes),
                            child: const Text('Segna tutti',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Episode grid
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List.generate(
                      totalEpisodes > 100
                          ? 100
                          : totalEpisodes, // Limit for performance
                      (index) {
                        final epNum = index + 1;
                        final isWatched = _watchedEpisodes.contains(epNum);
                        return GestureDetector(
                          onTap: () => _toggleEpisode(epNum),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isWatched
                                  ? AppTheme.primaryColor
                                  : AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isWatched
                                    ? AppTheme.primaryColor
                                    : Colors.grey[700]!,
                              ),
                            ),
                            child: Center(
                              child: isWatched
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 18)
                                  : Text(
                                      '$epNum',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (totalEpisodes > 100)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '... e altri ${totalEpisodes - 100} ${widget.type == 'anime' ? 'episodi' : 'capitoli'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
