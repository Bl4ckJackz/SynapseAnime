import 'package:equatable/equatable.dart';

class CastMember extends Equatable {
  final String name;
  final String? character;
  final String? profilePath;

  const CastMember({
    required this.name,
    this.character,
    this.profilePath,
  });

  String? get profileUrl {
    if (profilePath == null) return null;
    if (profilePath!.startsWith('http')) return profilePath;
    return 'https://image.tmdb.org/t/p/w185$profilePath';
  }

  factory CastMember.fromJson(Map<String, dynamic> json) {
    String? profilePath = json['profile_path']?.toString() ??
        json['profilePath']?.toString();
    if (profilePath == null && json['profileUrl'] != null) {
      profilePath = json['profileUrl'].toString();
    }
    return CastMember(
      name: json['name']?.toString() ?? '',
      character: json['character']?.toString(),
      profilePath: profilePath,
    );
  }

  @override
  List<Object?> get props => [name, character, profilePath];
}

class TvEpisode extends Equatable {
  final int id;
  final int episodeNumber;
  final int seasonNumber;
  final String name;
  final String? overview;
  final String? stillPath;
  final String? airDate;
  final int? runtime;
  final double voteAverage;

  const TvEpisode({
    required this.id,
    required this.episodeNumber,
    required this.seasonNumber,
    required this.name,
    this.overview,
    this.stillPath,
    this.airDate,
    this.runtime,
    this.voteAverage = 0.0,
  });

  String? get stillUrl {
    if (stillPath == null) return null;
    if (stillPath!.startsWith('http')) return stillPath;
    return 'https://image.tmdb.org/t/p/w300$stillPath';
  }

  factory TvEpisode.fromJson(Map<String, dynamic> json) {
    return TvEpisode(
      id: json['id'] as int? ?? 0,
      episodeNumber: json['episode_number'] as int? ??
          json['episodeNumber'] as int? ??
          0,
      seasonNumber: json['season_number'] as int? ??
          json['seasonNumber'] as int? ??
          0,
      name: json['name']?.toString() ?? '',
      overview: json['overview']?.toString(),
      stillPath: json['still_path']?.toString() ??
          json['stillPath']?.toString() ??
          json['stillUrl']?.toString(),
      airDate: json['air_date']?.toString() ??
          json['airDate']?.toString(),
      runtime: json['runtime'] as int?,
      voteAverage: (json['vote_average'] ?? json['voteAverage'] ?? json['rating'] ?? 0.0) is num
          ? (json['vote_average'] ?? json['voteAverage'] ?? json['rating'] ?? 0.0 as num)
              .toDouble()
          : double.tryParse(
                  (json['vote_average'] ?? json['voteAverage'] ?? json['rating'] ?? '0')
                      .toString()) ??
              0.0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        episodeNumber,
        seasonNumber,
        name,
        overview,
        stillPath,
        airDate,
        runtime,
        voteAverage,
      ];
}

class TvSeason extends Equatable {
  final int id;
  final int seasonNumber;
  final String name;
  final String? overview;
  final String? posterPath;
  final int episodeCount;
  final String? airDate;
  final List<TvEpisode> episodes;

  const TvSeason({
    required this.id,
    required this.seasonNumber,
    required this.name,
    this.overview,
    this.posterPath,
    this.episodeCount = 0,
    this.airDate,
    this.episodes = const [],
  });

  String? get posterUrl {
    if (posterPath == null) return null;
    if (posterPath!.startsWith('http')) return posterPath;
    return 'https://image.tmdb.org/t/p/w300$posterPath';
  }

