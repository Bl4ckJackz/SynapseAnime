class AnimeSource {
  final String id;
  final String name;
  final String description;
  final bool isActive;

  AnimeSource({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
  });

  factory AnimeSource.fromJson(Map<String, dynamic> json) {
    return AnimeSource(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      isActive: json['isActive'] as bool,
    );
  }
}
