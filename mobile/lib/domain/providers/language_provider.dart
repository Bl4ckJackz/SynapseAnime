import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kLanguageCodeKey = 'language_code';

final languageProvider = StateNotifierProvider<LanguageNotifier, String>((ref) {
  return LanguageNotifier();
});

class LanguageNotifier extends StateNotifier<String> {
  LanguageNotifier() : super('it') {
    _initLanguage();
  }

  Future<void> _initLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(kLanguageCodeKey) ?? 'it';
    state = languageCode;
  }

  Future<void> changeLanguage(String languageCode) async {
    state = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kLanguageCodeKey, languageCode);
  }

  String get currentLanguage => state;
}
