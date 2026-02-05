import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers/anime_provider.dart';
import '../widgets/anime_card.dart';
import 'home_screen.dart'; // Reusing ShimmerAnimeList if public or move it

class GenreGridScreen extends ConsumerWidget {
  final String genre;

  const GenreGridScreen({
    super.key,
    required this.genre,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Capitalize first letter just in case
    final title = genre.isNotEmpty
        ? '${genre[0].toUpperCase()}${genre.substring(1)}'
        : genre;

    final animeAsync = ref.watch(animeGenreProvider(genre));

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels >=
              scrollInfo.metrics.maxScrollExtent - 200) {
            ref.read(animeGenreProvider(genre).notifier).loadMore();
          }
          return false;
        },
        child: animeAsync.when(
          data: (animeList) {
            if (animeList.isEmpty) {
              return const Center(
                  child: Text('Nessun anime trovato per questa categoria'));
            }

            // Responsive grid logic (match SearchScreen)
            final width = MediaQuery.of(context).size.width;
            final crossAxisCount = width > 600 ? 5 : 3;
            // Adjust aspect ratio based on card size (approx 220/320 = 0.68)
            const childAspectRatio = 0.65;

            return GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: childAspectRatio,
              ),
              itemCount:
                  animeList.length + 1, // +1 for loading spinner at bottom
              itemBuilder: (context, index) {
                if (index == animeList.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                return AnimeCard(
                  anime: animeList[index],
                  width: double.infinity,
                  height: double.infinity,
                  margin: EdgeInsets.zero,
                  showTitle: false,
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Errore: $err')),
        ),
      ),
    );
  }
}
