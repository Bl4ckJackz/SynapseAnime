import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/entities.dart';
import '../../features/anime/data/repositories/anime_repository.dart';

final sourceProvider =
    StateNotifierProvider<SourceNotifier, AsyncValue<List<AnimeSource>>>((ref) {
  return SourceNotifier(ref.watch(animeRepositoryProvider));
});

class SourceNotifier extends StateNotifier<AsyncValue<List<AnimeSource>>> {
  final AnimeRepository _repository;

  SourceNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadSources();
  }

  Future<void> loadSources() async {
    state = const AsyncValue.loading();
    try {
      final sources = await _repository.getAvailableSources();
      state = AsyncValue.data(sources);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> setActiveSource(String sourceId) async {
    try {
      await _repository.setActiveSource(sourceId);
      // Reload sources to reflect the change
      await loadSources();
    } catch (e) {
      // Handle error appropriately
      rethrow;
    }
  }

  String? getActiveSource() {
    return _repository.getActiveSource();
  }
}
