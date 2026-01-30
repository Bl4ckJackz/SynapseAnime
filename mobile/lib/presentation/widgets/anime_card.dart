import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/anime.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';

/// Clean Material Design anime card with genre chips
class AnimeCard extends StatelessWidget {
  final Anime anime;
  final double width;
  final double height;
  final bool showTitle;

  const AnimeCard({
    super.key,
    required this.anime,
    this.width = 160,
    this.height = 220,
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
    final g = genre.toLowerCase();
    if (g.contains('action')) return Colors.red;
    if (g.contains('adventure')) return Colors.orange;
    if (g.contains('comedy')) return Colors.amber;
    if (g.contains('drama')) return Colors.purple;
    if (g.contains('fantasy')) return Colors.indigo;
    if (g.contains('horror')) return Colors.grey;
    if (g.contains('romance')) return Colors.pink;
    if (g.contains('sci-fi') || g.contains('scifi')) return Colors.cyan;
    if (g.contains('slice of life')) return Colors.green;
    if (g.contains('supernatural')) return Colors.deepPurple;
    return AppTheme.primaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final proxiedUrl = _getProxiedUrl(anime.coverUrl);

    return GestureDetector(
      onTap: () {
        context.pushNamed('animeDetail', pathParameters: {'id': anime.id});
      },
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 16), // More space between cards
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card with elevated container for better separation
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppTheme.surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    // Image
                    CachedNetworkImage(
                      imageUrl: proxiedUrl,
                      width: width,
                      height: height,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: width,
                        height: height,
                        color: AppTheme.surfaceColor,
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: width,
                        height: height,
                        color: AppTheme.surfaceColor,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),

                    // Rating badge - top left
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              anime.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Status badge - top right
                    if (anime.status == AnimeStatus.ongoing)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'IN CORSO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
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
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            anime.airedFrom != null
                                ? '${anime.airedFrom!.day}/${anime.airedFrom!.month}'
                                : 'PRESTO',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Title
            if (showTitle) ...[
              const SizedBox(height: 10),
              Text(
                anime.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),

              // Genre chips
              if (anime.genres.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: anime.genres.take(2).map((genre) {
                    final color = _getGenreColor(genre);
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: color.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        genre,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
