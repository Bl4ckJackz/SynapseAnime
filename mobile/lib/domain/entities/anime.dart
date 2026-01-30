import 'package:equatable/equatable.dart';
import 'episode.dart';

enum AnimeStatus { ongoing, completed, upcoming }

class Anime extends Equatable {
  final String id;
  final String title;
  final String? titleEnglish;
  final String? titleJapanese;
  final String? titleRomaji;
  final String description;
  final String? coverUrl;
  final List<String> genres;
  final AnimeStatus status;
  final int releaseYear;
  final double rating;
  final int totalEpisodes;
  final String? source;
  final List<Episode>? episodes;
  final String? duration;
  final DateTime? airedFrom;
  final DateTime? airedTo;

  const Anime({
    required this.id,
    required this.title,
    this.titleEnglish,
    this.titleJapanese,
    this.titleRomaji,
    required this.description,
    this.coverUrl,
    required this.genres,
    required this.status,
    required this.releaseYear,
    required this.rating,
    required this.totalEpisodes,
    this.episodes,
    this.source,
    this.duration,
    this.airedFrom,
    this.airedTo,
  });

  factory Anime.fromJson(Map<String, dynamic> json) {
    String? englishTitle =
        json['titleEnglish']?.toString() ?? json['title_english']?.toString();
    String defaultTitle = json['title']?.toString() ?? '';

    // Status Parsing
    AnimeStatus status = AnimeStatus.ongoing;
    final statusStr = json['status']?.toString().toLowerCase();
    if (statusStr == 'completed') {
      status = AnimeStatus.completed;
    } else if (statusStr == 'upcoming') {
      status = AnimeStatus.upcoming;
    }

    // Aired Dates Parsing
    DateTime? airedFrom;
    DateTime? airedTo;
    if (json['aired'] != null && json['aired'] is Map) {
      final aired = json['aired'];
      if (aired['from'] != null) {
        airedFrom = DateTime.tryParse(aired['from'].toString());
      }
      if (aired['to'] != null) {
        airedTo = DateTime.tryParse(aired['to'].toString());
      }
    }

    return Anime(
      id: json['id']?.toString() ?? '',
      // Use English title if available, otherwise default
      title: (englishTitle != null && englishTitle.isNotEmpty)
          ? englishTitle
          : defaultTitle,
      titleEnglish: englishTitle,
      titleJapanese: json['titleJapanese']?.toString() ??
          json['title_japanese']?.toString(),
      titleRomaji: defaultTitle, // Preserve original title (usually Romaji)
      description: json['description']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString(),
      genres: (json['genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: status,
      releaseYear: json['releaseYear'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalEpisodes: json['totalEpisodes'] as int? ?? 0,
      episodes: (json['episodes'] as List<dynamic>?)
          ?.map((e) => Episode.fromJson(e as Map<String, dynamic>))
          .toList(),
      source: json['source']?.toString(),
      duration: json['duration']?.toString(),
      airedFrom: airedFrom,
      airedTo: airedTo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'coverUrl': coverUrl,
      'genres': genres,
      'status': status == AnimeStatus.ongoing ? 'ongoing' : 'completed',
      'releaseYear': releaseYear,
      'rating': rating,
      'totalEpisodes': totalEpisodes,
      'source': source,
    };
  }

  String get statusText =>
      status == AnimeStatus.ongoing ? 'In corso' : 'Completato';

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        coverUrl,
        genres,
        status,
        releaseYear,
        rating,
        totalEpisodes,
      ];
}
