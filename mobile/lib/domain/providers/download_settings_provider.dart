import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DownloadDestination { local, server }

class DownloadSettings {
  final DownloadDestination destination;
  final String? localFolderPath;
  final String? serverFolderPath;

  const DownloadSettings({
    this.destination = DownloadDestination.server,
    this.localFolderPath,
    this.serverFolderPath,
  });

  DownloadSettings copyWith({
    DownloadDestination? destination,
    String? localFolderPath,
    String? serverFolderPath,
  }) {
    return DownloadSettings(
      destination: destination ?? this.destination,
      localFolderPath: localFolderPath ?? this.localFolderPath,
      serverFolderPath: serverFolderPath ?? this.serverFolderPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'destination': destination.name,
        'localFolderPath': localFolderPath,
        'serverFolderPath': serverFolderPath,
      };

  factory DownloadSettings.fromJson(Map<String, dynamic> json) {
    return DownloadSettings(
      destination: json['destination'] == 'local'
          ? DownloadDestination.local
          : DownloadDestination.server,
      localFolderPath: json['localFolderPath'],
      serverFolderPath: json['serverFolderPath'],
    );
  }
}

class DownloadSettingsNotifier extends StateNotifier<DownloadSettings> {
  DownloadSettingsNotifier() : super(const DownloadSettings()) {
    _loadSettings();
  }

  static const _keyDestination = 'download_destination';
  static const _keyLocalPath = 'download_local_path';
  static const _keyServerPath = 'download_server_path';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final destinationStr = prefs.getString(_keyDestination) ?? 'server';
    final localPath = prefs.getString(_keyLocalPath);
    final serverPath = prefs.getString(_keyServerPath);

    state = DownloadSettings(
      destination: destinationStr == 'local'
          ? DownloadDestination.local
          : DownloadDestination.server,
      localFolderPath: localPath,
      serverFolderPath: serverPath,
    );
  }

  Future<void> setDestination(DownloadDestination destination) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDestination, destination.name);
    state = state.copyWith(destination: destination);
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

final downloadSettingsProvider =
    StateNotifierProvider<DownloadSettingsNotifier, DownloadSettings>((ref) {
  return DownloadSettingsNotifier();
});
