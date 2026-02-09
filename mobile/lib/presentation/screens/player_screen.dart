import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../core/theme.dart';
import '../../domain/entities/episode.dart';
import '../../domain/entities/anime.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/providers/anime_provider.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String animeId;
  final String episodeId;
  final String? source;
  final String? startUrl;

  const PlayerScreen({
    super.key,
    required this.animeId,
    required this.episodeId,
    this.source,
    this.startUrl,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _initialized = false;
  Timer? _progressTimer;
  Episode? _episode;
  Anime? _anime;
  List<Episode> _episodes = [];
  double _volume = 1.0;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    // Restore orientations and UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    debugPrint('=== PLAYER DEBUG: Starting initialization ===');
    debugPrint('PLAYER DEBUG: animeId=${widget.animeId}');
    debugPrint('PLAYER DEBUG: episodeId=${widget.episodeId}');
    debugPrint('PLAYER DEBUG: source=${widget.source}');
    debugPrint('PLAYER DEBUG: startUrl=${widget.startUrl}');

    try {
      final animeRepository = ref.read(animeRepositoryProvider);

      // Try to fetch anime details for metadata (important for watch history)
      try {
        _anime = await ref.read(animeDetailsProvider(widget.animeId).future);
        debugPrint('PLAYER DEBUG: Loaded anime metadata: ${_anime?.title}');
      } catch (e) {
        debugPrint('PLAYER DEBUG: Failed to load anime metadata: $e');
      }

      // Get episodes from provider state (preserves loaded pages)
      final episodesAsync = ref.read(animeEpisodesProvider(widget.animeId));
      var episodesList = episodesAsync.valueOrNull ?? [];
      debugPrint(
          'PLAYER DEBUG: Episodes from provider: ${episodesList.length}');

      if (episodesList.isEmpty) {
        // Fallback fetch if provider is empty - fetch ALL episodes
        debugPrint('PLAYER DEBUG: Fetching all episodes from repository...');
        episodesList = await animeRepository.getAllEpisodes(widget.animeId);
        debugPrint('PLAYER DEBUG: Fetched ${episodesList.length} episodes');
      }
      _episodes = episodesList;

      Episode? episode;
      try {
        episode = episodesList.firstWhere(
          (e) => e.id.toString() == widget.episodeId.toString(),
        );
        debugPrint('PLAYER DEBUG: Found episode in list: ${episode.id}');
      } catch (e) {
        debugPrint(
            'PLAYER DEBUG: Episode not found in list, using first or placeholder');
        if (episodesList.isNotEmpty) {
          episode = episodesList.first;
        }
      }

      // If not in list, try to fetch it or create a placeholder
      episode ??= Episode(
        id: widget.episodeId,
        animeId: widget.animeId,
        number: 1,
        title: 'Episode',
        duration: 0,
        thumbnail: null,
        streamUrl: '',
        source: widget.source,
      );

      var currentEpisode = episode;
      debugPrint(
          'PLAYER DEBUG: Current episode streamUrl before: ${currentEpisode.streamUrl}');

      if (widget.startUrl != null && widget.startUrl!.isNotEmpty) {
        debugPrint(
            'PLAYER DEBUG: Using startUrl from widget: ${widget.startUrl}');
        currentEpisode = currentEpisode.copyWith(streamUrl: widget.startUrl);
      } else if (currentEpisode.streamUrl.isEmpty) {
        // Resolve stream URL
        debugPrint('PLAYER DEBUG: Resolving stream URL...');
        try {
          final resolvedData = await animeRepository.resolveStreamUrl(
              widget.episodeId,
              source: currentEpisode.source);

          final url = resolvedData['url'] as String;
          // Cast explicitly to Map<String, String> if present
          final headers = resolvedData['headers'] != null
              ? Map<String, String>.from(resolvedData['headers'])
              : null;

          debugPrint('PLAYER DEBUG: Resolved URL: $url');
          debugPrint('PLAYER DEBUG: Resolved headers: $headers');

          if (url.isNotEmpty) {
            currentEpisode =
                currentEpisode.copyWith(streamUrl: url, headers: headers);
          }
        } catch (e) {
          debugPrint('PLAYER DEBUG: Failed to resolve stream: $e');
        }
      }

      _episode = currentEpisode;
      debugPrint('PLAYER DEBUG: Final streamUrl: ${_episode!.streamUrl}');

      // Validate the stream URL before initializing
      if (_episode!.streamUrl.isEmpty) {
        throw Exception(
            'Video non disponibile. Il server di streaming potrebbe essere temporaneamente irraggiungibile. Riprova più tardi.');
      }

      // Try to get saved progress
      int startPosition = 0;
      try {
        final progressInfo = await ref
            .read(userRepositoryProvider)
            .getEpisodeProgress(widget.episodeId);
        startPosition = progressInfo.progressSeconds;
        debugPrint(
            'PLAYER DEBUG: Start position from progress: $startPosition');
      } catch (e) {
        debugPrint('PLAYER DEBUG: Could not load progress: $e');
      }

      // Prepare headers - skip Referer for local/downloaded content
      final isLocalContent = _episode!.streamUrl.contains('localhost') ||
          _episode!.streamUrl.contains('127.0.0.1') ||
          _episode!.streamUrl.contains('/downloads/');
      debugPrint('PLAYER DEBUG: Is local content: $isLocalContent');

      final Map<String, String> httpHeaders = {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };

      if (_episode!.headers != null && _episode!.headers!.isNotEmpty) {
        httpHeaders.addAll(_episode!.headers!);
      } else if (!isLocalContent) {
        // Only add Referer for external streams, not for local downloads
        final activeSource = currentEpisode.source ??
            animeRepository.getActiveSource() ??
            'jikan';
        String referer = 'https://www.animeworld.tv/';
        if (activeSource.contains('unity')) {
          referer = 'https://www.animeunity.to/';
        } else if (activeSource.contains('saturn')) {
          referer = 'https://www.animesaturn.tv/';
        }
        httpHeaders['Referer'] = referer;
      }

      final headersToUse = isLocalContent ? <String, String>{} : httpHeaders;
      debugPrint('PLAYER DEBUG: Headers to use: $headersToUse');
      debugPrint('PLAYER DEBUG: Creating VideoPlayerController...');

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(_episode!.streamUrl),
        httpHeaders: headersToUse,
      );

      // Add error listener to handle playback errors
      _videoPlayerController!.addListener(_videoListener);

      debugPrint('PLAYER DEBUG: Calling initialize()...');
      try {
        await _videoPlayerController!.initialize();
        debugPrint(
            'PLAYER DEBUG: VideoPlayerController initialized successfully!');
        debugPrint(
            'PLAYER DEBUG: Video duration: ${_videoPlayerController!.value.duration}');
        debugPrint(
            'PLAYER DEBUG: Video size: ${_videoPlayerController!.value.size}');
      } catch (initError) {
        debugPrint('PLAYER DEBUG: *** INITIALIZATION FAILED ***');
        debugPrint('PLAYER DEBUG: Error type: ${initError.runtimeType}');
        debugPrint('PLAYER DEBUG: Error message: $initError');
        rethrow;
      }

      if (startPosition > 0) {
        await _videoPlayerController!.seekTo(Duration(seconds: startPosition));
      }

      // Initialize volume
      await _videoPlayerController!.setVolume(_volume);

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: 16 / 9,
        allowFullScreen: true,
        allowMuting: true,
        showControls: true,
        placeholder: Container(color: Colors.black),
        materialProgressColors: ChewieProgressColors(
          playedColor: AppTheme.primaryColor,
          handleColor: AppTheme.primaryColor,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white24,
        ),
      );

      _startProgressTracking();

      setState(() {
        _initialized = true;
      });

      debugPrint('PLAYER DEBUG: Player fully initialized!');

      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (e, stackTrace) {
      debugPrint('PLAYER DEBUG: *** FATAL ERROR ***');
      debugPrint('PLAYER DEBUG: Error: $e');
      debugPrint('PLAYER DEBUG: Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento video: ${e.toString()}')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  void _startProgressTracking() {
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_videoPlayerController != null &&
          _videoPlayerController!.value.isPlaying &&
          _episode != null) {
        final position = _videoPlayerController!.value.position.inSeconds;
        try {
          await ref.read(userRepositoryProvider).updateProgress(
                episodeId: widget.episodeId,
                progressSeconds: position,
                animeId: widget.animeId,
                animeTitle: _anime?.title ?? 'Unknown Anime',
                animeCover: _anime?.coverUrl,
                animeTotalEpisodes: _anime?.totalEpisodes,
                episodeNumber: _episode?.number,
                episodeTitle: _episode?.title,
                episodeThumbnail: _episode?.thumbnail,
                duration: _videoPlayerController!.value.duration.inSeconds,
                source: widget.source ?? _episode?.source,
              );
        } catch (e) {
          // Silently ignore errors (e.g., 401 Unauthorized when not logged in)
          print('Progress update failed: $e');
        }
      }
    });
  }

  void _videoListener() {
    if (_videoPlayerController == null) return;

    if (_videoPlayerController!.value.hasError) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Errore video: ${_videoPlayerController!.value.errorDescription}')),
        );
      }
    }

    // Auto-next logic: check if video is finished
    if (_videoPlayerController!.value.isInitialized &&
        !_videoPlayerController!.value.isPlaying &&
        _videoPlayerController!.value.position >=
            _videoPlayerController!.value.duration &&
        _videoPlayerController!.value.duration.inSeconds > 0) {
      _playNextEpisode();
    }
  }

  void _playNextEpisode() {
    if (_episodes.isEmpty || _episode == null) return;

    // Sort episodes by number just in case
    // Assuming episode.number is reliable. If it's a string or irregular, index-based might be safer
    // But since the list comes from provider/repo, let's use list index.

    final currentIndex = _episodes.indexWhere((e) => e.id == _episode!.id);
    if (currentIndex != -1 && currentIndex < _episodes.length - 1) {
      final nextEpisode = _episodes[currentIndex + 1];

      // Navigate to new player screen (to reset everything cleanly)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            animeId: widget.animeId,
            episodeId: nextEpisode.id,
          ),
        ),
      );
    } else {
      // Last episode, maybe exit or show toast?
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Non ci sono altri episodi.')),
        );
      }
    }
  }

  void _changeVolume(double value) {
    setState(() {
      _volume = value;
    });
    _videoPlayerController?.setVolume(_volume);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Chewie(controller: _chewieController!),
            ),
            Positioned(
              top: 16,
              left: 16,
              child: SafeArea(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 16),
                    // Volume Slider
                    SizedBox(
                      width: 150,
                      child: Slider(
                        value: _volume,
                        min: 0.0,
                        max: 1.0,
                        activeColor: AppTheme.primaryColor,
                        inactiveColor: Colors.white24,
                        onChanged: _changeVolume,
                      ),
                    ),
                    const Icon(Icons.volume_up, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: TextButton.icon(
                  onPressed: _playNextEpisode,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Next Ep'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
