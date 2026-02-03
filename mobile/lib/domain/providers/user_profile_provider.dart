import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';
import '../../data/repositories/user_repository.dart';

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, AsyncValue<User>>(
  (ref) => UserProfileNotifier(ref.watch(userRepositoryProvider)),
);

class UserProfileNotifier extends StateNotifier<AsyncValue<User>> {
  final UserRepository _userRepository;

  UserProfileNotifier(this._userRepository)
      : super(const AsyncValue.loading()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = const AsyncValue.loading();
    try {
      final user = await _userRepository.getProfile();
      state = AsyncValue.data(user);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> updateProfile({
    String? username,
    String? email,
    String? avatar,
  }) async {
    try {
      final updatedUser = await _userRepository.updateProfile(
        username: username,
        email: email,
        avatar: avatar,
      );
      state = AsyncValue.data(updatedUser);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}
