import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppTheme.backgroundColor,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.movie_filter,
                      size: 48, color: AppTheme.primaryColor),
                  const SizedBox(height: 12),
                  Text(
                    'SynapseAnime',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Home'),
            onTap: () {
              context.go('/home'); // Reset to home
            },
          ),
          ListTile(
            leading: const Icon(Icons.history_outlined),
            title: const Text('Cronologia'),
            onTap: () {
              // Assuming navigation index 2 (Manga is 1, Search removed)
              // Actually indices shifted: Home=0, Manga=1, History=2, Library=3, Chat=4, Profile=5
              // We need a way to navigate to tabs.
              // Since we use IndexedStack, standard go('/history') might not work if routes aren't set up for deep linking bottom nav.
              // Let's assume standard routes exist or we push.
              // Re-visiting MainNavigationScreen, it likely handles branches.
              // For now, let's try popUntil or go('/home') then switch index via listener?
              // Simpler: context.goNamed('home'); then maybe we need a provider to switch tab?
              // Let's use goNamed with extra parameters or just go('/path') if ShellRoute is active.

              // Safest: go to root path for that tab
              context.go('/history');
            },
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_outline),
            title: const Text('Watchlist'),
            onTap: () {
              context.push('/watchlist');
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profilo'),
            onTap: () {
              context.go('/profile');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Impostazioni'),
            onTap: () {
              // context.pushNamed('settings');
            },
          ),
        ],
      ),
    );
  }
}
