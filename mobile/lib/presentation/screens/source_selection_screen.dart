import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/providers/active_source_provider.dart';
import '../../domain/providers/source_provider.dart';
import '../../core/theme.dart';

class SourceSelectionScreen extends ConsumerWidget {
  const SourceSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourcesAsync = ref.watch(sourceProvider);
    final currentSource = ref.watch(activeSourceIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scegli Sorgente'),
        centerTitle: true,
      ),
      body: sourcesAsync.when(
        data: (sources) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Current source indicator
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sorgente Attiva',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                        Text(
                          currentSource.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Available sources header
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Sorgenti Disponibili',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                ),
              ),
            ),

            // Source list
            ...sources.map((source) => _SourceTile(
                  source: source,
                  isActive: source.id == currentSource,
                )),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              Text('Errore: $err'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(sourceProvider),
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceTile extends ConsumerWidget {
  final dynamic source;
  final bool isActive;

  const _SourceTile({required this.source, required this.isActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isActive ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? AppTheme.primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      color: AppTheme.cardColor,
      child: InkWell(
        onTap: () async {
          await ref
              .read(activeSourceIdProvider.notifier)
              .setActiveSource(source.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sorgente cambiata: ${source.name}'),
                duration: const Duration(seconds: 2),
              ),
            );
            context.pop();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Source icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      isActive ? AppTheme.primaryColor : AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getSourceIcon(source.id),
                  color: isActive ? Colors.white : AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 16),

              // Source info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          source.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isActive ? AppTheme.primaryColor : null,
                          ),
                        ),
                        if (isActive) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'ATTIVA',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      source.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                isActive ? Icons.check_circle : Icons.chevron_right,
                color: isActive ? AppTheme.primaryColor : AppTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getSourceIcon(String id) {
    switch (id) {
      case 'jikan':
        return Icons.public;
      case 'animeunity':
        return Icons.movie_filter;
      case 'hianime':
        return Icons.play_circle;
      case 'animekai':
        return Icons.sports_martial_arts;
      case 'animesaturn':
        return Icons.wb_sunny;
      case 'kickassanime':
        return Icons.flash_on;
      default:
        return Icons.source;
    }
  }
}
