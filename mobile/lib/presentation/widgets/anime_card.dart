import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../../domain/entities/anime.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';
import '../../domain/providers/watch_history_provider.dart';
import '../../data/repositories/user_repository.dart';

class AnimeCard extends ConsumerStatefulWidget {
  final Anime anime;
  final double width;
  final double height;
  final bool showTitle;
  final EdgeInsetsGeometry? margin;

  const AnimeCard({
    super.key,
    required this.anime,
    this.width = 220,
    this.height = 320,
    this.showTitle = true,
    this.margin,
  });

  @override
  ConsumerState<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends ConsumerState<AnimeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _animation;
  bool _isFront = true;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  void _onHover(bool isHovering) {
    if (isHovering && _isFront) {
      _controller.forward();
      setState(() {
        _isFront = false;
        _isHovering = true;
      });
    } else if (!isHovering && !_isFront) {
      _controller.reverse();
      setState(() {
        _isFront = true;
        _isHovering = false;
      });
    }
  }

  String _getProxiedUrl(String? url) {
    if (url == null)
      return 'https://upload.wikimedia.org/wikipedia/commons/c/ca/1x1.png';
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
    // Watch History here (at top level of build, not inside AnimatedBuilder)
    final historyAsync = ref.watch(watchHistoryProvider);
    final historyItem =
        historyAsync.valueOrNull?.cast<WatchHistoryItem?>().firstWhere(
              (item) => item?.anime?.id == widget.anime.id,
              orElse: () => null,
            );

    final isFlexible = widget.height == double.infinity;

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: GestureDetector(
        onTap: () {
          context.pushNamed('animeDetail',
              pathParameters: {'id': widget.anime.id});
        },
        onLongPress: _toggleFlip,
        child: Container(
          width: widget.width == double.infinity ? null : widget.width,
          margin: widget.margin ?? const EdgeInsets.only(right: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Animated Flip Card
              if (isFlexible)
                Expanded(
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) =>
                        _buildAnimatedContent(historyItem),
                  ),
                )
// ... (skipping to _buildFront)
// Wait, I can't skip across methods easily. I will do 2 separate chunks.

              else
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) =>
                      _buildAnimatedContent(historyItem),
                ),

              // Title
              if (widget.showTitle) ...[
                const SizedBox(height: 10),
                Text(
                  widget.anime.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedContent(WatchHistoryItem? historyItem) {
    final angle = _animation.value * math.pi;
    final isBack = angle >= math.pi / 2;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001) // Perspective
        ..rotateY(angle),
      child: isBack
          ? Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(math.pi),
              child: _buildBack(historyItem),
            )
          : _buildFront(),
    );
  }

  Widget _buildFront() {
    final proxiedUrl = _getProxiedUrl(widget.anime.coverUrl);
    final width = widget.width == double.infinity ? null : widget.width;
    final height = widget.height == double.infinity ? null : widget.height;

    return Container(
      height: height,
      width: width, // Use computed width/height or null (fill)
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
            // Image
            CachedNetworkImage(
              imageUrl: proxiedUrl,
              width: width,
              height: height,
              fit: BoxFit.cover,
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
                  color: Colors.black.withOpacity(0.75),
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
                      widget.anime.rating.toStringAsFixed(1),
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
            if (widget.anime.status == AnimeStatus.ongoing)
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

            if (widget.anime.status == AnimeStatus.upcoming)
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
                    widget.anime.airedFrom != null
                        ? '${widget.anime.airedFrom!.day}/${widget.anime.airedFrom!.month}'
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
    );
  }

  Widget _buildBack(WatchHistoryItem? historyItem) {
    final bool canResume = historyItem != null;
    final String playButtonLabel = canResume ? 'Riprendi' : 'Guarda';
    final IconData playButtonIcon =
        canResume ? Icons.play_arrow_rounded : Icons.play_arrow_rounded;

    final width = widget.width == double.infinity ? null : widget.width;
    final height = widget.height == double.infinity ? null : widget.height;

    return Container(
      height: height,
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF1A1A1A),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      widget.anime.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Info Badges
                    Row(
                      children: [
                        Text(
                          '${widget.anime.releaseYear}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.greenAccent),
                        ),
                        const SizedBox(width: 8),
                        if (widget.anime.totalEpisodes > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white30),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '${widget.anime.totalEpisodes} ep',
                              style: const TextStyle(
                                  fontSize: 9, color: Colors.white70),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              if (canResume) {
                                context.pushNamed('player', pathParameters: {
                                  'animeId': widget.anime.id,
                                  'episodeId': historyItem.episode.id,
                                });
                              } else {
                                context.pushNamed('animeDetail',
                                    pathParameters: {'id': widget.anime.id});
                              }
                            },
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(playButtonIcon,
                                      color: Colors.black, size: 20),
                                  const SizedBox(width: 4),
                                  Text(
                                    playButtonLabel,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Description (Synopsis)
                    if (widget.anime.description.isNotEmpty)
                      Text(
                        widget.anime.description,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Extra Details Row (Status, Source)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildDetailBadge(
                          icon: Icons.circle,
                          color: widget.anime.status == AnimeStatus.ongoing
                              ? Colors.greenAccent
                              : Colors.redAccent,
                          label: widget.anime.statusText,
                        ),
                        if (widget.anime.source != null)
                          _buildDetailBadge(
                            icon: Icons.menu_book_rounded,
                            color: Colors.blueAccent,
                            label: widget.anime.source!,
                          ),
                        if (widget.anime.duration != null)
                          _buildDetailBadge(
                            icon: Icons.access_time_rounded,
                            color: Colors.orangeAccent,
                            label: widget.anime.duration!,
                          ),
                      ],
                    ),

                    const Spacer(),

                    // Genres Chips
                    if (widget.anime.genres.isNotEmpty) ...[
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: widget.anime.genres.take(3).map((genre) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getGenreColor(genre).withOpacity(0.2),
                              border: Border.all(
                                  color: _getGenreColor(genre).withOpacity(0.5),
                                  width: 1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              genre,
                              style: TextStyle(
                                fontSize: 10,
                                color: _getGenreColor(genre),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailBadge(
      {required IconData icon, required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
