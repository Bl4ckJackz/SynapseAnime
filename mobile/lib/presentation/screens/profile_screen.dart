import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../domain/entities/user.dart';
import '../../domain/providers/user_profile_provider.dart';
import '../../domain/providers/auth_provider.dart';
import '../../domain/providers/watch_history_provider.dart';
import '../animations/crystalize_chart_widget.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(userProfileProvider);
    final historyState = ref.watch(watchHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.pushNamed('settings'),
          ),
        ],
      ),
      body: profileState.when(
        data: (user) => _buildProfileContent(context, ref, user),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 16),
              const Text('Errore nel caricamento del profilo'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(userProfileProvider),
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(BuildContext context, WidgetRef ref, User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Profile Header Card
          _buildProfileHeader(context, ref, user),

          const SizedBox(height: 24),

          // Stats Cards Row
          _buildStatsCards(context, ref),

          const SizedBox(height: 24),

          // Charts
          _buildCharts(context, ref),

          const SizedBox(height: 24),

          // Quick Actions
          _buildQuickActions(context, ref),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, WidgetRef ref, User user) {
    return Card(
      color: AppTheme.cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withValues(alpha: 0.6),
                  ],
                ),
              ),
              child: const Icon(Icons.person, size: 40, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.nickname ?? 'Utente',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: TextStyle(color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Membro Premium',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _showEditProfileDialog(context, ref, user),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(watchHistoryProvider);

    return historyState.when(
      data: (history) {
        final uniqueAnime = history.map((e) => e.anime?.id).toSet().length;
        final totalEpisodes = history.length;
        final totalSeconds =
            history.fold(0, (sum, item) => sum + item.progressSeconds);

        String timeDisplay;
        if (totalSeconds < 3600) {
          timeDisplay = '${(totalSeconds / 60).toStringAsFixed(0)}m';
        } else {
          timeDisplay = '${(totalSeconds / 3600).toStringAsFixed(1)}h';
        }

        return Row(
          children: [
            Expanded(
                child: _buildStatCard('$uniqueAnime', 'Anime\nGuardati',
                    Icons.play_circle, Colors.blue)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard('$totalEpisodes', 'Episodi\nVisti',
                    Icons.movie, Colors.green)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard(
                    timeDisplay, 'Tempo\nTotale', Icons.timer, Colors.orange)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildCharts(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(watchHistoryProvider);

    return historyState.when(
      data: (history) {
        // Calculate Weekly Activity
        final now = DateTime.now();
        final weeklyActivity = List<double>.filled(7, 0);

        for (var item in history) {
          final diff = now.difference(item.updatedAt).inDays;
          if (diff < 7) {
            // Map weekday (1=Mon..7=Sun) to index (0..6)
            final weekdayIndex = item.updatedAt.weekday - 1;
            if (weekdayIndex >= 0 && weekdayIndex < 7) {
              weeklyActivity[weekdayIndex] += 1; // Count episodes
            }
          }
        }

        // Calculate Genre Distribution
        final genreDistribution = <String, int>{};
        for (var item in history) {
          if (item.anime != null) {
            for (var genre in item.anime!.genres) {
              genreDistribution[genre] = (genreDistribution[genre] ?? 0) + 1;
            }
          }
        }

        return CrystalizeChartWidget(
          weeklyActivity: weeklyActivity,
          genreDistribution: genreDistribution,
        );
      },
      loading: () => const SizedBox(
          height: 200, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildStatCard(
      String value, String label, IconData icon, Color color) {
    return Card(
      color: AppTheme.cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _buildActionTile(
          icon: Icons.history,
          title: 'Cronologia',
          subtitle: 'Visualizza anime guardati',
          onTap: () => context.pushNamed('history'),
        ),
        _buildActionTile(
          icon: Icons.favorite_border,
          title: 'Preferiti',
          subtitle: 'I tuoi anime preferiti',
          onTap: () {},
        ),
        _buildActionTile(
          icon: Icons.logout,
          title: 'Esci',
          subtitle: 'Disconnetti account',
          onTap: () async {
            await ref.read(authServiceProvider.notifier).logout();
            if (context.mounted) context.goNamed('login');
          },
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Card(
      color: AppTheme.cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon,
            color: isDestructive ? Colors.red : AppTheme.primaryColor),
        title: Text(title,
            style: TextStyle(color: isDestructive ? Colors.red : null)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, WidgetRef ref, User user) {
    final nicknameController = TextEditingController(text: user.nickname ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifica Profilo'),
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: nicknameController,
          decoration: const InputDecoration(
            labelText: 'Nickname',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(userProfileProvider.notifier).updateProfile(
                      username: nicknameController.text,
                    );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profilo aggiornato')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Errore: $e')),
                  );
                }
              }
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }
}
