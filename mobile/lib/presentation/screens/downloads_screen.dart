import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../domain/providers/download_provider.dart';
import 'player_screen.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(downloadProvider.notifier).loadQueue();
      ref.read(downloadProvider.notifier).loadHistory();
    });

    // Start polling for progress updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        ref.read(downloadProvider.notifier).loadQueue(silent: true);
        // History doesn't change often, no need to poll as frequently
        if (timer.tick % 5 == 0) {
          ref.read(downloadProvider.notifier).loadHistory();
        }
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadProvider);
    final activeDownloads = downloadState.queue;
    final historyDownloads = downloadState.history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download'),
        actions: [
          if (downloadState.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: activeDownloads.isEmpty && historyDownloads.isEmpty
          ? const _EmptyDownloadsView()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (activeDownloads.isNotEmpty) ...[
                  Text(
                    'In Corso (${activeDownloads.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...activeDownloads.map((download) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DownloadItemCard(
                          download: download,
                          isActive: true,
                        ),
                      )),
                  const SizedBox(height: 24),
                ],
                if (historyDownloads.isNotEmpty) ...[
                  Text(
                    'Completati',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  ...historyDownloads.map((download) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _DownloadItemCard(
                          download: download,
                          isActive: false,
                        ),
                      )),
                ],
              ],
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
          const Icon(
            Icons.download_outlined,
            size: 80,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'Nessun download',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'I tuoi download appariranno qui',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
        ],
      ),
    );
  }
}

class _DownloadItemCard extends ConsumerWidget {
  final Download download;
  final bool isActive;

  const _DownloadItemCard({
    required this.download,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: AppTheme.cardColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          if (download.status == DownloadStatus.completed) {
            // Construct video URL from animeName and fileName
            // Sanitize animeName to match backend folder naming (same as download.service.ts)
            String sanitizedAnimeName = download.animeName
                .replaceAll(RegExp(r'[<>:"/\\|?*]'), '')
                .replaceAll(RegExp(r'\s+'), '_');
            if (sanitizedAnimeName.length > 100) {
              sanitizedAnimeName = sanitizedAnimeName.substring(0, 100);
            }

            // Use fileName if available, otherwise construct from sanitized name + episode number
            final fileName = download.fileName ??
                '$sanitizedAnimeName-${download.episodeNumber}.mp4';
            final relativePath = '$sanitizedAnimeName/$fileName';

            // Construct full URL
            final rawUrl =
                '${AppConstants.apiBaseUrl.replaceAll('/api', '')}/downloads/$relativePath';
            final videoUrl = Uri.encodeFull(rawUrl);
            debugPrint('Playing download URL: $videoUrl');

            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PlayerScreen(
                  animeId: download.animeId,
                  episodeId: download.episodeId,
                  startUrl: videoUrl,
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Thumbnail placeholder
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: download.thumbnailPath != null
                    ? Image.network(
                        '${AppConstants.apiBaseUrl.replaceAll('/api', '')}/downloads/${download.thumbnailPath}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          isActive ? Icons.downloading : Icons.play_arrow,
                          color: AppTheme.primaryColor,
                          size: 30,
                        ),
                      )
                    : Icon(
                        isActive ? Icons.downloading : Icons.play_arrow,
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
                      download.episodeTitle ??
                          'Episodio ${download.episodeNumber}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      download.animeName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textMuted,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    if (isActive)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _getStatusText(download.status),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: _getStatusColor(download.status),
                                    ),
                              ),
                              Text(
                                '${download.progress}%',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textMuted,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: download.progress / 100,
                            backgroundColor: AppTheme.surfaceColor,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _getStatusColor(download.status),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Completato',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.successColor,
                            ),
                      ),
                  ],
                ),
              ),
              if (isActive)
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  onPressed: () {
                    ref
                        .read(downloadProvider.notifier)
                        .cancelDownload(download.id);
                  },
                )
              else
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.textMuted),
                  onPressed: () {
                    // Implement delete
                    ref.read(downloadProvider.notifier).cancelDownload(download
                        .id); // Cancel serves as delete in current implementation
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.pending:
        return 'In attesa...';
      case DownloadStatus.downloading:
        return 'Download in corso';
      case DownloadStatus.completed:
        return 'Completato';
      case DownloadStatus.failed:
        return 'Fallito';
      case DownloadStatus.cancelled:
        return 'Cancellato';
    }
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.pending:
        return Colors.orange;
      case DownloadStatus.downloading:
        return AppTheme.primaryColor;
      case DownloadStatus.completed:
        return AppTheme.successColor;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.cancelled:
        return Colors.grey;
    }
  }
}
