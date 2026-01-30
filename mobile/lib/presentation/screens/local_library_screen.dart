import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import '../../domain/entities/anime.dart';

class LocalLibraryScreen extends StatefulWidget {
  const LocalLibraryScreen({super.key});

  @override
  State<LocalLibraryScreen> createState() => _LocalLibraryScreenState();
}

class _LocalLibraryScreenState extends State<LocalLibraryScreen> {
  List<LocalAnime> _localAnimes = [];
  bool _isLoading = false;
  String? _selectedDirectory;

  @override
  void initState() {
    super.initState();
    // Load last selected directory from prefs? (TODO)
  }

  Future<void> _pickDirectory() async {
    // Request storage permission on Android
    if (Platform.isAndroid) {
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
          if (['.mp4', '.mkv', '.avi', '.mov'].contains(ext)) {
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
        // Find best cover image in the folder?
        // For now, generate a placeholder or try to find 'cover.jpg' in the same dir

        return LocalAnime(
          title: entry.key,
          episodes: entry.value..sort((a, b) => a.number.compareTo(b.number)),
          path: directoryPath,
        );
      }).toList();

      // Sort animes by title
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

  ({String title, int episode}) _parseFilename(String filename) {
    // Try standard format: [Group] Title - 01 [1080p].ext
    // Regex: (?:\[.*?\]\s*)?([^-]+?)\s*-\s*(\d+)
    final regex =
        RegExp(r'(?:\[.*?\]\s*)?([^-]+?)\s*-\s*(\d+)', caseSensitive: false);
    final match = regex.firstMatch(filename);

    if (match != null) {
      final title = match.group(1)?.trim() ?? 'Unknown';
      final episode = int.tryParse(match.group(2) ?? '0') ?? 0;
      return (title: title, episode: episode);
    }

    // If no match, use parent folder name?
    // fallback
    return (title: filename, episode: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Libreria Locale'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: _pickDirectory,
            tooltip: 'Seleziona Cartella',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
          color: Colors.grey[800],
          child: const Icon(Icons.movie, color: Colors.white54),
        ),
        children: anime.episodes.map((ep) {
          return ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: Text(ep.filename),
            subtitle: Text('Episodio ${ep.number}'),
            onTap: () {
              // Play video
              _playVideo(ep.path);
            },
          );
        }).toList(),
      ),
    );
  }

  void _playVideo(String filePath) {
    // TODO: Navigate to player with file path
    // Need to update PlayerScreen to handle local files
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Playing: $filePath')),
    );
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
