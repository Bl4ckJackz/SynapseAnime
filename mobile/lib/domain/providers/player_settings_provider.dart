import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReadingMode { verticalScroll, horizontalSwipe, webtoon }

class PlayerSettings {
  final double defaultPlaybackSpeed;
  final int skipIntroDuration;
  final bool autoNextEpisode;
  final ReadingMode defaultReadingMode;
  final bool nightModeFilter;

  const PlayerSettings({
    this.defaultPlaybackSpeed = 1.0,
    this.skipIntroDuration = 85,
    this.autoNextEpisode = true,
    this.defaultReadingMode = ReadingMode.verticalScroll,
    this.nightModeFilter = false,
  });

  PlayerSettings copyWith({
    double? defaultPlaybackSpeed,
    int? skipIntroDuration,
    bool? autoNextEpisode,
    ReadingMode? defaultReadingMode,
    bool? nightModeFilter,
  }) {
    return PlayerSettings(
      defaultPlaybackSpeed: defaultPlaybackSpeed ?? this.defaultPlaybackSpeed,
      skipIntroDuration: skipIntroDuration ?? this.skipIntroDuration,
      autoNextEpisode: autoNextEpisode ?? this.autoNextEpisode,
      defaultReadingMode: defaultReadingMode ?? this.defaultReadingMode,
      nightModeFilter: nightModeFilter ?? this.nightModeFilter,
    );
  }
}

class PlayerSettingsNotifier extends StateNotifier<PlayerSettings> {
  PlayerSettingsNotifier() : super(const PlayerSettings()) {
    _loadSettings();
  }

  static const _keySpeed = 'player_speed';
  static const _keySkipIntro = 'player_skip_intro';
  static const _keyAutoNext = 'player_auto_next';
  static const _keyReadingMode = 'player_reading_mode';
  static const _keyNightMode = 'player_night_mode';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = PlayerSettings(
      defaultPlaybackSpeed: prefs.getDouble(_keySpeed) ?? 1.0,
      skipIntroDuration: prefs.getInt(_keySkipIntro) ?? 85,
      autoNextEpisode: prefs.getBool(_keyAutoNext) ?? true,
      defaultReadingMode: ReadingMode.values[prefs.getInt(_keyReadingMode) ?? 0],
      nightModeFilter: prefs.getBool(_keyNightMode) ?? false,
    );
  }

  Future<void> setPlaybackSpeed(double speed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySpeed, speed);
    state = state.copyWith(defaultPlaybackSpeed: speed);
  }

  Future<void> setSkipIntroDuration(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keySkipIntro, seconds);
    state = state.copyWith(skipIntroDuration: seconds);
  }

  Future<void> setAutoNextEpisode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoNext, value);
    state = state.copyWith(autoNextEpisode: value);
  }

  Future<void> setReadingMode(ReadingMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReadingMode, mode.index);
    state = state.copyWith(defaultReadingMode: mode);
  }

  Future<void> setNightModeFilter(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNightMode, value);
    state = state.copyWith(nightModeFilter: value);
  }
}

final playerSettingsProvider =
    StateNotifierProvider<PlayerSettingsNotifier, PlayerSettings>((ref) {
  return PlayerSettingsNotifier();
});
