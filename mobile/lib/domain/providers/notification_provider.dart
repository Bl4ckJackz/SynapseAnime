import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/api_client.dart';
import '../../core/constants.dart';

// Provider for notification settings state
final notificationSettingsProvider = StateNotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>((ref) {
  return NotificationSettingsNotifier(ref.read(apiClientProvider));
});

class NotificationSettingsState {
  final bool globalEnabled;
  final Map<String, bool> animeSettings;
  final bool isLoading;

  NotificationSettingsState({
    this.globalEnabled = true,
    this.animeSettings = const {},
    this.isLoading = false,
  });

  NotificationSettingsState copyWith({
    bool? globalEnabled,
    Map<String, bool>? animeSettings,
    bool? isLoading,
  }) {
    return NotificationSettingsState(
      globalEnabled: globalEnabled ?? this.globalEnabled,
      animeSettings: animeSettings ?? this.animeSettings,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class NotificationSettingsNotifier extends StateNotifier<NotificationSettingsState> {
  final ApiClient _apiClient;

  NotificationSettingsNotifier(this._apiClient) : super(NotificationSettingsState());

  Future<void> loadSettings() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _apiClient.get(AppConstants.notificationsSettings);
      final data = response.data as Map<String, dynamic>;

      state = state.copyWith(
        globalEnabled: data['globalEnabled'] as bool,
        animeSettings: Map<String, bool>.from(data['animeSettings'] as Map),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> updateGlobal(bool enabled) async {
    // Optimistic update
    state = state.copyWith(globalEnabled: enabled);

    try {
      await _apiClient.put(
        AppConstants.notificationsSettings,
        data: {'globalEnabled': enabled},
      );
    } catch (e) {
      // Revert on error
      state = state.copyWith(globalEnabled: !enabled);
    }
  }

  Future<void> updateAnime(String animeId, bool enabled) async {
    final newSettings = Map<String, bool>.from(state.animeSettings);
    newSettings[animeId] = enabled;

    // Optimistic update
    state = state.copyWith(animeSettings: newSettings);

    try {
      await _apiClient.put(
        AppConstants.notificationsSettings,
        data: {'animeId': animeId, 'animeEnabled': enabled},
      );
    } catch (e) {
      // Revert
      newSettings[animeId] = !enabled;
      state = state.copyWith(animeSettings: newSettings);
    }
  }

  Future<void> initializeFCM() async {
    try {
      // Request permission
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get token
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          debugPrint('FCM Token: $token');
          // Send to backend
          await _apiClient.post(
            AppConstants.notificationsRegisterToken,
            data: {'fcmToken': token},
          );
        }
      }
    } catch (e) {
      debugPrint('FCM Init Error: $e');
    }
  }
}
