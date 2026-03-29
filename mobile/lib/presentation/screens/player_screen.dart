import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme.dart';
import '../../domain/entities/episode.dart';
import '../../domain/entities/anime.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/providers/anime_provider.dart';
import '../../domain/providers/player_settings_provider.dart';
import '../widgets/player/custom_video_controls.dart';

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
  bool _initialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _progressTimer;
  Episode? _episode;
  Anime? _anime;
  List<Episode> _episodes = [];

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _videoPlayerController?.dispose();
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

      // Load anime metadata
      try {
        _anime = await ref.read(animeDetailsProvider(widget.animeId).future);
      } catch (e) {
        if (kDebugMode) debugPrint('Failed to load anime metadata: $e');
      }

      // Get episodes
      final episodesAsync = ref.read(animeEpisodesProvider(widget.animeId));
      var episodesList = episodesAsync.valueOrNull ?? [];
      if (episodesList.isEmpty) {
        episodesList = await animeRepository.getAllEpisodes(widget.animeId);
      }
      _episodes = episodesList;

      // Find current episode
      Episode? episode;
      try {
        episode = episodesList.firstWhere(
          (e) => e.id.toString() == widget.episodeId.toString(),
        );
      } catch (_) {
        if (episodesList.isNotEmpty) episode = episodesList.first;
      }

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

      // Resolve stream URL
      if (widget.startUrl != null && widget.startUrl!.isNotEmpty) {
        currentEpisode = currentEpisode.copyWith(streamUrl: widget.startUrl);
      } else if (currentEpisode.streamUrl.isEmpty) {
        try {
          final resolvedData = await animeRepository.resolveStreamUrl(
              widget.episodeId,
              source: currentEpisode.source);
          final url = resolvedData['url'] as String;
          final headers = resolvedData['headers'] != null
              ? Map<String, String>.from(resolvedData['headers'])
              : null;
          if (url.isNotEmpty) {
            currentEpisode =
                currentEpisode.copyWith(streamUrl: url, headers: headers);
          }
        } catch (e) {
          if (kDebugMode) debugPrint('Failed to resolve stream: $e');
        }
      }

      _episode = currentEpisode;

      if (_episode!.streamUrl.isEmpty) {
        throw Exception('Video non disponibile. Riprova più tardi.');
      }

      // Saved progress
      int startPosition = 0;
      try {
        final progressInfo = await ref
            .read(userRepositoryProvider)
            .getEpisodeProgress(widget.episodeId);
        startPosition = progressInfo.progressSeconds;
      } catch (_) {}

      // Headers
      final isLocalContent = _episode!.streamUrl.contains('localhost') ||
          _episode!.streamUrl.contains('127.0.0.1') ||
          _episode!.streamUrl.contains('/downloads/');

      final Map<String, String> httpHeaders = {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      };

      if (_episode!.headers != null && _episode!.headers!.isNotEmpty) {
        httpHeaders.addAll(_episode!.headers!);
      } else if (!isLocalContent) {
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

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(_episode!.streamUrl),
        httpHeaders: headersToUse,
      );

      _videoPlayerController!.addListener(_videoListener);
      await _videoPlayerController!.initialize();

      if (startPosition > 0) {
        await _videoPlayerController!.seekTo(Duration(seconds: startPosition));
      }

      // Set initial playback speed from settings
      final settings = ref.read(playerSettingsProvider);
      await _videoPlayerController!.setPlaybackSpeed(settings.defaultPlaybackSpeed);

      await _videoPlayerController!.play();

      _startProgressTracking();

      setState(() => _initialized = true);

      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
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
        } catch (_) {}
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

    // Auto-next episode
    final settings = ref.read(playerSettingsProvider);
    if (settings.autoNextEpisode &&
        _videoPlayerController!.value.isInitialized &&
        !_videoPlayerController!.value.isPlaying &&
        _videoPlayerController!.value.position >=
            _videoPlayerController!.value.duration &&
        _videoPlayerController!.value.duration.inSeconds > 0) {
      _playNextEpisode();
    }
  }

  void _playNextEpisode() {
    if (_episodes.isEmpty || _episode == null) return;

    final currentIndex = _episodes.indexWhere((e) => e.id == _episode!.id);
    if (currentIndex != -1 && currentIndex < _episodes.length - 1) {
      final nextEpisode = _episodes[currentIndex + 1];
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            animeId: widget.animeId,
            episodeId: nextEpisode.id,
          ),
        ),
      );
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Non ci sono altri episodi.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _initialized = false;
                  });
                  _initializePlayer();
                },
                child: const Text('Riprova'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Indietro'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    final settings = ref.watch(playerSettingsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomVideoControls(
        controller: _videoPlayerController!,
        title: _anime?.title ?? 'Anime',
        subtitle: _episode != null
            ? 'Episodio ${_episode!.number}${_episode!.title.isNotEmpty ? ' - ${_episode!.title}' : ''}'
            : null,
        onBack: () => Navigator.of(context).pop(),
        onNextEpisode: _playNextEpisode,
        skipIntroDuration: settings.skipIntroDuration,
        initialPlaybackSpeed: settings.defaultPlaybackSpeed,
      ),
    );
  }
}
