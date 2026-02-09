import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../core/theme.dart';

class SimplePlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;

  const SimplePlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
  });

  @override
  State<SimplePlayerScreen> createState() => _SimplePlayerScreenState();
}

class _SimplePlayerScreenState extends State<SimplePlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    debugPrint('=== SIMPLE PLAYER DEBUG: Starting initialization ===');
    debugPrint('SIMPLE PLAYER DEBUG: streamUrl=${widget.streamUrl}');
    debugPrint('SIMPLE PLAYER DEBUG: title=${widget.title}');

    try {
      debugPrint('SIMPLE PLAYER DEBUG: Creating VideoPlayerController...');
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(widget.streamUrl),
      );

      debugPrint('SIMPLE PLAYER DEBUG: Calling initialize()...');
      await _videoPlayerController!.initialize();
      debugPrint(
          'SIMPLE PLAYER DEBUG: VideoPlayerController initialized successfully!');
      debugPrint(
          'SIMPLE PLAYER DEBUG: Video duration: ${_videoPlayerController!.value.duration}');
      debugPrint(
          'SIMPLE PLAYER DEBUG: Video size: ${_videoPlayerController!.value.size}');
      debugPrint(
          'SIMPLE PLAYER DEBUG: Video hasError: ${_videoPlayerController!.value.hasError}');
      if (_videoPlayerController!.value.hasError) {
        debugPrint(
            'SIMPLE PLAYER DEBUG: Error description: ${_videoPlayerController!.value.errorDescription}');
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
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
        errorBuilder: (context, errorMessage) {
          debugPrint('SIMPLE PLAYER DEBUG: Chewie error: $errorMessage');
          return Center(
            child: Text(
              'Errore: $errorMessage',
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      setState(() {
        _initialized = true;
      });

      debugPrint('SIMPLE PLAYER DEBUG: Player fully initialized!');

      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (e, stackTrace) {
      debugPrint('SIMPLE PLAYER DEBUG: *** INITIALIZATION FAILED ***');
      debugPrint('SIMPLE PLAYER DEBUG: Error type: ${e.runtimeType}');
      debugPrint('SIMPLE PLAYER DEBUG: Error: $e');
      debugPrint('SIMPLE PLAYER DEBUG: Stack trace: $stackTrace');
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Errore durante la riproduzione',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 4,
                      color: Colors.black,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
