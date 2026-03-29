import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/utils/image_utils.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/providers/manga_provider.dart';
import '../../domain/providers/player_settings_provider.dart';
import '../widgets/app_loader.dart';

class MangaReaderScreen extends ConsumerStatefulWidget {
  final String mangaId;
  final String chapterId;
  final String? preferredSource;

  const MangaReaderScreen({
    super.key,
    required this.mangaId,
    required this.chapterId,
    this.preferredSource,
  });

  @override
  ConsumerState<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends ConsumerState<MangaReaderScreen> {
  bool _showControls = true;
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  final TransformationController _transformController = TransformationController();
  final List<String> _loadedPages = [];
  final List<MangaChapter> _loadedChapters = [];
  bool _isLoadingNextChapter = false;

  MangaChapter? _currentChapter;
  List<MangaChapter> _allChapters = [];
  int _currentPageIndex = 0;
  late ReadingMode _readingMode;
  bool _nightMode = false;

  String _getSourceFromId(String chapterId) {
    if (chapterId.contains(':')) return chapterId.split(':')[0];
    return 'mangadex';
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scrollController.addListener(_onScroll);
    final settings = ref.read(playerSettingsProvider);
    _readingMode = settings.defaultReadingMode;
    _nightMode = settings.nightModeFilter;
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadedPages.isEmpty) return;

    final position = _scrollController.position;
    // Auto-load next chapter
    if (position.pixels >= position.maxScrollExtent - 500 &&
        !_isLoadingNextChapter) {
      _loadNextChapter();
    }

    // Update current page index for vertical modes
    if (_loadedPages.isNotEmpty && _scrollController.hasClients) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent > 0) {
        final currentPage =
            (_scrollController.offset / maxExtent * _loadedPages.length)
                .floor()
                .clamp(0, _loadedPages.length - 1);
        if (_currentPageIndex != currentPage) {
          setState(() => _currentPageIndex = currentPage);
        }
      }
    }
  }

  Future<void> _loadNextChapter() async {
    if (_allChapters.isEmpty || _currentChapter == null || _isLoadingNextChapter) return;

    final currentIndex = _allChapters.indexWhere((c) => c.id == _currentChapter!.id);
    if (currentIndex == -1 || currentIndex >= _allChapters.length - 1) return;

    final nextChapter = _allChapters[currentIndex + 1];
    if (_loadedChapters.any((c) => c.id == nextChapter.id)) return;

    setState(() => _isLoadingNextChapter = true);

    try {
      final pages = await ref.read(chapterPagesProvider(
        ChapterRequest(mangaId: widget.mangaId, chapterId: nextChapter.id),
      ).future);

      if (mounted) {
        setState(() {
          _loadedPages.addAll(pages);
          _loadedChapters.add(nextChapter);
          _currentChapter = nextChapter;
          _isLoadingNextChapter = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Caricato Capitolo ${nextChapter.number}')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingNextChapter = false);
    }
  }

  void _navigateToChapter(MangaChapter chapter) async {
    setState(() {
      _loadedPages.clear();
      _loadedChapters.clear();
      _currentPageIndex = 0;
      _isLoadingNextChapter = true;
    });

    try {
      final pages = await ref.read(chapterPagesProvider(
        ChapterRequest(mangaId: widget.mangaId, chapterId: chapter.id),
      ).future);

      if (mounted) {
        setState(() {
          _loadedPages.addAll(pages);
          _loadedChapters.add(chapter);
          _currentChapter = chapter;
          _isLoadingNextChapter = false;
        });

        if (_readingMode == ReadingMode.horizontalSwipe) {
          _pageController.jumpToPage(0);
        } else if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingNextChapter = false);
    }
  }

  void _handleDoubleTapZoom(TapDownDetails details) {
    if (_transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
    } else {
      final position = details.localPosition;
      _transformController.value = Matrix4.identity()
        ..translate(-position.dx, -position.dy)
        ..scale(2.5)
        ..translate(position.dx / 2.5, position.dy / 2.5);
    }
  }

  void _showChapterDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Capitoli',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _allChapters.length,
                itemBuilder: (context, index) {
                  final chapter = _allChapters[index];
                  final isCurrent = chapter.id == _currentChapter?.id;
                  return ListTile(
                    title: Text(
                      chapter.title ?? 'Capitolo ${chapter.number ?? index + 1}',
                      style: TextStyle(
                        color: isCurrent ? AppTheme.primaryColor : Colors.white,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      'Cap. ${chapter.number ?? '?'}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    trailing: isCurrent
                        ? const Icon(Icons.play_arrow, color: AppTheme.primaryColor)
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToChapter(chapter);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReadingModeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Modalità Lettura',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            _buildModeOption(ReadingMode.verticalScroll, Icons.swap_vert, 'Scorrimento verticale'),
            _buildModeOption(ReadingMode.horizontalSwipe, Icons.swap_horiz, 'Pagina per pagina'),
            _buildModeOption(ReadingMode.webtoon, Icons.view_day, 'Modalità Webtoon'),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption(ReadingMode mode, IconData icon, String label) {
    final isSelected = _readingMode == mode;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppTheme.primaryColor : Colors.white70),
      title: Text(label, style: TextStyle(
        color: isSelected ? AppTheme.primaryColor : Colors.white,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      )),
      trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primaryColor) : null,
      onTap: () {
        setState(() => _readingMode = mode);
        ref.read(playerSettingsProvider.notifier).setReadingMode(mode);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildReaderContent() {
    switch (_readingMode) {
      case ReadingMode.verticalScroll:
        return _buildVerticalReader();
      case ReadingMode.horizontalSwipe:
        return _buildHorizontalReader();
      case ReadingMode.webtoon:
        return _buildWebtoonReader();
    }
  }

  Widget _buildVerticalReader() {
    return InteractiveViewer(
      transformationController: _transformController,
      minScale: 1.0,
      maxScale: 4.0,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _loadedPages.length + (_isLoadingNextChapter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _loadedPages.length) {
            return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator(color: Colors.grey)),
            );
          }
          return _buildPageImage(index);
        },
      ),
    );
  }

  Widget _buildHorizontalReader() {
    return PageView.builder(
      controller: _pageController,
      itemCount: _loadedPages.length,
      onPageChanged: (index) {
        setState(() => _currentPageIndex = index);
        // Preload adjacent pages
        _preloadPages(index);
      },
      itemBuilder: (context, index) {
        return InteractiveViewer(
          transformationController: index == _currentPageIndex
              ? _transformController
              : TransformationController(),
          minScale: 1.0,
          maxScale: 4.0,
          child: Center(
            child: _buildPageImage(index, fit: BoxFit.contain),
          ),
        );
      },
    );
  }

  Widget _buildWebtoonReader() {
    return InteractiveViewer(
      transformationController: _transformController,
      minScale: 1.0,
      maxScale: 4.0,
      child: ListView.builder(
        controller: _scrollController,
        cacheExtent: 2000,
        itemCount: _loadedPages.length + (_isLoadingNextChapter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _loadedPages.length) {
            return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator(color: Colors.grey)),
            );
          }
          return _buildPageImage(index, spacing: false);
        },
      ),
    );
  }

  Widget _buildPageImage(int index, {BoxFit fit = BoxFit.fitWidth, bool spacing = true}) {
    return Padding(
      padding: spacing ? const EdgeInsets.only(bottom: 2) : EdgeInsets.zero,
      child: CachedNetworkImage(
        imageUrl: ImageUtils.getProxiedUrl(_loadedPages[index], headers: {
          'Referer': ImageUtils.getRefererForSource(
              _getSourceFromId(_currentChapter?.id ?? widget.chapterId)),
        }),
        fit: fit,
        placeholder: (context, url) => const SizedBox(
          height: 400,
          child: Center(child: CircularProgressIndicator(color: Colors.grey)),
        ),
        errorWidget: (context, url, _) => const SizedBox(
          height: 300,
          child: Center(child: Icon(Icons.broken_image, color: Colors.white)),
        ),
      ),
    );
  }

  void _preloadPages(int currentIndex) {
    for (int i = 1; i <= 2; i++) {
      final nextIndex = currentIndex + i;
      if (nextIndex < _loadedPages.length) {
        precacheImage(
          CachedNetworkImageProvider(
            ImageUtils.getProxiedUrl(_loadedPages[nextIndex], headers: {
              'Referer': ImageUtils.getRefererForSource(
                  _getSourceFromId(_currentChapter?.id ?? widget.chapterId)),
            }),
          ),
          context,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mangaAsync = ref.watch(mangaDetailsProvider(widget.mangaId));

    return mangaAsync.when(
      data: (manga) {
        final chaptersAsync = ref.watch(mangaChaptersProvider(
          ChapterListRequest(
            mangaId: widget.mangaId,
            title: manga.title,
            titleEnglish: manga.titleEnglish,
            preferredSource: widget.preferredSource,
          ),
        ));

        return chaptersAsync.when(
          data: (chapters) {
            if (chapters.isEmpty) {
              return Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                body: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline, color: Colors.white, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'Nessun capitolo trovato per questo manga su MangaDex.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            _allChapters = List.from(chapters)
              ..sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));

            // Initial load
            if (_loadedPages.isEmpty && !_isLoadingNextChapter) {
              final startChapter = _allChapters.firstWhere(
                (c) => c.id == widget.chapterId,
                orElse: () => _allChapters.first,
              );

              Future.microtask(() async {
                if (_loadedPages.isNotEmpty || !mounted) return;
                setState(() => _isLoadingNextChapter = true);
                try {
                  final pages = await ref.read(chapterPagesProvider(
                    ChapterRequest(mangaId: widget.mangaId, chapterId: startChapter.id),
                  ).future);
                  if (mounted) {
                    setState(() {
                      _loadedPages.addAll(pages);
                      _loadedChapters.add(startChapter);
                      _currentChapter = startChapter;
                      _isLoadingNextChapter = false;
                    });
                  }
                } catch (e) {
                  if (mounted) setState(() => _isLoadingNextChapter = false);
                }
              });

              return Scaffold(
                backgroundColor: Colors.black,
                body: Center(child: AppLoader()),
              );
            }

            // Reader content with night mode filter
            Widget readerContent = _buildReaderContent();
            if (_nightMode) {
              readerContent = ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  1.0, 0.0, 0.0, 0.0, 0.0,
                  0.0, 0.9, 0.0, 0.0, 0.0,
                  0.0, 0.0, 0.7, 0.0, 0.0,
                  0.0, 0.0, 0.0, 1.0, 0.0,
                ]),
                child: readerContent,
              );
            }

            return Scaffold(
              backgroundColor: Colors.black,
              body: GestureDetector(
                onTap: () {
                  setState(() => _showControls = !_showControls);
                  if (_showControls) {
                    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                  } else {
                    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                  }
                },
                onDoubleTapDown: (details) => _handleDoubleTapZoom(details),
                onDoubleTap: () {},
                child: Stack(
                  children: [
                    // Reader content
                    readerContent,

                    // Page indicator
                    if (_loadedPages.isNotEmpty)
                      Positioned(
                        bottom: _showControls ? 60 : 16,
                        right: 16,
                        child: AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${_currentPageIndex + 1} / ${_loadedPages.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      ),

                    // Top controls
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      top: _showControls ? 0 : -120,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black.withOpacity(0.7),
                        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            Expanded(
                              child: Text(
                                _currentChapter?.title ?? 'Lettura...',
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Night mode toggle
                            IconButton(
                              icon: Icon(
                                _nightMode ? Icons.nightlight : Icons.nightlight_outlined,
                                color: _nightMode ? Colors.amber : Colors.white,
                              ),
                              onPressed: () {
                                setState(() => _nightMode = !_nightMode);
                                ref.read(playerSettingsProvider.notifier).setNightModeFilter(_nightMode);
                              },
                              tooltip: 'Modalità notturna',
                            ),
                            // Reading mode selector
                            IconButton(
                              icon: Icon(
                                _readingMode == ReadingMode.verticalScroll
                                    ? Icons.swap_vert
                                    : _readingMode == ReadingMode.horizontalSwipe
                                        ? Icons.swap_horiz
                                        : Icons.view_day,
                                color: Colors.white,
                              ),
                              onPressed: _showReadingModeSelector,
                              tooltip: 'Modalità lettura',
                            ),
                            // Chapter list
                            IconButton(
                              icon: const Icon(Icons.list, color: Colors.white),
                              onPressed: _showChapterDrawer,
                              tooltip: 'Lista capitoli',
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom chapter navigation
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      bottom: _showControls ? 0 : -60,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black.withOpacity(0.7),
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).padding.bottom,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                if (_allChapters.isEmpty || _currentChapter == null) return;
                                final idx = _allChapters.indexWhere((c) => c.id == _currentChapter!.id);
                                if (idx > 0) _navigateToChapter(_allChapters[idx - 1]);
                              },
                              icon: const Icon(Icons.chevron_left, color: Colors.white),
                              label: const Text('Precedente', style: TextStyle(color: Colors.white)),
                            ),
                            Text(
                              'Cap. ${_currentChapter?.number ?? '?'}',
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                if (_allChapters.isEmpty || _currentChapter == null) return;
                                final idx = _allChapters.indexWhere((c) => c.id == _currentChapter!.id);
                                if (idx < _allChapters.length - 1) _navigateToChapter(_allChapters[idx + 1]);
                              },
                              icon: const Icon(Icons.chevron_right, color: Colors.white),
                              label: const Text('Successivo', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: AppLoader()),
          ),
          error: (err, _) => Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text('Errore: $err', style: const TextStyle(color: Colors.white)),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: AppLoader()),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('Errore: $err', style: const TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}
