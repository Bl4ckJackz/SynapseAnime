import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LibrarySource { local, server }

class LibrarySettings {
  final LibrarySource source;
  final String? localFolderPath;
  final String? serverFolderPath;

  const LibrarySettings({
    this.source = LibrarySource.local,
    this.localFolderPath,
    this.serverFolderPath,
  });

  LibrarySettings copyWith({
    LibrarySource? source,
    String? localFolderPath,
    String? serverFolderPath,
  }) {
    return LibrarySettings(
      source: source ?? this.source,
      localFolderPath: localFolderPath ?? this.localFolderPath,
      serverFolderPath: serverFolderPath ?? this.serverFolderPath,
    );
  }
}

class LibrarySettingsNotifier extends StateNotifier<LibrarySettings> {
  LibrarySettingsNotifier() : super(const LibrarySettings()) {
    _loadSettings();
  }

  static const _keySource = 'library_source';
  static const _keyLocalPath = 'library_local_path';
  static const _keyServerPath = 'library_server_path';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final sourceStr = prefs.getString(_keySource) ?? 'local';
    final localPath = prefs.getString(_keyLocalPath);
    final serverPath = prefs.getString(_keyServerPath);

    state = LibrarySettings(
      source:
          sourceStr == 'server' ? LibrarySource.server : LibrarySource.local,
      localFolderPath: localPath,
      serverFolderPath: serverPath,
    );
  }

  Future<void> setSource(LibrarySource source) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _keySource, source == LibrarySource.server ? 'server' : 'local');
    state = state.copyWith(source: source);
  }

  Future<void> setLocalFolderPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString(_keyLocalPath, path);
    } else {
      await prefs.remove(_keyLocalPath);
    }
    state = state.copyWith(localFolderPath: path);
  }

  Future<void> setServerFolderPath(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString(_keyServerPath, path);
    } else {
      await prefs.remove(_keyServerPath);
    }
    state = state.copyWith(serverFolderPath: path);
  }
}

final librarySettingsProvider =
    StateNotifierProvider<LibrarySettingsNotifier, LibrarySettings>((ref) {
  return LibrarySettingsNotifier();
});
