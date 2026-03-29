import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../domain/entities/tv_show.dart';
import '../../domain/providers/movies_tv_provider.dart';
import '../widgets/tv_show_card.dart';

class TvShowDetailScreen extends ConsumerStatefulWidget {
  final int tmdbId;

  const TvShowDetailScreen({super.key, required this.tmdbId});

  @override
  ConsumerState<TvShowDetailScreen> createState() =>
      _TvShowDetailScreenState();
}

class _TvShowDetailScreenState extends ConsumerState<TvShowDetailScreen> {
  int _selectedSeason = 1;

  @override
  Widget build(BuildContext context) {
    final tvShowAsync = ref.watch(tvShowDetailsProvider(widget.tmdbId));

    return Scaffold(
      body: tvShowAsync.when(
        data: (show) => _buildContent(context, show),
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
                onPressed: () =>
                    ref.invalidate(tvShowDetailsProvider(widget.tmdbId)),
                child: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, TvShow show) {
    // Fetch episodes for the selected season
    final episodesAsync = ref.watch(seasonEpisodesProvider(
      SeasonEpisodesKey(tmdbId: widget.tmdbId, season: _selectedSeason),
    ));

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
                if (show.backdropUrl != null)
                  CachedNetworkImage(
                    imageUrl: show.backdropUrl!,
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
                  show.name,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                // Metadata row
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    if (show.year != null)
                      _buildInfoChip(Icons.calendar_today, show.year!),
                    if (show.numberOfSeasons > 0)
                      _buildInfoChip(Icons.video_library,
                          '${show.numberOfSeasons} Stagioni'),
                    _buildInfoChip(Icons.star_rounded,
                        show.voteAverage.toStringAsFixed(1),
                        iconColor: Colors.amber),
                    if (show.status != null)
                      _buildInfoChip(Icons.info_outline, show.status!),
                  ],
                ),
                const SizedBox(height: 12),

                // Genres
                if (show.genres.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: show.genres.map((genre) {
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
                if (show.overview != null && show.overview!.isNotEmpty) ...[
                  Text(
                    show.overview!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Season selector
                if (show.numberOfSeasons > 0) ...[
                  Row(
                    children: [
                      Text(
                        'Stagione',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedSeason,
                            dropdownColor: AppTheme.surfaceColor,
                            style: const TextStyle(color: Colors.white),
                            items: List.generate(
                              show.numberOfSeasons,
                              (index) => DropdownMenuItem(
                                value: index + 1,
                                child: Text('Stagione ${index + 1}'),
                              ),
                            ),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedSeason = value;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Episodes list
                  Text(
                    'Episodi',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),

                  episodesAsync.when(
                    data: (episodes) {
                      if (episodes.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'Nessun episodio disponibile',
                              style: TextStyle(color: AppTheme.textMuted),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: episodes.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final episode = episodes[index];
                          return _buildEpisodeTile(context, show, episode);
                        },
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppTheme.primaryColor),
                      ),
                    ),
                    error: (err, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                          child: Text('Errore caricamento episodi: $err')),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Cast section
                if (show.cast.isNotEmpty) ...[
                  Text(
                    'Cast',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: show.cast.length,
                      itemBuilder: (context, index) {
                        final member = show.cast[index];
                        return Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 12),
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 32,
                                backgroundColor: AppTheme.surfaceColor,
                                backgroundImage: member.profileUrl != null
                                    ? CachedNetworkImageProvider(
                                        member.profileUrl!)
                                    : null,
                                child: member.profileUrl == null
                                    ? const Icon(Icons.person,
                                        color: AppTheme.textMuted)
                                    : null,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                member.name,
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

                // Similar shows
                if (show.similar.isNotEmpty) ...[
                  Text(
                    'Serie Simili',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 310,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: show.similar.length,
                      itemBuilder: (context, index) {
                        return TvShowCard(show: show.similar[index]);
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

  Widget _buildEpisodeTile(
      BuildContext context, TvShow show, TvEpisode episode) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: episode.stillUrl != null
              ? CachedNetworkImage(
                  imageUrl: episode.stillUrl!,
                  width: 100,
                  height: 56,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => Container(
                    width: 100,
                    height: 56,
                    color: AppTheme.cardColor,
                    child: const Icon(Icons.tv, color: AppTheme.textMuted),
                  ),
                )
              : Container(
                  width: 100,
                  height: 56,
                  color: AppTheme.cardColor,
                  child: const Icon(Icons.tv, color: AppTheme.textMuted),
                ),
        ),
        title: Text(
          'Ep. ${episode.episodeNumber} - ${episode.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (episode.overview != null && episode.overview!.isNotEmpty)
              Text(
                episode.overview!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            if (episode.runtime != null)
              Text(
                '${episode.runtime} min',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.play_circle_fill,
              color: AppTheme.primaryColor, size: 36),
          onPressed: () {
            context.pushNamed('vidsrcPlayer', queryParameters: {
              'url':
                  'https://vidsrc.xyz/embed/tv/${widget.tmdbId}/${episode.seasonNumber}/${episode.episodeNumber}',
              'title':
                  '${show.name} S${episode.seasonNumber}E${episode.episodeNumber}',
            });
          },
        ),
      ),
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
