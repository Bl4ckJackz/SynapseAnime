/// Chapter entity for manga chapters
class MangaChapter {
  final String id;
  final String mangaId;
  final String title;
  final double number;
  final String? volume;
  final List<String> pages;
  final DateTime? publishedAt;
  final String? source;

  const MangaChapter({
    required this.id,
    required this.mangaId,
    required this.title,
    required this.number,
    this.volume,
    this.pages = const [],
    this.publishedAt,
    this.source,
  });

  factory MangaChapter.fromMangaHookJson(
      Map<String, dynamic> json, String mangaId) {
    // Parse chapter number from title like "Chapter 123" or just "123"
    final chapterStr = json['chapterId']?.toString() ??
        json['id']?.toString() ??
        json['chapter']?.toString() ??
        '0';
    final numberMatch = RegExp(r'[\d.]+').firstMatch(chapterStr);
    final number = double.tryParse(numberMatch?.group(0) ?? '0') ?? 0;

    return MangaChapter(
      id: json['chapterId']?.toString() ?? json['id']?.toString() ?? '',
      mangaId: mangaId,
      title: json['title']?.toString() ??
          json['name']?.toString() ??
          'Chapter ${number.toInt()}',
      number: number,
      volume: json['volume']?.toString(),
      pages: (json['images'] as List<dynamic>?)
              ?.map((img) => img.toString())
              .toList() ??
          [],
      publishedAt: json['publishedAt'] != null
          ? DateTime.tryParse(json['publishedAt'].toString())
          : null,
      source: 'mangahook',
    );
  }

  factory MangaChapter.fromMangaDexJson(
      Map<String, dynamic> json, String mangaId) {
    // Check if it's raw MangaDex response (has 'attributes') or Backend entity (flat)
    final isRaw = json.containsKey('attributes');
    final attributes =
        isRaw ? json['attributes'] as Map<String, dynamic>? ?? {} : json;

    final id = isRaw
        ? (json['id']?.toString() ??
            'unknown-${DateTime.now().millisecondsSinceEpoch}')
        : (json['mangadexChapterId']?.toString() ??
            json['id']?.toString() ??
            'unknown-${DateTime.now().millisecondsSinceEpoch}');

    final titleVal = isRaw ? attributes['title'] : json['title'];
    final title = titleVal?.toString() ?? '';

    final chapterVal = isRaw ? attributes['chapter'] : json['number'];
    final volumeVal = isRaw ? attributes['volume'] : json['volume'];
    final publishDateVal =
        isRaw ? attributes['publishAt'] : json['publishedAt'];

    return MangaChapter(
      id: id,
      mangaId: mangaId,
      title: title,
      number: double.tryParse(chapterVal?.toString() ?? '0') ?? 0,
      volume: volumeVal?.toString(),
      publishedAt: publishDateVal != null
          ? DateTime.tryParse(publishDateVal.toString())
          : null,
      source: 'mangadex',
    );
  }

  String get displayTitle {
    if (title.isNotEmpty && !title.toLowerCase().startsWith('chapter')) {
      return 'Cap. ${number.toInt()} - $title';
    }
    return 'Capitolo ${number.toInt()}';
  }

  String get volumeDisplay => volume != null ? 'Vol. $volume' : '';
}