  factory TvSeason.fromJson(Map<String, dynamic> json) {
    List<TvEpisode> episodes = [];
    if (json['episodes'] != null && json['episodes'] is List) {
      episodes = (json['episodes'] as List)
          .map((e) => TvEpisode.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return TvSeason(
      id: json['id'] as int? ?? 0,
      seasonNumber: json['season_number'] as int? ??
          json['seasonNumber'] as int? ??
          0,
      name: json['name']?.toString() ?? '',
      overview: json['overview']?.toString(),
      posterPath: json['poster_path']?.toString() ??
          json['posterPath']?.toString() ??
          json['posterUrl']?.toString(),
      episodeCount: json['episode_count'] as int? ??
          json['episodeCount'] as int? ??
          0,
      airDate: json['air_date']?.toString() ??
          json['airDate']?.toString(),
      episodes: episodes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        seasonNumber,
        name,
        overview,
        posterPath,
        episodeCount,
        airDate,
      ];
}

class TvShow extends Equatable {
  final int id;
  final String name;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final String? firstAirDate;
  final List<String> genres;
  final int numberOfSeasons;
  final int numberOfEpisodes;
  final List<TvSeason> seasons;
  final List<CastMember> cast;
  final List<TvShow> similar;
  final String? status;

  const TvShow({
    required this.id,
    required this.name,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.voteAverage = 0.0,
    this.firstAirDate,
    this.genres = const [],
    this.numberOfSeasons = 0,
    this.numberOfEpisodes = 0,
    this.seasons = const [],
    this.cast = const [],
    this.similar = const [],
    this.status,
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
      firstAirDate != null && firstAirDate!.length >= 4
          ? firstAirDate!.substring(0, 4)
          : null;

  factory TvShow.fromJson(Map<String, dynamic> json) {
    // Parse genres
    List<String> genres = [];
    if (json['genres'] != null && json['genres'] is List) {
      genres = (json['genres'] as List).map((g) {
        if (g is String) return g;
        if (g is Map) return (g['name'] ?? '').toString();
        return g.toString();
      }).toList();
    }

    // Parse seasons
    List<TvSeason> seasons = [];
    if (json['seasons'] != null && json['seasons'] is List) {
      seasons = (json['seasons'] as List)
          .map((e) => TvSeason.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Parse cast
    List<CastMember> cast = [];
    if (json['cast'] != null && json['cast'] is List) {
      cast = (json['cast'] as List)
          .map((e) => CastMember.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Parse similar
    List<TvShow> similar = [];
    if (json['similar'] != null && json['similar'] is List) {
      similar = (json['similar'] as List)
          .map((e) => TvShow.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    String? posterPath = json['poster_path']?.toString() ??
        json['posterPath']?.toString();
    if (posterPath == null && json['posterUrl'] != null) {
      posterPath = json['posterUrl'].toString();
    }

    String? backdropPath = json['backdrop_path']?.toString() ??
        json['backdropPath']?.toString();
    if (backdropPath == null && json['backdropUrl'] != null) {
      backdropPath = json['backdropUrl'].toString();
    }

    return TvShow(
      id: json['id'] as int? ?? 0,
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      overview: json['overview']?.toString() ??
          json['description']?.toString(),
      posterPath: posterPath,
      backdropPath: backdropPath,
      voteAverage: (json['vote_average'] ?? json['voteAverage'] ?? json['rating'] ?? 0.0) is num
          ? (json['vote_average'] ?? json['voteAverage'] ?? json['rating'] ?? 0.0 as num)
              .toDouble()
          : double.tryParse(
                  (json['vote_average'] ?? json['voteAverage'] ?? json['rating'] ?? '0')
                      .toString()) ??
              0.0,
      firstAirDate: json['first_air_date']?.toString() ??
          json['firstAirDate']?.toString(),
      genres: genres,
      numberOfSeasons: json['number_of_seasons'] as int? ??
          json['numberOfSeasons'] as int? ??
          0,
      numberOfEpisodes: json['number_of_episodes'] as int? ??
          json['numberOfEpisodes'] as int? ??
          0,
      seasons: seasons,
      cast: cast,
      similar: similar,
      status: json['status']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        overview,
        posterPath,
        backdropPath,
        voteAverage,
        firstAirDate,
        genres,
        numberOfSeasons,
        numberOfEpisodes,
        status,
      ];
}
