import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/anime.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';

class AnimeCard extends StatelessWidget {
  final Anime anime;
  final double width;
  final double height;
  final bool showTitle;

  const AnimeCard({
    super.key,
    required this.anime,
    this.width = 140,
    this.height = 170,
    this.showTitle = true,
  });

  String _getProxiedUrl(String? url) {
    if (url == null) return 'https://via.placeholder.com/150';
    if (url.contains('animeunity.so') ||
        url.contains('img.animeunity') ||
        url.contains('cdn.noitatnemucod.net')) {
      return '${AppConstants.apiBaseUrl}/stream/proxy-image?url=${Uri.encodeComponent(url)}';
    }
    return url;
  }

  Color _getGenreColor(String genre) {
    final genreLower = genre.toLowerCase();
    if (genreLower.contains('action')) return Colors.red;
    if (genreLower.contains('adventure')) return Colors.orange;
    if (genreLower.contains('comedy')) return Colors.amber;
    if (genreLower.contains('drama')) return Colors.purple;
    if (genreLower.contains('fantasy')) return Colors.indigo;
    if (genreLower.contains('horror')) return Colors.grey;
    if (genreLower.contains('mystery')) return Colors.blueGrey;
    if (genreLower.contains('romance')) return Colors.pink;
    if (genreLower.contains('sci-fi') || genreLower.contains('scifi'))
      return Colors.cyan;
    if (genreLower.contains('slice of life')) return Colors.green;
    if (genreLower.contains('sports')) return Colors.teal;
    if (genreLower.contains('supernatural')) return Colors.deepPurple;
    if (genreLower.contains('thriller')) return Colors.brown;
    return AppTheme.primaryColor; // Default
  }

  @override
  Widget build(BuildContext context) {
    final proxiedUrl = _getProxiedUrl(anime.coverUrl);

    return GestureDetector(
      onTap: () {
        print('Selected Anime: ${anime.title}');
        context.pushNamed('animeDetail', pathParameters: {'id': anime.id});
      },
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: proxiedUrl,
                    width: width,
                    height: height,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppTheme.surfaceColor,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppTheme.surfaceColor,
                      child: const Icon(Icons.error),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 12),
                        const SizedBox(width: 2),
                        Text(
                          anime.rating.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (anime.status == AnimeStatus.ongoing)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'ON AIR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (anime.status == AnimeStatus.upcoming)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        anime.airedFrom != null
                            ? '${anime.airedFrom!.day}/${anime.airedFrom!.month}'
                            : 'COMING SOON',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (anime.duration != null && anime.duration!.isNotEmpty)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        anime.duration!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (showTitle) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 36, // Fixed height for title (approx 2 lines)
                child: Text(
                  anime.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 13),
                ),
              ),
              if (anime.genres.isNotEmpty) ...[
                const SizedBox(height: 4),
                SizedBox(
                  height: 20,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: anime.genres.take(2).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 4),
                    itemBuilder: (context, index) {
                      final genre = anime.genres[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getGenreColor(genre).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _getGenreColor(genre).withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          genre,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: _getGenreColor(genre),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
