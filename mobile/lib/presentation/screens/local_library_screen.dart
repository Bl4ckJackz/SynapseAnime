import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/api_client.dart';
import '../../domain/providers/library_settings_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LocalLibraryScreen extends ConsumerStatefulWidget {
  const LocalLibraryScreen({super.key});

  @override
  ConsumerState<LocalLibraryScreen> createState() => _LocalLibraryScreenState();
}

class _LocalLibraryScreenState extends ConsumerState<LocalLibraryScreen> {
  List<LocalAnime> _localAnimes = [];
  List<ServerAnime> _serverAnimes = [];
  bool _isLoading = false;
  String? _selectedDirectory;

  @override
  void initState() {
    super.initState();
    // Load saved settings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(librarySettingsProvider);
      if (settings.localFolderPath != null) {
        setState(() {
          _selectedDirectory = settings.localFolderPath;
        });
        _scanDirectory(settings.localFolderPath!);
      }
      if (settings.source == LibrarySource.server) {
        _loadServerLibrary();
      }
    });
  }

  Future<void> _pickDirectory() async {
    // Request storage permission on Android
    if (!kIsWeb && Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permesso di accesso ai file negato')),
          );
        }
        return;
      }
    }

    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      setState(() {
        _selectedDirectory = selectedDirectory;
      });
      ref
          .read(librarySettingsProvider.notifier)
          .setLocalFolderPath(selectedDirectory);
      _scanDirectory(selectedDirectory);
    }
  }

  Future<void> _scanDirectory(String directoryPath) async {
    setState(() {
      _isLoading = true;
      _localAnimes = [];
    });

    try {
      final dir = Directory(directoryPath);
      final List<FileSystemEntity> entities =
          await dir.list(recursive: true).toList();

      final Map<String, List<LocalEpisode>> groupedEpisodes = {};

      for (var entity in entities) {
        if (entity is File) {
          final ext = path.extension(entity.path).toLowerCase();
          if (['.mp4', '.mkv', '.avi', '.mov', '.webm'].contains(ext)) {
            final filename = path.basename(entity.path);
            final parsed = _parseFilename(filename);

            final animeTitle = parsed.title;
            final episodeNum = parsed.episode;

            if (!groupedEpisodes.containsKey(animeTitle)) {
              groupedEpisodes[animeTitle] = [];
            }

            groupedEpisodes[animeTitle]!.add(LocalEpisode(
              path: entity.path,
              filename: filename,
              number: episodeNum,
            ));
          }
        }
      }

      final List<LocalAnime> newAnimes = groupedEpisodes.entries.map((entry) {
        return LocalAnime(
          title: entry.key,
          episodes: entry.value..sort((a, b) => a.number.compareTo(b.number)),
          path: directoryPath,
        );
      }).toList();

      newAnimes.sort((a, b) => a.title.compareTo(b.title));

      setState(() {
        _localAnimes = newAnimes;
      });
    } catch (e) {
      debugPrint('Error scanning directory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante la scansione: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadServerLibrary() async {
    setState(() {
      _isLoading = true;
      _serverAnimes = [];
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/library/folder/default/videos');

      final List<dynamic> data = response.data as List<dynamic>? ?? [];

      final List<ServerAnime> animes = data.map((item) {
        final episodes = (item['episodes'] as List<dynamic>? ?? [])
            .map((ep) => ServerEpisode(
                  id: ep['id'] ?? '',
                  filename: ep['filename'] ?? '',
                  episode: ep['episode'] ?? 0,
                ))
            .toList();

        return ServerAnime(
          title: item['title'] ?? 'Unknown',
          episodes: episodes,
        );
      }).toList();

      setState(() {
        _serverAnimes = animes;
      });
    } catch (e) {
      debugPrint('Error loading server library: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore nel caricamento dal server: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  ({String title, int episode}) _parseFilename(String filename) {
    final regex =
        RegExp(r'(?:\[.*?\]\s*)?([^-]+?)\s*-\s*(\d+)', caseSensitive: false);
    final match = regex.firstMatch(filename);

    if (match != null) {
      final title = match.group(1)?.trim() ?? 'Unknown';
      final episode = int.tryParse(match.group(2) ?? '0') ?? 0;
      return (title: title, episode: episode);
    }

    return (title: filename, episode: 0);
  }

  @override
  Widget build(BuildContext context) {
    final librarySettings = ref.watch(librarySettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Libreria'),
        actions: [
          if (librarySettings.source == LibrarySource.local)
            IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: _pickDirectory,
              tooltip: 'Seleziona Cartella',
            ),
          if (librarySettings.source == LibrarySource.server)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadServerLibrary,
              tooltip: 'Aggiorna',
            ),
        ],
      ),
      body: Column(
        children: [
          // Source Selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSourceButton(
                      'Locale',
                      Icons.folder,
                      LibrarySource.local,
                      librarySettings.source == LibrarySource.local,
                    ),
                  ),
                  Expanded(
                    child: _buildSourceButton(
                      'Server',
                      Icons.cloud,
                      LibrarySource.server,
                      librarySettings.source == LibrarySource.server,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: librarySettings.source == LibrarySource.local
                ? _buildLocalBody()
                : _buildServerBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceButton(
    String label,
    IconData icon,
    LibrarySource source,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        ref.read(librarySettingsProvider.notifier).setSource(source);
        if (source == LibrarySource.server) {
          _loadServerLibrary();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_selectedDirectory == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_library_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Nessuna cartella selezionata',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickDirectory,
              icon: const Icon(Icons.folder_open),
              label: const Text('Seleziona Cartella Anime'),
            ),
          ],
        ),
      );
    }

    if (_localAnimes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Nessun video trovato in:\n$_selectedDirectory',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _localAnimes.length,
      itemBuilder: (context, index) {
        final anime = _localAnimes[index];
        return _buildLocalAnimeTile(anime);
      },
    );
  }

  Widget _buildServerBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_serverAnimes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Nessun contenuto trovato sul server',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadServerLibrary,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _serverAnimes.length,
      itemBuilder: (context, index) {
        final anime = _serverAnimes[index];
        return _buildServerAnimeTile(anime);
      },
    );
  }

  Widget _buildLocalAnimeTile(LocalAnime anime) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(anime.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${anime.episodes.length} Episodi'),
        leading: Container(
          width: 50,
          height: 70,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.movie, color: Colors.white54),
        ),
        children: anime.episodes.map((ep) {
          return ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: Text(ep.filename),
            subtitle: Text('Episodio ${ep.number}'),
            onTap: () {
              _playLocalVideo(ep.path);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildServerAnimeTile(ServerAnime anime) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Text(anime.title,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${anime.episodes.length} Episodi'),
        leading: Container(
          width: 50,
          height: 70,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.cloud, color: Colors.white54),
        ),
        children: anime.episodes.map((ep) {
          return ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: Text(ep.filename),
            subtitle: Text('Episodio ${ep.episode}'),
            onTap: () {
              _playServerVideo(ep.id);
            },
          );
        }).toList(),
      ),
    );
  }

  void _playLocalVideo(String filePath) {
    // TODO: Navigate to player with file path
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Playing: $filePath')),
    );
  }

  void _playServerVideo(String videoId) {
    // HLS stream URL
    final hlsUrl =
        '${AppConstants.apiBaseUrl}/library/stream/$videoId/playlist.m3u8';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Playing HLS: $hlsUrl')),
    );

    // TODO: Navigate to player with HLS URL
    // context.push('/player?url=$hlsUrl');
  }
}

class LocalAnime {
  final String title;
  final List<LocalEpisode> episodes;
  final String path;

  LocalAnime({required this.title, required this.episodes, required this.path});
}

class LocalEpisode {
  final String path;
  final String filename;
  final int number;

  LocalEpisode(
      {required this.path, required this.filename, required this.number});
}

class ServerAnime {
  final String title;
  final List<ServerEpisode> episodes;

  ServerAnime({required this.title, required this.episodes});
}

class ServerEpisode {
  final String id;
  final String filename;
  final int episode;

  ServerEpisode(
      {required this.id, required this.filename, required this.episode});
}
