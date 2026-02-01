import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/api_client.dart';
import '../../domain/entities/user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(apiClientProvider));
});

final StateNotifierProvider<AuthService, AsyncValue<User?>>
    authServiceProvider = StateNotifierProvider((ref) {
  return AuthService(ref.read(authRepositoryProvider));
});

/// Provider to check if user is authenticated (has a valid token)
final isAuthenticatedProvider = FutureProvider<bool>((ref) async {
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: AppConstants.accessTokenKey);
  return token != null && token.isNotEmpty;
});

class AuthService extends StateNotifier<AsyncValue<User?>> {
  final AuthRepository _repository;

  AuthService(this._repository) : super(const AsyncValue.data(null));

  /// Check if there's a stored token and try to get user profile
  Future<bool> checkStoredToken() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: AppConstants.accessTokenKey);

    if (token == null || token.isEmpty) {
      state = const AsyncValue.data(null);
      return false;
    }

    try {
      // Try to get user profile with stored token
      final user = await _repository.getUserProfile();
      state = AsyncValue.data(user);
      return true;
    } catch (e) {
      // Token invalid or expired
      await storage.delete(key: AppConstants.accessTokenKey);
      state = const AsyncValue.data(null);
      return false;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.login(email, password);
      state = AsyncValue.data(user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> register(String nickname, String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.register(nickname, email, password);
      state = AsyncValue.data(user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> loginWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.loginWithGoogle();
      state = AsyncValue.data(user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncValue.data(null);
  }

  Future<void> checkSession() async {
    // Basic check, try to get profile if token exists in storage (handled by api client init)
    // For now just skipping complex re-auth logic
  }
}
