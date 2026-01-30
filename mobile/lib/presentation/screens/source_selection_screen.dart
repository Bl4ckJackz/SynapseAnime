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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scegli una Sorgente'),
        centerTitle: true,
      ),
      body: sourcesAsync.when(
        data: (sources) => GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemCount: sources.length,
          itemBuilder: (context, index) {
            final source = sources[index];
            return _SourceCard(source: source);
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Errore: $err')),
      ),
    );
  }
}

class _SourceCard extends ConsumerWidget {
  final dynamic source;

  const _SourceCard({required this.source});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = source.isActive;

    return Card(
      elevation: isActive ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive ? AppTheme.primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () async {
          await ref
              .read(activeSourceIdProvider.notifier)
              .setActiveSource(source.id);
          if (context.mounted) {
            context.goNamed('home');
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getSourceIcon(source.id),
              size: 40,
              color: isActive ? AppTheme.primaryColor : Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              source.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isActive ? AppTheme.primaryColor : null,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                source.description,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getSourceIcon(String id) {
    switch (id) {
      case 'jikan':
        return Icons.language;
      case 'animeunity':
        return Icons.movie_filter;
      case 'hianime':
        return Icons.play_circle_filled;
      case 'animekai':
        return Icons.kitesurfing; // Just a placeholder
      case 'animesaturn':
        return Icons.wb_sunny;
      case 'kickassanime':
        return Icons.flash_on;
      default:
        return Icons.source;
    }
  }
}
