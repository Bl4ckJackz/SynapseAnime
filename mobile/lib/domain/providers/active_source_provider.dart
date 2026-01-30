import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'source_provider.dart';
import '../../domain/entities/entities.dart';
import '../../data/repositories/anime_repository.dart';

final activeSourceIdProvider =
    StateNotifierProvider<ActiveSourceNotifier, String>((ref) {
  return ActiveSourceNotifier(ref);
});

class ActiveSourceNotifier extends StateNotifier<String> {
  final Ref ref;

  ActiveSourceNotifier(this.ref) : super('default_db') {
    _initActiveSource();
  }

  Future<void> _initActiveSource() async {
    final sourceState = ref.read(sourceProvider);
    if (sourceState.hasValue) {
      final sources = sourceState.value ?? [];
      final activeSource = sources.firstWhere(
        (source) => source.isActive == true,
        orElse: () => sources.isNotEmpty
            ? sources[0]
            : AnimeSource(
                id: 'jikan', name: 'MAL', description: '', isActive: true),
      );
      state = activeSource.id;
    }
  }

  Future<void> setActiveSource(String sourceId) async {
    state = sourceId;
    // Update the repository as well
    final repository = ref.read(animeRepositoryProvider);
    await repository.setActiveSource(sourceId);

    // Refresh the source list to update the 'isActive' state in the UI
    ref.read(sourceProvider.notifier).loadSources();
  }
}
