import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers/anime_provider.dart';
import '../widgets/episode_card.dart';
import '../widgets/shimmer_loading.dart';
import '../../core/theme.dart';

class RecentEpisodesScreen extends ConsumerStatefulWidget {
  const RecentEpisodesScreen({super.key});

  @override
  ConsumerState<RecentEpisodesScreen> createState() =>
      _RecentEpisodesScreenState();
}

class _RecentEpisodesScreenState extends ConsumerState<RecentEpisodesScreen> {
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
      ref.read(recentEpisodesPaginationProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final episodesAsync = ref.watch(recentEpisodesPaginationProvider);
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 600 ? 4 : 2;
    const childAspectRatio = 1.6;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Episodi Recenti'),
      ),
      body: episodesAsync.when(
        data: (episodes) {
          if (episodes.isEmpty) {
            return const Center(child: Text('Nessun episodio trovato'));
          }
          return GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: childAspectRatio,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: episodes.length + 1,
            itemBuilder: (context, index) {
              if (index == episodes.length) {
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
              return EpisodeCard(
                episode: episodes[index],
                width: double.infinity,
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
