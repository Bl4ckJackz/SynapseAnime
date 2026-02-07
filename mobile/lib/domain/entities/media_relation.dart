import 'package:equatable/equatable.dart';

class MediaRelation extends Equatable {
  final String relationType; // e.g., "Sequel", "Prequel", "Adaptation"
  final List<MediaRelationEntry> entries;

  const MediaRelation({
    required this.relationType,
    required this.entries,
  });

  factory MediaRelation.fromJson(Map<String, dynamic> json) {
    return MediaRelation(
      relationType: json['relation']?.toString() ?? 'Unknown',
      entries: (json['entry'] as List<dynamic>?)
              ?.map(
                  (e) => MediaRelationEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  List<Object?> get props => [relationType, entries];
}

class MediaRelationEntry extends Equatable {
  final String malId;
  final String type; // "anime" or "manga"
  final String title;
  final String url;

  const MediaRelationEntry({
    required this.malId,
    required this.type,
    required this.title,
    required this.url,
  });

  factory MediaRelationEntry.fromJson(Map<String, dynamic> json) {
    return MediaRelationEntry(
      malId: json['malId']?.toString() ?? json['mal_id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      title: json['name']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [malId, type, title, url];
}
