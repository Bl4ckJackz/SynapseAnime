import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../domain/entities/anime.dart';
import '../../domain/entities/episode.dart';

class WatchHistoryScreen extends ConsumerWidget {
  const WatchHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mock data for watch history
    final watchHistory = [
      WatchHistoryItem(
        id: '1',
        anime: const Anime(
          id: 'a1',
          title: 'Attack on Titan',
          description: 'Humanity fights for survival against giant humanoid Titans.',
          coverUrl: '',
          genres: ['Action', 'Drama'],
          status: AnimeStatus.completed,
          releaseYear: 2013,
          rating: 4.8,
          totalEpisodes: 75,
        ),
        episode: const Episode(
          id: 'e1',
          animeId: 'a1',
          number: 1,
          title: 'To You, in 2000 Years - The Fall of Shiganshina, Part 1',
          duration: 1320, // 22 minutes in seconds
          thumbnail: '',
          streamUrl: '',
        ),
        progress: 100, // 100% watched
        lastWatched: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      WatchHistoryItem(
        id: '2',
        anime: const Anime(
          id: 'a2',
          title: 'Demon Slayer',
          description: 'A boy becomes a demon slayer to avenge his family and cure his sister.',
          coverUrl: '',
          genres: ['Action', 'Fantasy'],
          status: AnimeStatus.ongoing,
          releaseYear: 2019,
          rating: 4.9,
          totalEpisodes: 44,
        ),
        episode: const Episode(
          id: 'e2',
          animeId: 'a2',
          number: 1,
          title: 'Meet Tanjiro!',
          duration: 1440, // 24 minutes in seconds
          thumbnail: '',
          streamUrl: '',
        ),
        progress: 75, // 75% watched
        lastWatched: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      WatchHistoryItem(
        id: '3',
        anime: const Anime(
          id: 'a3',
          title: 'One Piece',
          description: 'Follow the adventures of Monkey D. Luffy and his pirate crew.',
          coverUrl: '',
          genres: ['Adventure', 'Comedy'],
          status: AnimeStatus.ongoing,
          releaseYear: 1999,
          rating: 4.7,
          totalEpisodes: 1000, // Many episodes
        ),
        episode: const Episode(
          id: 'e3',
          animeId: 'a3',
          number: 1,
          title: 'Romance Dawn',
          duration: 1500, // 25 minutes in seconds
          thumbnail: '',
          streamUrl: '',
        ),
        progress: 30, // 30% watched
        lastWatched: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Storia di Visione'),
      ),
      body: watchHistory.isEmpty
          ? const _EmptyHistoryView()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: watchHistory.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _WatchHistoryCard(historyItem: watchHistory[index]);
              },
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
          Icon(
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
              // Navigate to continue watching or home
              // context.push('/');
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
    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Thumbnail placeholder
            Container(
              width: 80,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.play_arrow,
                color: AppTheme.primaryColor,
                size: 30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    historyItem.anime.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Ep. ${historyItem.episode.number} - ${historyItem.episode.title}',
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
                        '${historyItem.progress}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.primaryColor,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTimeAgo(historyItem.lastWatched),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: historyItem.progress / 100,
                    backgroundColor: AppTheme.surfaceColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      historyItem.progress > 90
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
                // Resume watching
              },
              icon: const Icon(Icons.play_circle),
              color: AppTheme.primaryColor,
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

class WatchHistoryItem {
  final String id;
  final Anime anime;
  final Episode episode;
  final int progress; // 0-100 percentage
  final DateTime lastWatched;

  WatchHistoryItem({
    required this.id,
    required this.anime,
    required this.episode,
    required this.progress,
    required this.lastWatched,
  });
}