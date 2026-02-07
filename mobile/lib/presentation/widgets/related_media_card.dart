import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/utils/image_utils.dart';
import '../../domain/providers/anime_provider.dart';
import '../../domain/providers/manga_provider.dart';

class RelatedMediaCard extends ConsumerWidget {
  final String malId;
  final String type; // 'anime' or 'manga'
  final String title;
  final String relationType;

  const RelatedMediaCard({
    super.key,
    required this.malId,
    required this.type,
    required this.title,
    required this.relationType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine which provider to watch based on type
    final AsyncValue<dynamic> detailsAsync = type == 'anime'
        ? ref.watch(animeDetailsProvider(malId))
        : ref.watch(mangaDetailsProvider(malId));

    return GestureDetector(
      onTap: () {
        if (type == 'anime') {
          context.push('/anime/$malId');
        } else if (type == 'manga') {
          context.push('/manga/$malId');
        }
      },
      child: Container(
        width: 150, // Slightly wider to match card feel
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Image
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: AppTheme.surfaceColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image Content
                      detailsAsync.when(
                        data: (data) {
                          final imageUrl = data.coverUrl;
                          if (imageUrl == null || imageUrl.isEmpty) {
                            return _buildPlaceholder();
                          }
                          return CachedNetworkImage(
                            imageUrl: ImageUtils.getProxiedUrl(
                              imageUrl,
                              headers: {
                                'Referer': 'https://myanimelist.net/'
                              }, // Default safer referer
                            ),
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                _buildPlaceholder(),
                            placeholder: (context, url) => Container(
                              color: AppTheme.surfaceColor,
                              child: const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primaryColor),
                              ),
                            ),
                          );
                        },
                        loading: () => Container(
                          color: AppTheme.surfaceColor,
                          child: const Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.primaryColor),
                          ),
                        ),
                        error: (_, __) => _buildPlaceholder(),
                      ),

                      // Relation Type Badge (Top Left)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            relationType,
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
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.surfaceColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'anime' ? Icons.movie_outlined : Icons.menu_book_outlined,
              color: AppTheme.textMuted,
              size: 32,
            ),
            const SizedBox(height: 4),
            Text(
              type.toUpperCase(),
              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
