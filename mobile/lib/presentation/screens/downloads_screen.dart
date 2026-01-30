import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mock data for downloaded episodes
    final downloadedEpisodes = [
      DownloadedEpisode(
        id: '1',
        title: 'Attack on Titan - Ep. 1',
        animeTitle: 'Attack on Titan',
        progress: 100, // 100% means completed
        fileSize: '245 MB',
        dateAdded: DateTime.now().subtract(const Duration(days: 2)),
      ),
      DownloadedEpisode(
        id: '2',
        title: 'Demon Slayer - Ep. 3',
        animeTitle: 'Demon Slayer',
        progress: 100,
        fileSize: '312 MB',
        dateAdded: DateTime.now().subtract(const Duration(days: 5)),
      ),
      DownloadedEpisode(
        id: '3',
        title: 'Jujutsu Kaisen - Ep. 7',
        animeTitle: 'Jujutsu Kaisen',
        progress: 65,
        fileSize: '187 MB',
        dateAdded: DateTime.now().subtract(const Duration(hours: 12)),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download'),
      ),
      body: downloadedEpisodes.isEmpty
          ? const _EmptyDownloadsView()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: downloadedEpisodes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _DownloadedEpisodeCard(
                  episode: downloadedEpisodes[index],
                );
              },
            ),
    );
  }
}

class _EmptyDownloadsView extends StatelessWidget {
  const _EmptyDownloadsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_outlined,
            size: 80,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'Nessun episodio scaricato',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Gli episodi scaricati appariranno qui',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              // Navigate to anime discovery
              // context.push('/discover');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Sfoglia Anime'),
          ),
        ],
      ),
    );
  }
}

class _DownloadedEpisodeCard extends StatelessWidget {
  final DownloadedEpisode episode;

  const _DownloadedEpisodeCard({required this.episode});

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
                    episode.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    episode.animeTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        episode.fileSize,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                      ),
                      const Spacer(),
                      if (episode.progress < 100)
                        Text(
                          '${episode.progress}%',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.warningColor,
                              ),
                        ),
                    ],
                  ),
                  if (episode.progress < 100) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: episode.progress / 100,
                      backgroundColor: AppTheme.surfaceColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        episode.progress > 70
                            ? AppTheme.successColor
                            : AppTheme.warningColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            PopupMenuButton<String>(
              onSelected: (String result) {
                // Handle menu selection
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'play',
                  child: Text('Riproduci'),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Elimina'),
                ),
                const PopupMenuItem<String>(
                  value: 'info',
                  child: Text('Informazioni'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DownloadedEpisode {
  final String id;
  final String title;
  final String animeTitle;
  final int progress; // 0-100
  final String fileSize;
  final DateTime dateAdded;

  DownloadedEpisode({
    required this.id,
    required this.title,
    required this.animeTitle,
    required this.progress,
    required this.fileSize,
    required this.dateAdded,
  });
}