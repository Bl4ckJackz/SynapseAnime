import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers/anime_provider.dart';
import '../../core/theme.dart';
import '../widgets/anime_card.dart';

class PaginatedAnimeListScreen extends ConsumerStatefulWidget {
  final AnimeFilter filter;
  final String title;

  const PaginatedAnimeListScreen({
    super.key,
    required this.filter,
    required this.title,
  });

  @override
  ConsumerState<PaginatedAnimeListScreen> createState() =>
      _PaginatedAnimeListScreenState();
}

class _PaginatedAnimeListScreenState
    extends ConsumerState<PaginatedAnimeListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedAnimeFilterProvider(widget.filter).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final animeListAsync =
        ref.watch(paginatedAnimeFilterProvider(widget.filter));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
      ),
      body: animeListAsync.when(
        data: (paginatedResult) {
          final animeList = paginatedResult.items;
          final hasMore = paginatedResult.hasMore;

          if (animeList.isEmpty) {
            return const Center(child: Text('Nessun anime trovato'));
          }

          final width = MediaQuery.of(context).size.width;
          // Use 2 columns on mobile for larger images, 4 on larger screens
          final crossAxisCount = width > 600 ? 5 : 2;
          // Standard aspect ratio for Anime Cards (Portrait)
          // Adjust to make them slightly taller/larger if needed
          const childAspectRatio = 0.7;

          return GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            // +1 for spinner only if we have more pages
            itemCount: animeList.length + (hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == animeList.length) {
                // Show spinner only if hasMore is true (implied by itemCount)
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                );
              }
              return AnimeCard(anime: animeList[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Errore: $err')),
      ),
    );
  }
}
