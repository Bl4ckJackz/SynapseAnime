import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/auth/presentation/screens/onboarding_screen.dart';
import '../features/anime/presentation/screens/anime_detail_screen.dart';
import '../presentation/screens/player_screen.dart';
import '../presentation/screens/chat_screen.dart';
import '../presentation/screens/settings_screen.dart';
import '../presentation/screens/profile_screen.dart';
import '../presentation/screens/watch_history_screen.dart';
import '../presentation/screens/search_screen.dart';
import '../presentation/screens/main_navigation_screen.dart';
import '../presentation/screens/external_stream_screen.dart';
import '../presentation/screens/animation_demo_screen.dart';
import '../presentation/screens/manga_detail_screen.dart';
import '../presentation/screens/manga_reader_screen.dart';
import '../presentation/screens/source_selection_screen.dart';
import '../presentation/screens/calendar_screen.dart';
import '../presentation/screens/genre_grid_screen.dart';
import '../presentation/screens/watchlist_screen.dart';
import '../presentation/screens/recent_episodes_screen.dart';
import '../presentation/screens/paginated_anime_list_screen.dart';
import '../presentation/screens/paginated_manga_list_screen.dart';
import '../presentation/screens/downloads_screen.dart';
import '../presentation/screens/currently_watching_screen.dart';
import '../presentation/screens/genre_selection_screen.dart';
import '../presentation/screens/movie_detail_screen.dart';
import '../presentation/screens/tv_show_detail_screen.dart';
import '../presentation/screens/vidsrc_player_screen.dart';
import '../domain/providers/anime_provider.dart'; // for FilterType and AnimeFilter
import '../domain/providers/manga_provider.dart'; // for MangaFilterType and MangaFilter
import 'constants.dart';

// Route names
class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const animeDetail = '/anime/:id';
  static const player = '/player/:animeId/:episodeId';
  static const chat = '/chat';
  static const settings = '/settings';
  static const mangaDetail = '/manga/:id';
  static const mangaReader = '/manga/:mangaId/chapter/:chapterId';
  static const sourceSelection = '/source-selection';
  static const calendar = '/calendar';
  static const downloads = '/downloads';
  static const intro = '/intro';
  static const watching = '/watching';
  static const movieDetail = '/movie/:id';
  static const tvShowDetail = '/tv-show/:id';
  static const vidsrcPlayer = '/vidsrc-player';

  // Routes that don't require authentication
  static const publicRoutes = ['/', '/login', '/register', '/intro'];
}

