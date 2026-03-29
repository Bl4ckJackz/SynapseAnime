import 'package:equatable/equatable.dart';

class Movie extends Equatable {
  final int id;
  final String title;
  final String? originalTitle;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final int voteCount;
  final String? releaseDate;
  final List<int> genreIds;
  final List<String> genres;
  final int? runtime;
  final String? tagline;
  final List<Map<String, dynamic>> cast;
  final List<Movie> similar;
  final String? imdbId;

  const Movie({
    required this.id,
    required this.title,
    this.originalTitle,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.voteAverage = 0.0,
    this.voteCount = 0,
    this.releaseDate,
    this.genreIds = const [],
    this.genres = const [],
    this.runtime,
    this.tagline,
    this.cast = const [],
    this.similar = const [],
    this.imdbId,
  });

  String? get posterUrl {
    if (posterPath == null) return null;
    if (posterPath!.startsWith('http')) return posterPath;
    return 'https://image.tmdb.org/t/p/w500$posterPath';
  }

  String? get backdropUrl {
    if (backdropPath == null) return null;
    if (backdropPath!.startsWith('http')) return backdropPath;
    return 'https://image.tmdb.org/t/p/w780$backdropPath';
  }

  String? get year =>
      releaseDate != null && releaseDate!.length >= 4
          ? releaseDate!.substring(0, 4)
          : null;

  factory Movie.fromJson(Map<String, dynamic> json) {
    // Parse genres - can be list of strings or list of objects with 'name'
    List<String> genres = [];
    if (json['genres'] != null && json['genres'] is List) {
      genres = (json['genres'] as List).map((g) {
        if (g is String) return g;
        if (g is Map) return (g['name'] ?? '').toString();
        return g.toString();
      }).toList();
    }

    // Parse genre_ids
    List<int> genreIds = [];
    if (json['genre_ids'] != null && json['genre_ids'] is List) {
      genreIds = (json['genre_ids'] as List)
          .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
          .toList();
    } else if (json['genreIds'] != null && json['genreIds'] is List) {
      genreIds = (json['genreIds'] as List)
          .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
          .toList();
    }

    // Parse cast
    List<Map<String, dynamic>> cast = [];
    if (json['cast'] != null && json['cast'] is List) {
      cast = (json['cast'] as List)
          .map((e) => e is Map<String, dynamic>
              ? e
              : Map<String, dynamic>.from(e as Map))
          .toList();
    }

    // Parse similar movies
    List<Movie> similar = [];
    if (json['similar'] != null && json['similar'] is List) {
      similar = (json['similar'] as List)
          .map((e) => Movie.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Handle both full URLs (from our backend) and relative paths (from TMDB directly)
    String? posterPath = json['poster_path']?.toString() ??
        json['posterPath']?.toString();
    final posterUrl = json['posterUrl']?.toString();
    if (posterPath == null && posterUrl != null) {
      posterPath = posterUrl; // store full URL directly
    }

    String? backdropPath = json['backdrop_path']?.toString() ??
        json['backdropPath']?.toString();
    final backdropUrl = json['backdropUrl']?.toString();
    if (backdropPath == null && backdropUrl != null) {
      backdropPath = backdropUrl;
    }

    return Movie(
      id: json['id'] as int? ?? 0,
      title: json['title']?.toString() ?? '',
      originalTitle: json['original_title']?.toString() ??
          json['originalTitle']?.toString(),
      overview: json['overview']?.toString() ??
          json['description']?.toString(),
      posterPath: posterPath,
      backdropPath: backdropPath,
      voteAverage: (json['vote_average'] ?? json['voteAverage'] ?? json['rating'] ?? 0.0)
          is num
          ? (json['vote_average'] ?? json['voteAverage'] ?? json['rating'] ?? 0.0 as num)
              .toDouble()
          : double.tryParse(
                  (json['vote_average'] ?? json['voteAverage'] ?? json['rating'] ?? '0')
                      .toString()) ??
              0.0,
      voteCount: json['vote_count'] as int? ??
          json['voteCount'] as int? ??
          0,
      releaseDate: json['release_date']?.toString() ??
          json['releaseDate']?.toString(),
      genreIds: genreIds,
      genres: genres,
      runtime: json['runtime'] as int?,
      tagline: json['tagline']?.toString(),
      cast: cast,
      similar: similar,
      imdbId: json['imdb_id']?.toString() ?? json['imdbId']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        originalTitle,
        overview,
        posterPath,
        backdropPath,
        voteAverage,
        voteCount,
        releaseDate,
        genreIds,
        genres,
        runtime,
        tagline,
        imdbId,
      ];
}
