import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/user_repository.dart';

final watchlistProvider = FutureProvider<List<WatchlistItem>>((ref) {
  return ref.watch(userRepositoryProvider).getWatchlist();
});
