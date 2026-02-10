import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../domain/providers/notification_provider.dart';
import '../../domain/providers/download_settings_provider.dart';
import '../../features/anime/data/repositories/anime_repository.dart';
import '../../data/repositories/manga_repository.dart';

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
                  subtitle:
                      const Text('Ricevi aggiornamenti sui nuovi episodi'),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Le notifiche sono disabilitate globalmente. Attivale per gestire le singole serie.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.errorColor,
                          ),
                    ),
                  ),
                const Divider(),
                _buildSectionHeader(context, 'Download'),
                Consumer(
                  builder: (context, ref, child) {
                    final downloadSettings =
                        ref.watch(downloadSettingsProvider);
                    return Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Scarica su server'),
                          subtitle: Text(
                            downloadSettings.destination ==
                                    DownloadDestination.server
                                ? 'I file vengono salvati sul server'
                                : 'I file vengono salvati localmente',
                          ),
                          value: downloadSettings.destination ==
                              DownloadDestination.server,
                          activeThumbColor: AppTheme.primaryColor,
                          onChanged: (value) {
                            ref
                                .read(downloadSettingsProvider.notifier)
                                .setDestination(
                                  value
                                      ? DownloadDestination.server
                                      : DownloadDestination.local,
                                );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.folder),
                          title: const Text('Cartella download'),
                          subtitle: Text(
                            downloadSettings.destination ==
                                    DownloadDestination.server
                                ? downloadSettings.serverFolderPath ??
                                    'Default server folder'
                                : downloadSettings.localFolderPath ??
                                    'Non impostata',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            _showDownloadFolderDialog(
                                context, ref, downloadSettings);
                          },
                        ),
                      ],
                    );
                  },
                ),
                const Divider(),
                _buildSectionHeader(context, 'Account'),
                ListTile(
                  leading: const Icon(Icons.movie_filter),
                  title: const Text('Sorgente Anime'),
                  subtitle: Text(ref
                          .read(animeRepositoryProvider)
                          .getActiveSource()
                          ?.toUpperCase() ??
                      'JIKAN'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showAnimeSourceSelectionDialog(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book),
                  title: const Text('Sorgente Manga'),
                  subtitle: Text(ref
                      .read(mangaRepositoryProvider)
                      .getActiveSource()
                      .toUpperCase()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _showMangaSourceSelectionDialog(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.category),
                  title: const Text('Generi Preferiti'),
                  subtitle: const Text('Personalizza i tuoi gusti'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed('genreSelection'),
                ),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Profilo'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Navigate to profile edit or just show profile
                    context.pushNamed('profile');
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

  void _showAnimeSourceSelectionDialog(BuildContext context) async {
    final repository = ref.read(animeRepositoryProvider);
    final sources = await repository.getAvailableSources();
    final activeSource = repository.getActiveSource();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleziona Sorgente Anime'),
        backgroundColor: AppTheme.cardColor,
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sources.length,
            itemBuilder: (context, index) {
              final source = sources[index];
              return ListTile(
                title: Text(source.name),
                subtitle: Text(source.description),
                leading: Radio<String>(
                  value: source.id,
                  groupValue: activeSource,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (value) async {
                    if (value != null) {
                      await repository.setActiveSource(value);
                      if (context.mounted) {
                        Navigator.pop(context);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Sorgente cambiata in: ${source.name}')),
                        );
                      }
                    }
                  },
                ),
                trailing: source.id == activeSource
                    ? const Icon(Icons.check, color: AppTheme.primaryColor)
                    : null,
                onTap: () async {
                  await repository.setActiveSource(source.id);
                  if (context.mounted) {
                    Navigator.pop(context);
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Sorgente cambiata in: ${source.name}')),
                    );
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showMangaSourceSelectionDialog(BuildContext context) async {
    final repository = ref.read(mangaRepositoryProvider);
    final sources = repository.availableSources;
    final activeSource = repository.getActiveSource();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleziona Sorgente Manga'),
        backgroundColor: AppTheme.cardColor,
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: sources.length,
            itemBuilder: (context, index) {
              final sourceId = sources[index];
              return ListTile(
                title: Text(sourceId.toUpperCase()),
                leading: Radio<String>(
                  value: sourceId,
                  groupValue: activeSource,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (value) async {
                    if (value != null) {
                      await repository.setActiveSource(value);
                      if (context.mounted) {
                        Navigator.pop(context);
                        setState(() {});
                      }
                    }
                  },
                ),
                trailing: sourceId == activeSource
                    ? const Icon(Icons.check, color: AppTheme.primaryColor)
                    : null,
                onTap: () async {
                  await repository.setActiveSource(sourceId);
                  if (context.mounted) {
                    Navigator.pop(context);
                    setState(() {});
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showDownloadFolderDialog(
    BuildContext context,
    WidgetRef ref,
    DownloadSettings settings,
  ) {
    final controller = TextEditingController(
      text: settings.destination == DownloadDestination.server
          ? settings.serverFolderPath ?? ''
          : settings.localFolderPath ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cartella Download'),
        backgroundColor: AppTheme.cardColor,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              settings.destination == DownloadDestination.server
                  ? 'Inserisci il percorso della cartella sul server:'
                  : 'Inserisci il percorso della cartella locale:',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: settings.destination == DownloadDestination.server
                    ? '/path/to/downloads'
                    : '/storage/emulated/0/Download/Anime',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            onPressed: () {
              final path = controller.text.trim();
              if (path.isNotEmpty) {
                if (settings.destination == DownloadDestination.server) {
                  ref
                      .read(downloadSettingsProvider.notifier)
                      .setServerFolderPath(path);
                } else {
                  ref
                      .read(downloadSettingsProvider.notifier)
                      .setLocalFolderPath(path);
                }
              }
              Navigator.pop(context);
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }
}
