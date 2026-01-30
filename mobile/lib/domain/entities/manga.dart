/// Manga entity representing a manga from various APIs (Jikan, MangaHook, MangaDex)
class Manga {
  final String id;
  final String title;
  final String? titleEnglish;
  final String? titleJapanese;
  final String? coverUrl;
  final String? synopsis;
  final List<String> authors;
  final List<String> genres;
  final MangaStatus status;
  final double? score;
  final int? chapters;
  final int? volumes;
  final int? year;
  final String? source; // Which API this came from

  const Manga({
    required this.id,
    required this.title,
    this.titleEnglish,
    this.titleJapanese,
    this.coverUrl,
    this.synopsis,
    this.authors = const [],
    this.genres = const [],
    this.status = MangaStatus.unknown,
    this.score,
    this.chapters,
    this.volumes,
    this.year,
    this.source,
  });

  factory Manga.fromJikanJson(Map<String, dynamic> json) {
    // Handle both raw Jikan format and backend transformed DTO format
    // Backend returns: malId (int), imageUrl, authors: string[], genres: string[]
    // Raw Jikan returns: mal_id (int), images.jpg.large_image_url, authors: [{name:...}], genres: [{name:...}]

    final malId = json['malId'] ?? json['mal_id'];

    // Parse authors - can be List<String> or List<{name: string}>
    List<String> authors = [];
    final authorsData = json['authors'];
    if (authorsData is List) {
      for (var a in authorsData) {
        if (a is String) {
          authors.add(a);
        } else if (a is Map) {
          final name = a['name']?.toString();
          if (name != null && name.isNotEmpty) authors.add(name);
        }
      }
    }

    // Parse genres - can be List<String> or List<{name: string}>
    List<String> genres = [];
    final genresData = json['genres'];
    if (genresData is List) {
      for (var g in genresData) {
        if (g is String) {
          genres.add(g);
        } else if (g is Map) {
          final name = g['name']?.toString();
          if (name != null && name.isNotEmpty) genres.add(name);
        }
      }
    }

    // Parse cover URL - can be imageUrl (transformed) or images.jpg.large_image_url (raw)
    String? coverUrl = json['imageUrl']?.toString();
    if (coverUrl == null || coverUrl.isEmpty) {
      coverUrl = json['images']?['jpg']?['large_image_url'] ??
          json['images']?['jpg']?['image_url'];
    }

    return Manga(
      id: malId?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      titleEnglish:
          json['titleEnglish']?.toString() ?? json['title_english']?.toString(),
      titleJapanese: json['titleJapanese']?.toString() ??
          json['title_japanese']?.toString(),
      coverUrl: coverUrl,
      synopsis: json['synopsis']?.toString(),
      authors: authors,
      genres: genres,
      status: _parseStatus(json['status']?.toString()),
      score: (json['score'] as num?)?.toDouble(),
      chapters: json['chapters'] as int?,
      volumes: json['volumes'] as int?,
      year:
          json['year'] as int? ?? json['published']?['prop']?['from']?['year'],
      source: 'jikan',
    );
  }

  factory Manga.fromMangaHookJson(Map<String, dynamic> json) {
    return Manga(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? json['name'] ?? '',
      coverUrl: json['image'] ?? json['cover'],
      synopsis: json['description'],
      authors: json['author'] != null ? [json['author'].toString()] : [],
      genres: (json['genres'] as List<dynamic>?)
              ?.map((g) => g.toString())
              .toList() ??
          [],
      status: _parseStatus(json['status']),
      chapters: int.tryParse(
          json['chapter']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? ''),
      source: 'mangahook',
    );
  }

  factory Manga.fromMangaDexJson(Map<String, dynamic> json) {
    // Handle both Consumet results and detailed info
    final id = json['id']?.toString() ?? json['mangadexId']?.toString() ?? '';
    final title = json['title']?.toString() ?? '';

    // Safely parse English title from various possible formats
    String? titleEnglish = json['titleEnglish']?.toString();
    if (titleEnglish == null || titleEnglish.isEmpty) {
      final altTitles = json['altTitles'];
      if (altTitles is Map) {
        titleEnglish = altTitles['en']?.toString();
      } else if (altTitles is List && altTitles.isNotEmpty) {
        // If it's a list (like in raw MangaDex), it might be [{ "en": "..." }]
        for (var alt in altTitles) {
          if (alt is Map && alt.containsKey('en')) {
            titleEnglish = alt['en']?.toString();
            break;
          }
        }
      }
    }

    return Manga(
      id: id,
      title: title,
      titleEnglish: titleEnglish,
      synopsis: json['description']?.toString(),
      coverUrl: json['coverImage']?.toString() ?? json['image']?.toString(),
      authors: (json['authors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      genres: (json['genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: _parseStatus(json['status']?.toString()),
      score: (json['rating'] as num?)?.toDouble(),
      year: (json['year'] as num?)?.toInt(),
      source: 'mangadex',
    );
  }

  static MangaStatus _parseStatus(String? status) {
    if (status == null) return MangaStatus.unknown;
    final lower = status.toLowerCase();
    if (lower.contains('ongoing') || lower.contains('publishing')) {
      return MangaStatus.ongoing;
    } else if (lower.contains('completed') || lower.contains('finished')) {
      return MangaStatus.completed;
    } else if (lower.contains('hiatus')) {
      return MangaStatus.hiatus;
    }
    return MangaStatus.unknown;
  }

  String get statusText {
    switch (status) {
      case MangaStatus.ongoing:
        return 'In corso';
      case MangaStatus.completed:
        return 'Completato';
      case MangaStatus.hiatus:
        return 'In pausa';
      case MangaStatus.unknown:
        return 'Sconosciuto';
    }
  }
}

enum MangaStatus {
  ongoing,
  completed,
  hiatus,
  unknown,
}
