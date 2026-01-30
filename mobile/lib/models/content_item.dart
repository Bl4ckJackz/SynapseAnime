// lib/models/content_item.dart
class ContentItem {
  final String id;
  final String title;
  final String imageUrl;
  final dynamic type;
  final double progress;
  final double rating;
  final int year;

  ContentItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.type,
    this.progress = 0.0,
    required this.rating,
    required this.year,
  });
}