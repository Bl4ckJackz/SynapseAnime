import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'source_provider.dart';
import '../../domain/entities/entities.dart';
import '../../data/repositories/anime_repository.dart';

final activeSourceIdProvider =
    NotifierProvider<ActiveSourceNotifier, String>(ActiveSourceNotifier.new);

class ActiveSourceNotifier extends Notifier<String> {
  @override
  @override
  String build() {
    // Note: sourceProvider is AsyncValue<List<AnimeSource>>
    final sourceState = ref.watch(sourceProvider); // Reactive watch

    if (sourceState.hasValue) {
      final sources = sourceState.value ?? [];
      final activeSource = sources.firstWhere(
        (source) => source.isActive == true,
        orElse: () => sources.isNotEmpty
            ? sources[0]
            : AnimeSource(
                id: 'jikan', name: 'MAL', description: '', isActive: true),
      );
      return activeSource.id;
    }

    return 'default_db'; // Default fallback
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
