import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../domain/entities/episode.dart';

class EpisodeCard extends StatelessWidget {
  final Episode episode;
  final double width;
  final double height;

  const EpisodeCard({
    super.key,
    required this.episode,
    this.width = 200,
    this.height = 140, // Height for the image part roughly, or total container?
    // Let's make the container responsive
  });

  String _getProxiedUrl(String? url) {
    if (url == null || url.isEmpty) {
      return 'https://upload.wikimedia.org/wikipedia/commons/c/ca/1x1.png';
    }
    // AnimeUnity images block requests without Referer
    // We can either proxy them or try adding headers directly
    if (url.contains('img.animeunity') || url.contains('animeunity.so') || url.contains('cdn.noitatnemucod.net')) {
      // Direct access often fails even with headers if there's strict checking
      // Use proxy endpoint if available
      return '${AppConstants.apiBaseUrl}/stream/proxy-image?url=${Uri.encodeComponent(url)}';
    }
    return url;
  }

  Map<String, String>? _getHeaders(String url) {
    if (url.contains('animeunity')) {
      return {
        'Referer': 'https://www.animeunity.so/',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final finalUrl = _getProxiedUrl(episode.thumbnail);

    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () {
          // Navigate to Player with animeId and episodeId
          context.pushNamed(
            'player',
            pathParameters: {
              'animeId': episode.animeId,
              'episodeId': episode.id,
            },
            queryParameters: {
              if (episode.source != null) 'source': episode.source!,
            },
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail Container
            Container(
              height: 112, // 16:9 ratio approx for 200 width
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.surfaceColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: finalUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 400,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (context, url) => Container(
                        color: AppTheme.surfaceColor,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppTheme.surfaceColor,
                        child: const Icon(Icons.broken_image,
                            color: AppTheme.textMuted),
                      ),
                    ),
                    // Play icon overlay
                    Container(
                      color: Colors.black.withOpacity(0.2),
                      child: const Center(
                        child: Icon(
                          Icons.play_circle_fill_rounded,
                          color: Colors.white70,
                          size: 32,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Title
            Text(
              episode.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            // Episode Number Chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Text(
                'Episodio ${episode.number}',
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
