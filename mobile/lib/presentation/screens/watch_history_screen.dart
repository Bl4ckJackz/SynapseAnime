import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/providers/watch_history_provider.dart';
import '../../domain/providers/download_provider.dart';

// Helper function to proxy animeunity URLs
String _getProxiedUrl(String? url) {
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

class WatchHistoryScreen extends ConsumerStatefulWidget {
  const WatchHistoryScreen({super.key});

  @override
  ConsumerState<WatchHistoryScreen> createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends ConsumerState<WatchHistoryScreen>
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
      appBar: AppBar(
        title: const Text('Cronologia'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(icon: Icon(Icons.history), text: 'Visione'),
            Tab(icon: Icon(Icons.download_done), text: 'Download'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(watchHistoryProvider.notifier).refresh();
              ref.read(downloadProvider.notifier).loadHistory();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _WatchHistoryTab(),
          _DownloadHistoryTab(),
        ],
      ),
    );
  }
}

// ========== WATCH HISTORY TAB ==========
class _WatchHistoryTab extends ConsumerWidget {
  const _WatchHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(watchHistoryProvider);

    return historyState.when(
      data: (watchHistory) {
        if (watchHistory.isEmpty) {
          return const _EmptyHistoryView(
            icon: Icons.history,
            title: 'La tua storia è vuota',
            subtitle: 'I tuoi episodi guardati appariranno qui',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: watchHistory.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _WatchHistoryCard(historyItem: watchHistory[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text('Errore: ${error.toString()}'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  ref.read(watchHistoryProvider.notifier).refresh(),
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}

// ========== DOWNLOAD HISTORY TAB ==========
class _DownloadHistoryTab extends ConsumerStatefulWidget {
  const _DownloadHistoryTab();

  @override
  ConsumerState<_DownloadHistoryTab> createState() =>
      _DownloadHistoryTabState();
}

class _DownloadHistoryTabState extends ConsumerState<_DownloadHistoryTab> {
  @override
  void initState() {
    super.initState();
    // Load download history when tab is first shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(downloadProvider.notifier).loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadProvider);
    final history = downloadState.history;

    if (downloadState.isLoading && history.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (history.isEmpty) {
      return const _EmptyHistoryView(
        icon: Icons.download_done,
        title: 'Nessun download',
        subtitle: 'I tuoi download completati appariranno qui',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _DownloadHistoryCard(download: history[index]);
      },
    );
  }
}

// ========== EMPTY VIEW ==========
class _EmptyHistoryView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyHistoryView({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.goNamed('home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Inizia a Guardare'),
          ),
        ],
      ),
    );
  }
}

// ========== WATCH HISTORY CARD ==========
class _WatchHistoryCard extends StatelessWidget {
  final WatchHistoryItem historyItem;

  const _WatchHistoryCard({required this.historyItem});

  @override
  Widget build(BuildContext context) {
    final animeTitle = historyItem.anime?.title ?? 'Anime Sconosciuto';
    final episodeNumber = historyItem.episode.number;
    final episodeTitle = historyItem.episode.title;
    final progressPercent = historyItem.progressPercent * 100;

    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 80,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (historyItem.episode.thumbnail?.isNotEmpty ?? false)
                    Image.network(
                      _getProxiedUrl(historyItem.episode.thumbnail!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        if (historyItem.anime?.coverUrl?.isNotEmpty ?? false) {
                          return Image.network(
                            _getProxiedUrl(historyItem.anime!.coverUrl!),
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => const Icon(
                                Icons.broken_image,
                                color: Colors.white24),
                          );
                        }
                        return const Center(
                            child: Icon(Icons.error, color: Colors.white24));
                      },
                    )
                  else if (historyItem.anime?.coverUrl?.isNotEmpty ?? false)
                    Image.network(
                      _getProxiedUrl(historyItem.anime!.coverUrl!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.broken_image, color: Colors.white24),
                    )
                  else
                    const Center(
                      child: Icon(Icons.play_arrow,
                          color: AppTheme.primaryColor, size: 30),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    animeTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Ep. $episodeNumber - $episodeTitle',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${progressPercent.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.primaryColor,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTimeAgo(historyItem.updatedAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: historyItem.progressPercent,
                    backgroundColor: AppTheme.surfaceColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressPercent > 90
                          ? AppTheme.successColor
                          : AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () {
                if (historyItem.anime != null) {
                  context.pushNamed(
                    'player',
                    pathParameters: {
                      'animeId': historyItem.anime!.id,
                      'episodeId': historyItem.episode.id,
                    },
                    queryParameters: {
                      if (historyItem.episode.source != null)
                        'source': historyItem.episode.source!,
                    },
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dati anime mancanti')),
                  );
                }
              },
              icon: const Icon(Icons.play_circle),
              color: AppTheme.primaryColor,
              iconSize: 40,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}g fa';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h fa';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m fa';
    } else {
      return 'ora';
    }
  }
}

// ========== DOWNLOAD HISTORY CARD ==========
class _DownloadHistoryCard extends ConsumerWidget {
  final Download download;

  const _DownloadHistoryCard({required this.download});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _getStatusColor(download.status);
    final statusIcon = _getStatusIcon(download.status);

    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(statusIcon, color: statusColor, size: 30),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    download.animeName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Ep. ${download.episodeNumber}${download.episodeTitle != null ? ' - ${download.episodeTitle}' : ''}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getStatusText(download.status),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                      const Spacer(),
                      if (download.completedAt != null)
                        Text(
                          _formatTimeAgo(download.completedAt!),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textMuted,
                                  ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            // Actions
            Column(
              children: [
                if (download.status == DownloadStatus.pending ||
                    download.status == DownloadStatus.downloading)
                  IconButton(
                    icon: const Icon(Icons.stop_circle_outlined,
                        color: Colors.orange),
                    onPressed: () {
                      _showCancelDialog(context, ref, download);
                    },
                    tooltip: 'Ferma',
                  ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    _showDeleteDialog(context, ref, download);
                  },
                  tooltip: 'Elimina',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(
      BuildContext context, WidgetRef ref, Download download) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ferma Download'),
        content: Text(
            'Vuoi davvero fermare il download di "${download.animeName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              ref.read(downloadProvider.notifier).cancelDownload(download.id);
              Navigator.pop(context);
            },
            child: const Text('Ferma', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, WidgetRef ref, Download download) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Download'),
        content: Text(
            'Vuoi eliminare definitivamente "${download.animeName}"? Il file verrà rimosso.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              ref.read(downloadProvider.notifier).deleteDownload(download.id);
              Navigator.pop(context);
            },
            child: const Text('Elimina', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.completed:
        return AppTheme.successColor;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.cancelled:
        return Colors.orange;
      case DownloadStatus.downloading:
        return AppTheme.primaryColor;
      case DownloadStatus.pending:
        return AppTheme.textMuted;
    }
  }

  IconData _getStatusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.completed:
        return Icons.check_circle;
      case DownloadStatus.failed:
        return Icons.error;
      case DownloadStatus.cancelled:
        return Icons.cancel;
      case DownloadStatus.downloading:
        return Icons.downloading;
      case DownloadStatus.pending:
        return Icons.schedule;
    }
  }

  String _getStatusText(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.completed:
        return 'Completato';
      case DownloadStatus.failed:
        return 'Fallito';
      case DownloadStatus.cancelled:
        return 'Annullato';
      case DownloadStatus.downloading:
        return 'In corso';
      case DownloadStatus.pending:
        return 'In attesa';
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}g fa';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h fa';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m fa';
    } else {
      return 'ora';
    }
  }
}
