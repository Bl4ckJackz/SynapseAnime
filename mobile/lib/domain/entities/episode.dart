import 'package:equatable/equatable.dart';

class Episode extends Equatable {
  final String id;
  final String animeId;
  final int number;
  final String title;
  final int duration; // in seconds
  final String? thumbnail;
  final String streamUrl;
  final int? season; // Season number for grouping

  const Episode({
    required this.id,
    required this.animeId,
    required this.number,
    required this.title,
    required this.duration,
    this.thumbnail,
    required this.streamUrl,
    this.season,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id'] as String,
      animeId: json['animeId'] as String,
      number: json['number'] as int,
      title: json['title'] as String,
      duration: json['duration'] as int,
      thumbnail: json['thumbnail'] as String?,
      streamUrl: json['streamUrl'] as String,
      season: json['season'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'animeId': animeId,
      'number': number,
      'title': title,
      'duration': duration,
      'thumbnail': thumbnail,
      'streamUrl': streamUrl,
      'season': season,
    };
  }

  Episode copyWith({
    String? id,
    String? animeId,
    int? number,
    String? title,
    int? duration,
    String? thumbnail,
    String? streamUrl,
    int? season,
  }) {
    return Episode(
      id: id ?? this.id,
      animeId: animeId ?? this.animeId,
      number: number ?? this.number,
      title: title ?? this.title,
      duration: duration ?? this.duration,
      thumbnail: thumbnail ?? this.thumbnail,
      streamUrl: streamUrl ?? this.streamUrl,
      season: season ?? this.season,
    );
  }

  String get durationFormatted {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes}m ${seconds}s';
  }

  @override
  List<Object?> get props =>
      [id, animeId, number, title, duration, thumbnail, streamUrl, season];
}
