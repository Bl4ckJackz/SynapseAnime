// lib/widgets/content_row.dart
import 'package:flutter/material.dart';
import '../models/content_item.dart';
import 'content_tile.dart';

enum ContentType {
  continueWatching,
  trending,
  topPicks,
  newReleases,
  genre,
}

class ContentRow extends StatelessWidget {
  final String title;
  final ContentType contentType;
  final String? genre;

  const ContentRow({
    Key? key,
    required this.title,
    required this.contentType,
    this.genre,
  }) : super(key: key);

  List<ContentItem> _getContentItems() {
    // This would normally fetch from the provider based on content type
    // For demo purposes, returning mock data
    return List.generate(10, (index) {
      return ContentItem(
        id: 'item_$index',
        title: '$title Item ${index + 1}',
        imageUrl: 'https://placehold.co/300x450?text=${title[0]}${index + 1}',
        type: index % 3 == 0 ? ContentType.continueWatching : 
              index % 3 == 1 ? ContentType.trending : ContentType.newReleases,
        progress: index % 3 == 0 ? 0.6 : 0.0, // Simulate progress for continue watching
        rating: 8.0 + (index % 3),
        year: 2020 + (index % 4),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _getContentItems().length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = _getContentItems()[index];
              return ContentTile(contentItem: item);
            },
          ),
        ),
      ],
    );
  }
}