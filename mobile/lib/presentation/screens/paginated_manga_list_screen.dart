import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers/manga_provider.dart';
import '../widgets/manga_card.dart';

class PaginatedMangaListScreen extends ConsumerStatefulWidget {
  final String title;
  final MangaFilter filter;

  const PaginatedMangaListScreen({
    super.key,
    required this.title,
    required this.filter,
  });

  @override
  ConsumerState<PaginatedMangaListScreen> createState() =>
      _PaginatedMangaListScreenState();
}

class _PaginatedMangaListScreenState
    extends ConsumerState<PaginatedMangaListScreen> {
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
      ref.read(paginatedMangaFilterProvider(widget.filter).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mangaListAsync =
        ref.watch(paginatedMangaFilterProvider(widget.filter));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: mangaListAsync.when(
        data: (paginatedResult) {
          final mangaList = paginatedResult.items;
          final hasMore = paginatedResult.hasMore;

          if (mangaList.isEmpty) {
            return const Center(child: Text('Nessun manga trovato'));
          }

          final width = MediaQuery.of(context).size.width;
          // 2 columns for flip cards (they need more space)
          final crossAxisCount = width > 800 ? 4 : (width > 500 ? 3 : 2);
          const childAspectRatio = 0.5;

          return GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: mangaList.length + (hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == mangaList.length) {
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
              return MangaCard(
                manga: mangaList[index],
                width: double.infinity,
                height: double.infinity,
                showTitle: true,
                margin: EdgeInsets.zero,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Errore: $err')),
      ),
    );
  }
}
