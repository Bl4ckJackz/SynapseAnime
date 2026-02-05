import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../core/theme.dart';
import '../../domain/entities/episode.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/providers/anime_provider.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String animeId;
  final String episodeId;

  const PlayerScreen({
    super.key,
    required this.animeId,
    required this.episodeId,
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
    try {
      final animeRepository = ref.read(animeRepositoryProvider);

      // Get episodes from provider state (preserves loaded pages)
      final episodesAsync = ref.read(animeEpisodesProvider(widget.animeId));
      var episodesList = episodesAsync.valueOrNull ?? [];

      if (episodesList.isEmpty) {
        // Fallback fetch if provider is empty - fetch ALL episodes
        episodesList = await animeRepository.getAllEpisodes(widget.animeId);
      }
      Episode? episode;
      try {
        episode = episodesList.firstWhere(
          (e) => e.id.toString() == widget.episodeId.toString(),
        );
      } catch (e) {
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
      );

      var currentEpisode = episode;

      if (currentEpisode.streamUrl.isEmpty) {
        // Resolve stream URL
        try {
          final resolvedData = await animeRepository.resolveStreamUrl(
              widget.episodeId,
              source: currentEpisode.source);

          final url = resolvedData['url'] as String;
          // Cast explicitly to Map<String, String> if present
          final headers = resolvedData['headers'] != null
              ? Map<String, String>.from(resolvedData['headers'])
              : null;

          if (url.isNotEmpty) {
            currentEpisode =
                currentEpisode.copyWith(streamUrl: url, headers: headers);
          }
        } catch (e) {
          print('Failed to resolve stream: $e');
        }
      }

      _episode = currentEpisode;

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
      } catch (e) {
        print('Could not load progress: $e');
      }

      // Prepare headers
      final Map<String, String> httpHeaders = {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };

      if (_episode!.headers != null && _episode!.headers!.isNotEmpty) {
        httpHeaders.addAll(_episode!.headers!);
      } else {
        // Fallback legacy logic
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

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(_episode!.streamUrl),
        httpHeaders: httpHeaders,
      );

      // Add error listener to handle playback errors
      _videoPlayerController!.addListener(() {
        if (_videoPlayerController!.value.hasError) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Errore video: ${_videoPlayerController!.value.errorDescription}')),
            );
          }
        }
      });

      await _videoPlayerController!.initialize();

      if (startPosition > 0) {
        await _videoPlayerController!.seekTo(Duration(seconds: startPosition));
      }

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

      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (e) {
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
          _videoPlayerController!.value.isPlaying) {
        final position = _videoPlayerController!.value.position.inSeconds;
        try {
          await ref
              .read(userRepositoryProvider)
              .updateProgress(widget.episodeId, position);
        } catch (e) {
          // Silently ignore errors (e.g., 401 Unauthorized when not logged in)
        }
      }
    });
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
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
