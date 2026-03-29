import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../domain/entities/movie.dart';
import '../../domain/entities/tv_show.dart';
import '../../domain/providers/movies_tv_provider.dart';
import '../widgets/section_header.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/movie_card.dart';
import '../widgets/tv_show_card.dart';

class MoviesTvHomeScreen extends ConsumerStatefulWidget {
  const MoviesTvHomeScreen({super.key});

  @override
  ConsumerState<MoviesTvHomeScreen> createState() => _MoviesTvHomeScreenState();
}

class _MoviesTvHomeScreenState extends ConsumerState<MoviesTvHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(moviesTvSearchQueryProvider);
    final trendingMoviesAsync = ref.watch(trendingMoviesProvider);
    final trendingTvAsync = ref.watch(trendingTvShowsProvider);
    final popularMoviesAsync = ref.watch(popularMoviesProvider);
    final popularTvAsync = ref.watch(popularTvShowsProvider);

    final movieSearchAsync =
        searchQuery.isNotEmpty ? ref.watch(movieSearchProvider(searchQuery)) : null;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Cerca film o serie TV...',
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: Colors.white),
                onSubmitted: (value) {
                  ref.read(moviesTvSearchQueryProvider.notifier).state = value;
                },
              )
            : Row(
                children: [
                  const Icon(Icons.movie_filter, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Film & Serie TV',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(moviesTvSearchQueryProvider.notifier).state = '';
                }
              });
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(trendingMoviesProvider);
          ref.invalidate(trendingTvShowsProvider);
          ref.invalidate(popularMoviesProvider);
          ref.invalidate(popularTvShowsProvider);
        },
        child: movieSearchAsync != null
            ? _buildSearchResults(movieSearchAsync)
            : _buildMainContent(
                trendingMoviesAsync,
                trendingTvAsync,
                popularMoviesAsync,
                popularTvAsync,
              ),
      ),
    );
  }

  Widget _buildSearchResults(AsyncValue<List<Movie>> searchAsync) {
    return searchAsync.when(
      data: (movieList) {
        if (movieList.isEmpty) {
          return const Center(child: Text('Nessun risultato trovato'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.55,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: movieList.length,
          itemBuilder: (context, index) => MovieCard(
            movie: movieList[index],
            width: double.infinity,
            height: 240,
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      ),
      error: (err, _) => Center(child: Text('Errore: $err')),
    );
  }

  Widget _buildMainContent(
    AsyncValue<List<Movie>> trendingMoviesAsync,
    AsyncValue<List<TvShow>> trendingTvAsync,
    AsyncValue<List<Movie>> popularMoviesAsync,
    AsyncValue<List<TvShow>> popularTvAsync,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Trending Movies
          const SectionHeader(title: 'Film di Tendenza'),
          SizedBox(
            height: 310,
            child: trendingMoviesAsync.when(
              data: (movies) {
                if (movies.isEmpty) {
                  return const Center(child: Text('Nessun film disponibile'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: movies.length,
                  itemBuilder: (context, index) {
                    return MovieCard(movie: movies[index]);
                  },
                );
              },
              loading: () => const ShimmerAnimeList(height: 310),
              error: (err, _) => Center(child: Text('Errore: $err')),
            ),
          ),

          const SizedBox(height: 24),

          // Trending TV Shows
          const SectionHeader(title: 'Serie TV di Tendenza'),
          SizedBox(
            height: 310,
            child: trendingTvAsync.when(
              data: (shows) {
                if (shows.isEmpty) {
                  return const Center(
                      child: Text('Nessuna serie TV disponibile'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: shows.length,
                  itemBuilder: (context, index) {
                    return TvShowCard(show: shows[index]);
                  },
                );
              },
              loading: () => const ShimmerAnimeList(height: 310),
              error: (err, _) => Center(child: Text('Errore: $err')),
            ),
          ),

          const SizedBox(height: 24),

          // Popular Movies
          const SectionHeader(title: 'Film Popolari'),
          SizedBox(
            height: 310,
            child: popularMoviesAsync.when(
              data: (movies) {
                if (movies.isEmpty) {
                  return const Center(child: Text('Nessun film disponibile'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: movies.length,
                  itemBuilder: (context, index) {
                    return MovieCard(movie: movies[index]);
                  },
                );
              },
              loading: () => const ShimmerAnimeList(height: 310),
              error: (err, _) => Center(child: Text('Errore: $err')),
            ),
          ),

          const SizedBox(height: 24),

          // Popular TV Shows
          const SectionHeader(title: 'Serie TV Popolari'),
          SizedBox(
            height: 310,
            child: popularTvAsync.when(
              data: (shows) {
                if (shows.isEmpty) {
                  return const Center(
                      child: Text('Nessuna serie TV disponibile'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: shows.length,
                  itemBuilder: (context, index) {
                    return TvShowCard(show: shows[index]);
                  },
                );
              },
              loading: () => const ShimmerAnimeList(height: 310),
              error: (err, _) => Center(child: Text('Errore: $err')),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
