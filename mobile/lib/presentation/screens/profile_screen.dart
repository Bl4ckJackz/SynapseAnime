import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../domain/entities/user.dart';
import '../../domain/providers/user_profile_provider.dart';
import '../../domain/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(userProfileProvider);

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
          _buildStatsCards(context),

          const SizedBox(height: 24),

          // Activity Chart
          _buildActivityChart(context),

          const SizedBox(height: 24),

          // Genre Distribution
          _buildGenreChart(context, user),

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

  Widget _buildStatsCards(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _buildStatCard(
                '12', 'Anime\nGuardati', Icons.play_circle, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatCard(
                '48', 'Episodi\nVisti', Icons.movie, Colors.green)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatCard(
                '24h', 'Tempo\nTotale', Icons.timer, Colors.orange)),
      ],
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

  Widget _buildActivityChart(BuildContext context) {
    return Card(
      color: AppTheme.cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attività Settimanale',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildBarChart('L', 0.4, Colors.blue),
                  _buildBarChart('M', 0.7, Colors.blue),
                  _buildBarChart('M', 0.3, Colors.blue),
                  _buildBarChart('G', 0.9, AppTheme.primaryColor),
                  _buildBarChart('V', 0.6, Colors.blue),
                  _buildBarChart('S', 1.0, AppTheme.primaryColor),
                  _buildBarChart('D', 0.8, AppTheme.primaryColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(String day, double height, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: 28,
          height: 80 * height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(day,
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _buildGenreChart(BuildContext context, User user) {
    final genres =
        user.preference?.preferredGenres ?? ['Action', 'Comedy', 'Drama'];
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple
    ];

    return Card(
      color: AppTheme.cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generi Preferiti',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...genres.asMap().entries.map((entry) {
              final index = entry.key;
              final genre = entry.value;
              final percentage = (100 - index * 20).clamp(20, 100).toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(genre, style: const TextStyle(fontSize: 14)),
                        Text('${percentage.toInt()}%',
                            style: TextStyle(
                                color: colors[index % colors.length])),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: colors[index % colors.length]
                            .withValues(alpha: 0.2),
                        valueColor: AlwaysStoppedAnimation(
                            colors[index % colors.length]),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              );
            }),
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
