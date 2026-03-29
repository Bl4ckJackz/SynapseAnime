import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../../domain/entities/manga.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';

class MangaCard extends StatefulWidget {
  final Manga manga;
  final double width;
  final double height;
  final bool showTitle;
  final EdgeInsetsGeometry? margin;
  final String? heroTagSuffix;

  const MangaCard({
    super.key,
    required this.manga,
    this.width = 220,
    this.height = 320,
    this.showTitle = true,
    this.margin,
    this.heroTagSuffix,
  });

  @override
  State<MangaCard> createState() => _MangaCardState();
}

class _MangaCardState extends State<MangaCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;
  bool _isPressed = false;

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
      setState(() => _isFront = false);
    } else if (!isHovering && !_isFront) {
      _controller.reverse();
      setState(() => _isFront = true);
    }
  }

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

  Color _getGenreColor(String genre) {
    final g = genre.toLowerCase();
    if (g.contains('action') || g.contains('azione')) return Colors.red;
    if (g.contains('adventure') || g.contains('avventura')) return Colors.orange;
    if (g.contains('comedy') || g.contains('commedia')) return Colors.amber;
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
    final isFlexible = widget.height == double.infinity;

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () => context.push('/manga/${widget.manga.id}'),
        onLongPress: _toggleFlip,
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: widget.width == double.infinity ? null : widget.width,
            margin: widget.margin ?? const EdgeInsets.only(right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isFlexible)
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) => _buildAnimatedContent(),
                    ),
                  )
                else
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) => _buildAnimatedContent(),
                  ),
                if (widget.showTitle) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.manga.title,
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
      ),
    );
  }

  Widget _buildAnimatedContent() {
    final angle = _animation.value * math.pi;
    final isBack = angle >= math.pi / 2;

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(angle),
      child: isBack
          ? Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(math.pi),
              child: _buildBack(),
            )
          : _buildFront(),
    );
  }

  Widget _buildFront() {
    final proxiedUrl = _getProxiedUrl(widget.manga.coverUrl);
    final width = widget.width == double.infinity ? null : widget.width;
    final height = widget.height == double.infinity ? null : widget.height;

    final heroTag = widget.heroTagSuffix != null
        ? 'manga-cover-${widget.manga.id}-${widget.heroTagSuffix}'
        : null;

    final imageWidget = CachedNetworkImage(
      imageUrl: proxiedUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      memCacheWidth: 440,
      fadeInDuration: const Duration(milliseconds: 200),
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
        child: const Icon(Icons.broken_image_outlined, color: AppTheme.textMuted),
      ),
    );

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppTheme.surfaceColor,
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (heroTag != null)
              Hero(tag: heroTag, child: imageWidget)
            else
              imageWidget,

            // Rating badge - glassmorphism
            if (widget.manga.score != null)
              Positioned(
                top: 8,
                left: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            widget.manga.score!.toStringAsFixed(1),
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
                ),
              ),

            // Status badge - glassmorphism
            if (widget.manga.status == MangaStatus.ongoing)
              Positioned(
                top: 8,
                right: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.5),
                      ),
                      child: const Text(
                        'IN CORSO',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),

            // Type badge (manhwa/manhua)
            if (widget.manga.type != null &&
                (widget.manga.type!.toLowerCase() == 'manhwa' ||
                    widget.manga.type!.toLowerCase() == 'manhua'))
              Positioned(
                bottom: 8,
                left: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (widget.manga.type!.toLowerCase() == 'manhwa'
                                ? Colors.blue
                                : Colors.orange)
                            .withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.manga.type!.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBack() {
    final width = widget.width == double.infinity ? null : widget.width;
    final height = widget.height == double.infinity ? null : widget.height;

    return Container(
      height: height,
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppTheme.surfaceColor.withOpacity(0.85),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: AppTheme.elevatedShadow,
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
                    Text(
                      widget.manga.title,
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
                    Row(
                      children: [
                        if (widget.manga.year != null)
                          Text(
                            '${widget.manga.year}',
                            style: const TextStyle(fontSize: 11, color: Colors.greenAccent),
                          ),
                        const SizedBox(width: 8),
                        if (widget.manga.chapters != null && widget.manga.chapters! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white30),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '${widget.manga.chapters} cap',
                              style: const TextStyle(fontSize: 9, color: Colors.white70),
                            ),
                          ),
                        const SizedBox(width: 4),
                        if (widget.manga.volumes != null && widget.manga.volumes! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white30),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              '${widget.manga.volumes} vol',
                              style: const TextStyle(fontSize: 9, color: Colors.white70),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => context.push('/manga/${widget.manga.id}'),
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.menu_book_rounded, color: Colors.black, size: 20),
                                  SizedBox(width: 4),
                                  Text(
                                    'Leggi',
                                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (widget.manga.synopsis != null && widget.manga.synopsis!.isNotEmpty)
                      Text(
                        widget.manga.synopsis!,
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildDetailBadge(
                          icon: Icons.circle,
                          color: widget.manga.status == MangaStatus.ongoing
                              ? Colors.greenAccent
                              : widget.manga.status == MangaStatus.completed
                                  ? Colors.blueAccent
                                  : Colors.orangeAccent,
                          label: widget.manga.statusText,
                        ),
                        if (widget.manga.authors.isNotEmpty)
                          _buildDetailBadge(
                            icon: Icons.person_outline,
                            color: Colors.pinkAccent,
                            label: widget.manga.authors.first,
                          ),
                      ],
                    ),
                    const Spacer(),
                    if (widget.manga.genres.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: widget.manga.genres.take(3).map((genre) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getGenreColor(genre).withOpacity(0.2),
                              border: Border.all(
                                color: _getGenreColor(genre).withOpacity(0.5),
                                width: 1,
                              ),
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
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailBadge({required IconData icon, required Color color, required String label}) {
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
