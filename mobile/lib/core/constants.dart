class AppConstants {
  AppConstants._();

  // API Configuration
  // Use localhost for Flutter web development
  // static const String apiBaseUrl = 'http://localhost:3010';
  // static const String consumetBaseUrl = 'http://localhost:3004';

  // For physical device testing, use your LAN IP:
  // For physical device testing, use your LAN IP:
  // static const String apiBaseUrl = 'http://192.168.191.73:3005';
  // static const String consumetBaseUrl = 'http://192.168.191.73:3004';

  static const String apiBaseUrl = 'http://localhost:3005';
  static const String consumetBaseUrl = 'http://localhost:3004';

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String userDataKey = 'user_data';
  static const String onboardingCompleteKey = 'onboarding_complete';

  // API Endpoints
  static const String authBase = '/auth';
  static const String authLogin = '/auth/login';
  static const String authRegister = '/auth/register';
  static const String authProfile = '/auth/profile';

  static const String animeList = '/jikan/anime/search';
  static const String animeDetails = '/jikan/anime'; // Will append /:id
  static const String jikanSchedules = '/jikan/schedules';
  static const String animeGenres = '/jikan/anime/genres';
  static const String animeNewReleases = '/anime/new-releases';
  static const String animeTopRated = '/anime/top-rated';
  static const String animeAiring = '/anime/top-rated';
  static const String animeClassics = '/anime/top-rated';

  static const String usersProfile = '/users/profile';
  static const String usersWatchlist = '/users/watchlist';
  static const String usersHistory = '/users/history';
  static const String usersContinueWatching = '/users/continue-watching';
  static const String usersProgress = '/users/progress';
  static const String usersPreferences = '/users/preferences';

  static const String aiRecommend = '/ai/recommend';

  // Manga API Endpoints
  static const String jikanMangaSearch = '/jikan/manga/search';
  static const String jikanMangaTop = '/jikan/manga/top';
  static const String jikanMangaGenres = '/jikan/manga/genres';
  static const String mangahookMangaList = '/mangahook/mangaList';

  // MangaDex
  static const String mangadexSearch = '/mangadex/manga/search';
  static const String mangadexChapterPages = '/mangadex/chapter';
  static const String mangahookMangaSearch = '/mangahook/manga/search';
  static const String mangadexHealth = '/mangadex/health';

  static const String notificationsSettings = '/notifications/settings';
  static const String notificationsRegisterToken =
      '/notifications/register-token';

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Pagination
  static const int defaultPageSize = 20;
}
