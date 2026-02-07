import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/providers/watch_history_provider.dart';

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

class WatchHistoryScreen extends ConsumerWidget {
  const WatchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(watchHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storia di Visione'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(watchHistoryProvider.notifier).refresh(),
          ),
        ],
      ),
      body: historyState.when(
        data: (watchHistory) {
          if (watchHistory.isEmpty) {
            return const _EmptyHistoryView();
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
      ),
    );
  }
}

class _EmptyHistoryView extends StatelessWidget {
  const _EmptyHistoryView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.history,
            size: 80,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'La tua storia è vuota',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'I tuoi episodi guardati appariranno qui',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              context.goNamed('home');
            },
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
            // Thumbnail placeholder or image
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
                        print('Image Load Error (Episode): $error');
                        // Fallback to anime cover
                        if (historyItem.anime?.coverUrl?.isNotEmpty ?? false) {
                          return Image.network(
                              _getProxiedUrl(historyItem.anime!.coverUrl!),
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) {
                            print('Image Load Error (Anime Fallback): $err');
                            return const Icon(Icons.broken_image,
                                color: Colors.white24);
                          });
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
                // Navigate to player with animeId and episodeId
                // If anime is missing we can't navigate safely, but item should have anime.
                if (historyItem.anime != null) {
                  context.pushNamed(
                    'player',
                    pathParameters: {
                      'animeId': historyItem.anime!.id,
                      'episodeId': historyItem.episode.id,
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
