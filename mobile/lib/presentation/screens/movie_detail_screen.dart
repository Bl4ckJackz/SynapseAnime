import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../domain/entities/movie.dart';
import '../../domain/providers/movies_tv_provider.dart';
import '../widgets/movie_card.dart';

class MovieDetailScreen extends ConsumerWidget {
  final int tmdbId;

  const MovieDetailScreen({super.key, required this.tmdbId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movieAsync = ref.watch(movieDetailsProvider(tmdbId));

    return Scaffold(
      body: movieAsync.when(
        data: (movie) => _buildContent(context, ref, movie),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: AppTheme.errorColor, size: 48),
              const SizedBox(height: 16),
              Text('Errore: $err',
                  style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(movieDetailsProvider(tmdbId)),
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Movie movie) {
    return CustomScrollView(
      slivers: [
        // SliverAppBar with backdrop
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (movie.backdropUrl != null)
                  CachedNetworkImage(
                    imageUrl: movie.backdropUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      color: AppTheme.surfaceColor,
                    ),
                  )
                else
                  Container(color: AppTheme.surfaceColor),
                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                        AppTheme.backgroundColor,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  movie.title,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                // Tagline
                if (movie.tagline != null && movie.tagline!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      movie.tagline!,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                  ),

                // Metadata row: year, runtime, rating
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (movie.year != null)
                      _buildInfoChip(Icons.calendar_today, movie.year!),
                    if (movie.runtime != null)
                      _buildInfoChip(
                          Icons.access_time, '${movie.runtime} min'),
                    _buildInfoChip(Icons.star_rounded,
                        movie.voteAverage.toStringAsFixed(1),
                        iconColor: Colors.amber),
                  ],
                ),
                const SizedBox(height: 12),

                // Genres
                if (movie.genres.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: movie.genres.map((genre) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          genre,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 20),

                // Overview
                if (movie.overview != null && movie.overview!.isNotEmpty) ...[
                  Text(
                    movie.overview!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Watch button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to vidsrc player with movie embed URL
                      context.pushNamed('vidsrcPlayer', queryParameters: {
                        'url':
                            'https://vidsrc.xyz/embed/movie/$tmdbId',
                        'title': movie.title,
                      });
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: const Text(
                      'Guarda Ora',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Cast section
                if (movie.cast.isNotEmpty) ...[
                  Text(
                    'Cast',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: movie.cast.length,
                      itemBuilder: (context, index) {
                        final member = movie.cast[index];
                        final profilePath = member['profile_path'] ??
                            member['profilePath'];
                        final profileUrl = profilePath != null
                            ? 'https://image.tmdb.org/t/p/w185$profilePath'
                            : null;
                        return Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: AppTheme.surfaceColor,
                                backgroundImage: profileUrl != null
                                    ? CachedNetworkImageProvider(profileUrl)
                                    : null,
                                child: profileUrl == null
                                    ? const Icon(Icons.person,
                                        color: AppTheme.textMuted)
                                    : null,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                member['name']?.toString() ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Similar movies
                if (movie.similar.isNotEmpty) ...[
                  Text(
                    'Film Simili',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 310,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: movie.similar.length,
                      itemBuilder: (context, index) {
                        return MovieCard(movie: movie.similar[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label,
      {Color? iconColor}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: iconColor ?? AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
