import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/user_repository.dart';

final watchHistoryProvider = StateNotifierProvider<WatchHistoryNotifier,
    AsyncValue<List<WatchHistoryItem>>>((ref) {
  return WatchHistoryNotifier(ref.read(userRepositoryProvider));
});

class WatchHistoryNotifier
    extends StateNotifier<AsyncValue<List<WatchHistoryItem>>> {
  final UserRepository _repository;

  WatchHistoryNotifier(this._repository) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      state = const AsyncValue.loading();
      final history = await _repository.getContinueWatching();
      state = AsyncValue.data(history);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  WatchHistoryItem? getProgressForAnime(String animeId) {
    return state.valueOrNull?.cast<WatchHistoryItem?>().firstWhere(
          (item) => item?.anime?.id == animeId,
          orElse: () => null,
        );
  }
}
