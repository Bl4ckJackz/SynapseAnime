import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../domain/entities/manga.dart';
import '../../domain/entities/chapter.dart';
import '../../domain/providers/manga_provider.dart';

class MangaDetailScreen extends ConsumerWidget {
  final String mangaId;

  const MangaDetailScreen({super.key, required this.mangaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mangaAsync = ref.watch(mangaDetailsProvider(mangaId));

    return Scaffold(
      body: mangaAsync.when(
        data: (manga) => MangaDetailContent(manga: manga),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Errore: $err')),
      ),
    );
  }
}

class MangaDetailContent extends ConsumerStatefulWidget {
  final Manga manga;

  const MangaDetailContent({super.key, required this.manga});

  @override
  ConsumerState<MangaDetailContent> createState() => _MangaDetailContentState();
}

class _MangaDetailContentState extends ConsumerState<MangaDetailContent> {
  String? _selectedSource;
  int _selectedRangeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final chaptersAsync = ref.watch(mangaChaptersProvider(ChapterListRequest(
        mangaId: widget.manga.id,
        title: widget.manga.title,
        titleEnglish: widget.manga.titleEnglish,
        preferredSource: _selectedSource)));

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              widget.manga.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                shadows: [Shadow(color: Colors.black, blurRadius: 10)],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: widget.manga.coverUrl ?? '',
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    color: AppTheme.surfaceColor,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status and Score row
                Row(
                  children: [
                    _buildTag(
                      widget.manga.statusText,
                      widget.manga.status == MangaStatus.ongoing
                          ? Colors.green
                          : Colors.blue,
                    ),
                    if (widget.manga.year != null) ...[
                      const SizedBox(width: 8),
                      _buildTag(widget.manga.year.toString(), Colors.grey),
                    ],
                    if (widget.manga.score != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        widget.manga.score!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Authors
                if (widget.manga.authors.isNotEmpty) ...[
                  Text(
                    'Autori: ${widget.manga.authors.join(", ")}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Genres
                if (widget.manga.genres.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: widget.manga.genres
                        .map((g) => Chip(
                              label: Text(g),
                              backgroundColor: AppTheme.surfaceColor,
                              labelStyle: const TextStyle(fontSize: 12),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 16),

                // Synopsis
                Text(
                  'Trama',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.manga.synopsis ?? 'Nessuna descrizione disponibile.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                // Chapters Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Capitoli${widget.manga.chapters != null ? " (${widget.manga.chapters})" : ""}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Row(
                      children: [
                        // Source Selector
                        DropdownButton<String>(
                            value: _selectedSource,
                            hint: const Text("Auto",
                                style: TextStyle(fontSize: 12)),
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(
                                  value: null, child: Text("Auto")),
                              DropdownMenuItem(
                                  value: "mangadex", child: Text("MangaDex")),
                              DropdownMenuItem(
                                  value: "mangareader",
                                  child: Text("MangaReader")),
                              DropdownMenuItem(
                                  value: "mangakakalot",
                                  child: Text("MangaKakalot")),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedSource = val;
                              });
                            }),
                        IconButton(
                          icon: const Icon(Icons.bookmark_border),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Aggiunto alla lista di lettura'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // Chapters List
        chaptersAsync.when(
          data: (chapters) {
            if (chapters.isEmpty) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Nessun capitolo disponibile. Prova a cambiare fonte.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            // Pagination Logic
            const int pageSize = 50;
            final int totalCount = chapters.length;
            final int totalPages = (totalCount / pageSize).ceil();

            // Reset index if out of bounds (e.g. source change)
            if (_selectedRangeIndex >= totalPages && totalPages > 0) {
              // Schedule reset after build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _selectedRangeIndex = 0);
              });
            }

            // Slice chapters
            final int start = _selectedRangeIndex * pageSize;
            final int end = (start + pageSize) < totalCount
                ? (start + pageSize)
                : totalCount;

            final List<MangaChapter> displayedChapters =
                (totalPages > 0 && start < totalCount)
                    ? chapters.sublist(start, end)
                    : chapters;

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // Index 0: Pagination Controls (if needed)
                  if (index == 0) {
                    if (totalPages <= 1) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Seleziona Capitoli',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: List.generate(totalPages, (i) {
                                final isSelected = i == _selectedRangeIndex;
                                final s = i * pageSize + 1;
                                final e = (i + 1) * pageSize;
                                final label =
                                    '$s-${e > totalCount ? totalCount : e}';

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(label),
                                    selected: isSelected,
                                    onSelected: (_) =>
                                        setState(() => _selectedRangeIndex = i),
                                    selectedColor: AppTheme.accentColor,
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey,
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  }

                  // Index 1+: Chapters
                  // Adjust index by -1 because of pagination header
                  final chapterIndex = index - 1;
                  if (chapterIndex < displayedChapters.length) {
                    return _buildChapterTile(
                        context, displayedChapters[chapterIndex]);
                  }
                  return null;
                },
                // Add 1 for the pagination header
                childCount: displayedChapters.length + 1,
              ),
            );
          },
          loading: () => const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
          error: (err, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange),
                  const SizedBox(height: 8),
                  Text(
                    'Errore: $err',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildChapterTile(BuildContext context, MangaChapter chapter) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            chapter.number.toInt().toString(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
      title: Text(
        chapter.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: chapter.volumeDisplay.isNotEmpty
          ? Text(
              chapter.volumeDisplay,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            )
          : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        final sourceParam =
            _selectedSource != null ? '?source=$_selectedSource' : '';
        context.push(
            '/manga/${widget.manga.id}/chapter/${chapter.id}$sourceParam');
      },
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
