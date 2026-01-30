import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../presentation/screens/splash_screen.dart';
import '../presentation/screens/login_screen.dart';
import '../presentation/screens/register_screen.dart';
import '../presentation/screens/anime_detail_screen.dart';
import '../presentation/screens/player_screen.dart';
import '../presentation/screens/chat_screen.dart';
import '../presentation/screens/settings_screen.dart';
import '../presentation/screens/profile_screen.dart';
import '../presentation/screens/search_screen.dart';
import '../presentation/screens/main_navigation_screen.dart';
import '../presentation/screens/external_stream_screen.dart';
import '../presentation/screens/animation_demo_screen.dart';
import '../presentation/screens/manga_detail_screen.dart';
import '../presentation/screens/manga_reader_screen.dart';
import '../presentation/screens/source_selection_screen.dart';
import '../presentation/screens/calendar_screen.dart';

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
}

// Route provider
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: (context, state) {
      // Can add auth redirect logic here
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
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: 'home',
        builder: (context, state) => const MainNavigationScreen(),
      ),
      GoRoute(
        path: AppRoutes.animeDetail,
        name: 'animeDetail',
        builder: (context, state) {
          final animeId = state.pathParameters['id']!;
          return AnimeDetailScreen(animeId: animeId);
        },
      ),
      GoRoute(
        path: AppRoutes.player,
        name: 'player',
        builder: (context, state) {
          final animeId = state.pathParameters['animeId']!;
          final episodeId = state.pathParameters['episodeId']!;
          return PlayerScreen(animeId: animeId, episodeId: episodeId);
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
        path: AppRoutes.mangaDetail,
        name: 'mangaDetail',
        builder: (context, state) {
          final mangaId = state.pathParameters['id']!;
          return MangaDetailScreen(mangaId: mangaId);
        },
      ),
      GoRoute(
        path: AppRoutes.mangaReader,
        name: 'mangaReader',
        builder: (context, state) {
          final mangaId = state.pathParameters['mangaId']!;
          final chapterId = state.pathParameters['chapterId']!;
          return MangaReaderScreen(mangaId: mangaId, chapterId: chapterId);
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
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});
