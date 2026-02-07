class SourceConfig {
  /// Toggle individual Anime sources
  static const Map<String, bool> animeSources = {
    'jikan': true,
    'animeunity': true,
    'hianime': true,
    'animekai': true,
    'animesaturn': true,
    'kickassanime': true,
    // Add other anime sources here
  };

  /// Toggle individual Manga sources
  static const Map<String, bool> mangaSources = {
    'mangaworld': true,
    'mangakatana': true,
    'mangasee': true,
    'comick': true,
    'mangadex': true,
    'mangahere': false, // Disabled: Consumet scraper broken (500 error)
    'mangapill': true,
    'asurascans': true,
    'mangareader': true,
    'mangakakalot': false,
    'weebcentral': true,
  };

  /// Check if an anime source is enabled
  static bool isAnimeSourceEnabled(String id) => animeSources[id] ?? false;

  /// Check if a manga source is enabled
  static bool isMangaSourceEnabled(String id) => mangaSources[id] ?? false;
}
