// lib/screens/video_player_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final bool isPremiumUser;

  const VideoPlayerScreen({
    Key? key,
    required this.videoUrl,
    required this.title,
    required this.isPremiumUser,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  bool _isFullscreen = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    _controller = VideoPlayerController.network(widget.videoUrl);
    await _controller.initialize();
    setState(() {});
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _startHideTimer();
      } else {
        _cancelHideTimer();
      }
    });
  }

  void _startHideTimer() {
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _cancelHideTimer() {
    _hideTimer?.cancel();
  }

  void _playAd() {
    // Show ad if user is not premium
    if (!widget.isPremiumUser) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Advertisement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(
                'https://placehold.co/300x150?text=Ad+Content',
                height: 150,
                width: 300,
              ),
              const SizedBox(height: 16),
              const Text('This is an advertisement. Premium users see no ads.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close ad dialog
                _controller.play(); // Resume video
              },
              child: const Text('Skip Ad (5s)'),
            ),
          ],
        ),
      );

      // Auto-skip after 5 seconds for demo
      Future.delayed(const Duration(seconds: 5), () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          _controller.play();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video player
          Center(
            child: _controller.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : const Center(child: CircularProgressIndicator()),
          ),

          // Controls overlay
          if (_showControls)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Progress bar
                    VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: VideoProgressColors(
                        playedColor: Colors.red,
                        bufferedColor: Colors.grey[700]!,
                        backgroundColor: Colors.grey[800]!,
                      ),
                    ),

                    // Control buttons
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(
                              _controller.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: () {
                              if (_controller.value.isPlaying) {
                                _controller.pause();
                              } else {
                                // Check if we need to play an ad
                                if (!widget.isPremiumUser && 
                                    _controller.value.position.inMinutes % 10 == 0 && 
                                    _controller.value.position.inSeconds > 0) {
                                  _controller.pause();
                                  _playAd();
                                } else {
                                  _controller.play();
                                }
                              }
                              _startHideTimer();
                            },
                          ),
                          
                          IconButton(
                            icon: const Icon(
                              Icons.skip_previous,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: () {
                              // Skip to previous episode
                              _startHideTimer();
                            },
                          ),
                          
                          IconButton(
                            icon: const Icon(
                              Icons.skip_next,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: () {
                              // Skip to next episode
                              _startHideTimer();
                            },
                          ),
                          
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.hd,
                              color: Colors.white,
                              size: 24,
                            ),
                            onSelected: (String result) {
                              // Handle quality selection
                              _startHideTimer();
                            },
                            itemBuilder: (BuildContext context) =>
                                <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: '360p',
                                child: Text('360p'),
                              ),
                              const PopupMenuItem<String>(
                                value: '480p',
                                child: Text('480p'),
                              ),
                              const PopupMenuItem<String>(
                                value: '720p',
                                child: Text('720p'),
                              ),
                              PopupMenuItem<String>(
                                value: '1080p',
                                child: Text(
                                  '1080p',
                                  style: TextStyle(
                                    color: widget.isPremiumUser 
                                        ? Colors.white 
                                        : Colors.grey,
                                  ),
                                ),
                                enabled: widget.isPremiumUser,
                              ),
                            ],
                          ),
                          
                          IconButton(
                            icon: Icon(
                              _isFullscreen
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              color: Colors.white,
                              size: 32,
                            ),
                            onPressed: () {
                              // Toggle fullscreen
                              setState(() {
                                _isFullscreen = !_isFullscreen;
                              });
                              _startHideTimer();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Title overlay
          Positioned(
            top: 50,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Back button
          Positioned(
            top: 50,
            left: 16,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 32,
              ),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }
}