import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/providers/manga_provider.dart';

class MangaReaderScreen extends ConsumerStatefulWidget {
  final String mangaId;
  final String chapterId;

  const MangaReaderScreen({
    super.key,
    required this.mangaId,
    required this.chapterId,
  });

  @override
  ConsumerState<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends ConsumerState<MangaReaderScreen> {
  bool _showControls = true;
  final ScrollController _scrollController = ScrollController();
  final List<String> _loadedPages = [];
  final List<MangaChapter> _loadedChapters = [];
  bool _isLoadingNextChapter = false;

  // Track current reading state
  MangaChapter? _currentChapter;
  List<MangaChapter> _allChapters = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadedPages.isEmpty) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 500 &&
        !_isLoadingNextChapter) {
      _loadNextChapter();
    }
  }

  Future<void> _loadNextChapter() async {
    if (_allChapters.isEmpty ||
        _currentChapter == null ||
        _isLoadingNextChapter) return;

    final currentIndex =
        _allChapters.indexWhere((c) => c.id == _currentChapter!.id);
    if (currentIndex == -1 || currentIndex >= _allChapters.length - 1) return;

    final nextChapter = _allChapters[currentIndex + 1];

    if (_loadedChapters.any((c) => c.id == nextChapter.id)) return;

    setState(() {
      _isLoadingNextChapter = true;
    });

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
      if (mounted) {
        setState(() => _isLoadingNextChapter = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Fetch manga details to get accurate title/ID for Jikan-sourced manga
    final mangaAsync = ref.watch(mangaDetailsProvider(widget.mangaId));

    return mangaAsync.when(
      data: (manga) {
        // 2. Fetch all chapters first to allow navigation
        final chaptersAsync = ref.watch(mangaChaptersProvider(
          ChapterListRequest(
            mangaId: widget.mangaId,
            title: manga.title,
            titleEnglish: manga.titleEnglish,
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
                    padding: EdgeInsets.all(24.0),
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

            // Sort chapters by number ascending to ensure correct order
            _allChapters = List.from(chapters)
              ..sort((a, b) => (a.number ?? 0).compareTo(b.number ?? 0));

            // Initial Load Logic
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
                          ChapterRequest(
                              mangaId: widget.mangaId,
                              chapterId: startChapter.id))
                      .future);
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

              return const Scaffold(
                backgroundColor: Colors.black,
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return Scaffold(
              backgroundColor: Colors.black,
              body: GestureDetector(
                onTap: () {
                  setState(() => _showControls = !_showControls);
                  if (_showControls) {
                    SystemChrome.setEnabledSystemUIMode(
                        SystemUiMode.edgeToEdge);
                  } else {
                    SystemChrome.setEnabledSystemUIMode(
                        SystemUiMode.immersiveSticky);
                  }
                },
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      itemCount:
                          _loadedPages.length + (_isLoadingNextChapter ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _loadedPages.length) {
                          return const SizedBox(
                              height: 100,
                              child:
                                  Center(child: CircularProgressIndicator()));
                        }

                        return CachedNetworkImage(
                          imageUrl: _loadedPages[index],
                          fit: BoxFit.fitWidth,
                          placeholder: (context, url) => const SizedBox(
                            height: 400,
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: Colors.grey)),
                          ),
                          errorWidget: (context, url, _) => const SizedBox(
                            height: 300,
                            child: Center(
                                child: Icon(Icons.broken_image,
                                    color: Colors.white)),
                          ),
                        );
                      },
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      top: _showControls ? 0 : -100,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black.withOpacity(0.7),
                        padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top),
                        child: AppBar(
                          backgroundColor: Colors.transparent,
                          title: Text(_currentChapter?.title ?? 'Reading...'),
                          leading: IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'Errore nel caricamento dei capitoli: $err',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            'Errore nel caricamento dei dettagli manga: $err',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
