import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/anime.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import 'package:go_router/go_router.dart';

String _getProxiedUrl(String? url) {
  if (url == null || url.isEmpty) {
    return 'https://upload.wikimedia.org/wikipedia/commons/c/ca/1x1.png';
  }
  if (url.contains('animeunity.so') ||
      url.contains('img.animeunity') ||
      url.contains('cdn.noitatnemucod.net')) {
    return '${AppConstants.apiBaseUrl}/stream/proxy-image?url=${Uri.encodeComponent(url)}';
  }
  return url;
}

class FeaturedSlider extends StatefulWidget {
  final List<Anime> animeList;

  const FeaturedSlider({super.key, required this.animeList});

  @override
  State<FeaturedSlider> createState() => _FeaturedSliderState();
}

class _FeaturedSliderState extends State<FeaturedSlider> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.animeList.isEmpty) return const SizedBox.shrink();

    final items = widget.animeList.take(7).toList();

    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 420,
            viewportFraction: 0.88,
            enlargeCenterPage: true,
            enlargeStrategy: CenterPageEnlargeStrategy.zoom,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 5),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            autoPlayCurve: Curves.fastOutSlowIn,
            onPageChanged: (index, reason) {
              setState(() => _currentIndex = index);
            },
          ),
          items: items.map((anime) {
            return Builder(
              builder: (BuildContext context) {
                return GestureDetector(
                  onTap: () => context.pushNamed('animeDetail',
                      pathParameters: {'id': anime.id}),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.elevatedShadow,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Cover image
                          CachedNetworkImage(
                            imageUrl: _getProxiedUrl(anime.coverUrl),
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            memCacheWidth: 800,
                            fadeInDuration: const Duration(milliseconds: 300),
                            placeholder: (context, url) => Container(
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
                              color: AppTheme.surfaceColor,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                color: AppTheme.textMuted,
                                size: 40,
                              ),
                            ),
                          ),

                          // Gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: AppTheme.cardOverlayGradient,
                            ),
                          ),

                          // Bottom info with glassmorphism
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                              ),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    border: const Border(
                                      top: BorderSide(
                                        color: Color(0x20FFFFFF),
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Title
                                      Text(
                                        anime.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          height: 1.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),

                                      // Rating + Status row
                                      Row(
                                        children: [
                                          const Icon(Icons.star_rounded,
                                              color: Colors.amber, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            anime.rating.toStringAsFixed(1),
                                            style: const TextStyle(
                                                color: Colors.white, fontSize: 14),
                                          ),
                                          const SizedBox(width: 12),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: anime.status == AnimeStatus.ongoing
                                                  ? Colors.green.withOpacity(0.3)
                                                  : Colors.blue.withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: anime.status == AnimeStatus.ongoing
                                                    ? Colors.green.withOpacity(0.5)
                                                    : Colors.blue.withOpacity(0.5),
                                              ),
                                            ),
                                            child: Text(
                                              anime.status == AnimeStatus.ongoing
                                                  ? 'ON AIR'
                                                  : 'COMPLETATO',
                                              style: TextStyle(
                                                color: anime.status == AnimeStatus.ongoing
                                                    ? Colors.greenAccent
                                                    : Colors.lightBlueAccent,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                      // Genre chips
                                      if (anime.genres.isNotEmpty)
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: anime.genres.take(3).map((genre) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.white.withOpacity(0.2),
                                                  width: 0.5,
                                                ),
                                              ),
                                              child: Text(
                                                genre,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Page indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentIndex == index ? 24 : 8,
              height: 4,
              decoration: BoxDecoration(
                color: _currentIndex == index
                    ? AppTheme.primaryColor
                    : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ],
    );
  }
}
