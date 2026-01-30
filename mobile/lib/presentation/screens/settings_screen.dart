import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../domain/providers/notification_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationSettingsProvider.notifier).loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader(context, 'Notifiche'),
                SwitchListTile(
                  title: const Text('Abilita notifiche push'),
                  subtitle: const Text('Ricevi aggiornamenti sui nuovi episodi'),
                  value: state.globalEnabled,
                  activeThumbColor: AppTheme.primaryColor,
                  onChanged: (value) {
                    ref
                        .read(notificationSettingsProvider.notifier)
                        .updateGlobal(value);
                  },
                ),
                if (!state.globalEnabled)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Le notifiche sono disabilitate globalmente. Attivale per gestire le singole serie.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.errorColor,
                          ),
                    ),
                  ),
                const Divider(),
                _buildSectionHeader(context, 'Account'),
                ListTile(
                  leading: const Icon(Icons.source),
                  title: const Text('Sorgente Anime'),
                  subtitle: const Text('Demo Database'), // TODO: Fetch from API
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showSourceSelectionDialog(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Profilo'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // TODO: Navigate to profile edit
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Lingua preferita'),
                  subtitle: const Text('Italiano'),
                  onTap: () {},
                ),
                const Divider(),
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Versione App'),
                  subtitle: Text('1.0.0'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: AppTheme.errorColor,
                      elevation: 0,
                      side: const BorderSide(color: AppTheme.errorColor),
                    ),
                    onPressed: () {
                      // Logout logic handled in home usually, or add here
                      Navigator.pop(context);
                    },
                    child: const Text('Esci'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  void _showSourceSelectionDialog(BuildContext context) {
    // Mock sources list (in real implementation, fetch from ref.read(animeRepositoryProvider).getSources())
    final sources = [
      {'id': 'default_db', 'name': 'Demo Database (Mock)'},
      {'id': 'local_files', 'name': 'Locale (Server Files)'},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleziona Sorgente'),
        backgroundColor: AppTheme.cardColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: sources.map((source) => ListTile(
            title: Text(source['name']!),
            onTap: () async {
              // TODO: Call API to switch source
              // await ref.read(animeRepositoryProvider).setSource(source['id']!);
              Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sorgente cambiata in: ${source['name']}')),
                );
              }
            },
          )).toList(),
        ),
      ),
    );
  }
}
