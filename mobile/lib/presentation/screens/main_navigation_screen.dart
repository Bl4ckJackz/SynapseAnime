import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/home_screen.dart';
import '../screens/search_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/movies_tv_home_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/currently_watching_screen.dart';
import '../screens/watch_history_screen.dart';
import '../screens/manga_home_screen.dart';
import 'local_library_screen.dart';
import '../widgets/animated_bottom_nav_bar.dart';
import '../widgets/download_manager_widget.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const MangaHomeScreen(),
    const CurrentlyWatchingScreen(),
    const WatchHistoryScreen(),
    const LocalLibraryScreen(),
    const MoviesTvHomeScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          // Floating download manager
          const DownloadManagerWidget(),
        ],
      ),
      bottomNavigationBar: AnimatedBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