// Route provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) async {
      final currentPath = state.matchedLocation;

      // Allow access to public routes
      if (AppRoutes.publicRoutes.contains(currentPath)) {
        return null;
      }

      // Check if user has a valid token
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: AppConstants.accessTokenKey);

      // If no token, redirect to login
      if (token == null || token.isEmpty) {
        return AppRoutes.login;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        // Start at Login page (index 4 in AuthScreen)
        builder: (context, state) => const AuthScreen(initialPage: 4),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        // Start at Register page (index 5 in AuthScreen)
        builder: (context, state) => const AuthScreen(initialPage: 5),
      ),
      GoRoute(
        path: AppRoutes.intro,
        name: 'intro',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const MainNavigationScreen(),
      ),
      GoRoute(
        path: AppRoutes.animeDetail,
        name: 'animeDetail',
        pageBuilder: (context, state) {
          final animeId = state.pathParameters['id']!;
          return CustomTransitionPage(
            key: state.pageKey,
            child: AnimeDetailScreen(animeId: animeId),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.player,
        name: 'player',
        builder: (context, state) {
          final animeId = state.pathParameters['animeId']!;
          final episodeId = state.pathParameters['episodeId']!;
          final source = state.uri.queryParameters['source'];
          return PlayerScreen(
            animeId: animeId,
            episodeId: episodeId,
            source: source,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.chat,
        name: 'chat',
        builder: (context, state) => const ChatScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/external-stream',
        name: 'external-stream',
        builder: (context, state) => const ExternalStreamScreen(),
      ),
      GoRoute(
        path: '/animation-demo',
        name: 'animation-demo',
        builder: (context, state) => const AnimationDemoScreen(),
      ),
      GoRoute(
        path: '/history',
        name: 'history',
        builder: (context, state) => const WatchHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.watching,
        name: 'watching',
        builder: (context, state) => const CurrentlyWatchingScreen(),
      ),
      GoRoute(
        path: AppRoutes.mangaDetail,
        name: 'mangaDetail',
        pageBuilder: (context, state) {
          final mangaId = state.pathParameters['id']!;
          return CustomTransitionPage(
            key: state.pageKey,
            child: MangaDetailScreen(mangaId: mangaId),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.mangaReader,
        name: 'mangaReader',
        builder: (context, state) {
          final mangaId = state.pathParameters['mangaId']!;
          // URL-decode the chapter ID (was encoded to handle slashes)
          final chapterId =
              Uri.decodeComponent(state.pathParameters['chapterId']!);
          final preferredSource = state.uri.queryParameters['source'];
          return MangaReaderScreen(
            mangaId: mangaId,
            chapterId: chapterId,
            preferredSource: preferredSource,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.sourceSelection,
        name: 'sourceSelection',
        builder: (context, state) => const SourceSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.calendar,
        name: 'calendar',
        builder: (context, state) => const CalendarScreen(),
      ),
      GoRoute(
        path: '/genre/:genreName',
        name: 'genreGrid',
        builder: (context, state) {
          final genreName = state.pathParameters['genreName']!;
          return GenreGridScreen(genre: genreName);
        },
      ),
      GoRoute(
        path: '/watchlist',
        name: 'watchlist',
        builder: (context, state) => const WatchlistScreen(),
      ),
      GoRoute(
        path: '/recent-episodes',
        builder: (context, state) => const RecentEpisodesScreen(),
      ),
      GoRoute(
        path: '/anime-list',
        name: 'animeList',
        builder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? 'Anime List';
          final typeStr = state.uri.queryParameters['type'] ?? 'list';

          FilterType type = FilterType.list;
          switch (typeStr) {
            case 'newReleases':
              type = FilterType.newReleases;
              break;
            case 'topRated':
              type = FilterType.topRated;
              break;
            case 'airing':
              type = FilterType.airing;
              break;
            case 'classics':
              type = FilterType.classics;
              break;
            case 'popular':
              type = FilterType.popular;
              break;
            case 'upcoming':
              type = FilterType.upcoming;
              break;
          }

          final filter = AnimeFilter(type: type);

          // Must import PaginatedAnimeListScreen
          return PaginatedAnimeListScreen(filter: filter, title: title);
        },
      ),
      GoRoute(
        path: AppRoutes.downloads,
        name: 'downloads',
        builder: (context, state) => const DownloadsScreen(),
      ),
      GoRoute(
        path: '/manga-list',
        name: 'mangaList',
        builder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? 'Manga List';
          final typeStr = state.uri.queryParameters['type'] ?? 'top';

          MangaFilterType type = MangaFilterType.top;
          switch (typeStr) {
            case 'top':
              type = MangaFilterType.top;
              break;
            case 'trending':
              type = MangaFilterType.trending;
              break;
            case 'updated':
              type = MangaFilterType.updated;
              break;
            case 'manhwa':
              type = MangaFilterType.manhwa;
              break;
            case 'manhua':
              type = MangaFilterType.manhua;
              break;
          }

          final filter = MangaFilter(type: type, title: title);
          return PaginatedMangaListScreen(filter: filter, title: title);
        },
      ),
      GoRoute(
        path: '/genre-selection',
        name: 'genreSelection',
        builder: (context, state) => const GenreSelectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.movieDetail,
        name: 'movieDetail',
        pageBuilder: (context, state) {
          final movieId = int.parse(state.pathParameters['id']!);
          return CustomTransitionPage(
            key: state.pageKey,
            child: MovieDetailScreen(tmdbId: movieId),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.tvShowDetail,
        name: 'tvShowDetail',
        pageBuilder: (context, state) {
          final tvId = int.parse(state.pathParameters['id']!);
          return CustomTransitionPage(
            key: state.pageKey,
            child: TvShowDetailScreen(tmdbId: tvId),
            transitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(curved),
                  child: child,
                ),
              );
            },
          );
        },
      ),
      GoRoute(
        path: AppRoutes.vidsrcPlayer,
        name: 'vidsrcPlayer',
        builder: (context, state) {
          final url = state.uri.queryParameters['url'] ?? '';
          final title = state.uri.queryParameters['title'] ?? 'Player';
          return VidsrcPlayerScreen(embedUrl: url, title: title);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});
