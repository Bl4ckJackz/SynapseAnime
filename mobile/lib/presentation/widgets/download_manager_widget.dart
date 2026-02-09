import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../domain/providers/download_provider.dart';

class DownloadManagerWidget extends ConsumerStatefulWidget {
  const DownloadManagerWidget({super.key});

  @override
  ConsumerState<DownloadManagerWidget> createState() =>
      _DownloadManagerWidgetState();
}

class _DownloadManagerWidgetState extends ConsumerState<DownloadManagerWidget> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    // Load queue on init
    Future.microtask(() => ref.read(downloadProvider.notifier).loadQueue());
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadProvider);
    final hasDownloads = downloadState.queue.isNotEmpty;

    return Positioned(
      bottom: 80,
      left: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Expanded panel
          if (_isExpanded)
            Container(
              width: 320,
              constraints: const BoxConstraints(maxHeight: 400),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.download,
                            color: AppTheme.primaryColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Download (${downloadState.queue.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: () {
                            ref.read(downloadProvider.notifier).loadQueue();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => setState(() => _isExpanded = false),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // Download list
                  if (downloadState.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    )
                  else if (downloadState.queue.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.download_done,
                              size: 48, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'Nessun download in coda',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: downloadState.queue.length,
                        itemBuilder: (context, index) {
                          final download = downloadState.queue[index];
                          return _DownloadItem(
                            download: download,
                            onCancel: () {
                              ref
                                  .read(downloadProvider.notifier)
                                  .cancelDownload(download.id);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          // Floating button
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: hasDownloads
                    ? AppTheme.primaryColor
                    : AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isExpanded ? Icons.close : Icons.download,
                    color: hasDownloads ? Colors.white : AppTheme.primaryColor,
                    size: 24,
                  ),
                  if (hasDownloads) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${downloadState.queue.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadItem extends StatelessWidget {
  final Download download;
  final VoidCallback onCancel;

  const _DownloadItem({
    required this.download,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloading = download.status == DownloadStatus.downloading;
    final isPending = download.status == DownloadStatus.pending;
    final isFailed = download.status == DownloadStatus.failed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getStatusColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: isDownloading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: download.progress / 100,
                        strokeWidth: 2,
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : Icon(
                      _getStatusIcon(),
                      size: 20,
                      color: _getStatusColor(),
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
                  download.animeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Episodio ${download.episodeNumber}${isDownloading ? ' - ${download.progress}%' : ''}',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                if (isFailed && download.errorMessage != null)
                  Text(
                    download.errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Cancel button
          if (isPending || isDownloading)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onCancel,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              color: Colors.grey,
            ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (download.status) {
      case DownloadStatus.downloading:
        return AppTheme.primaryColor;
      case DownloadStatus.pending:
        return Colors.orange;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.cancelled:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (download.status) {
      case DownloadStatus.downloading:
        return Icons.downloading;
      case DownloadStatus.pending:
        return Icons.schedule;
      case DownloadStatus.completed:
        return Icons.check_circle;
      case DownloadStatus.failed:
        return Icons.error;
      case DownloadStatus.cancelled:
        return Icons.cancel;
    }
  }
}
