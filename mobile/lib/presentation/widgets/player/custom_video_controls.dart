import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme.dart';

class CustomVideoControls extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onNextEpisode;
  final int skipIntroDuration;
  final double initialPlaybackSpeed;

  const CustomVideoControls({
    super.key,
    required this.controller,
    required this.title,
    this.subtitle,
    this.onBack,
    this.onNextEpisode,
    this.skipIntroDuration = 85,
    this.initialPlaybackSpeed = 1.0,
  });

  @override
  State<CustomVideoControls> createState() => _CustomVideoControlsState();
}

class _CustomVideoControlsState extends State<CustomVideoControls> {
  bool _showControls = true;
  bool _orientationLocked = false;
  Timer? _hideTimer;
  double _currentSpeed = 1.0;

  // Seek ripple state
  int _leftSeekCount = 0;
  int _rightSeekCount = 0;
  Timer? _leftRippleTimer;
  Timer? _rightRippleTimer;

  // Brightness/volume drag state
  bool _isDraggingBrightness = false;
  bool _isDraggingVolume = false;
  double _dragValue = 0;

  // Horizontal seek drag state
  bool _isSeeking = false;
  Duration _seekPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _currentSpeed = widget.initialPlaybackSpeed;
    widget.controller.addListener(_onVideoStateChanged);
    _resetHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _leftRippleTimer?.cancel();
    _rightRippleTimer?.cancel();
    widget.controller.removeListener(_onVideoStateChanged);
    super.dispose();
  }

  void _onVideoStateChanged() {
    if (mounted) setState(() {});
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && widget.controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetHideTimer();
  }

  void _seekForward(int seconds) {
    final position = widget.controller.value.position;
    final duration = widget.controller.value.duration;
    final newPosition = position + Duration(seconds: seconds);
    widget.controller
        .seekTo(newPosition > duration ? duration : newPosition);
    setState(() {
      _rightSeekCount += seconds;
    });
    _rightRippleTimer?.cancel();
    _rightRippleTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _rightSeekCount = 0);
    });
  }

  void _seekBackward(int seconds) {
    final position = widget.controller.value.position;
    final newPosition = position - Duration(seconds: seconds);
    widget.controller
        .seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
    setState(() {
      _leftSeekCount += seconds;
    });
    _leftRippleTimer?.cancel();
    _leftRippleTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _leftSeekCount = 0);
    });
  }

  void _togglePlay() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    } else {
      widget.controller.play();
    }
    _resetHideTimer();
  }

  void _toggleOrientationLock() {
    setState(() => _orientationLocked = !_orientationLocked);
    if (_orientationLocked) {
      final orientation = MediaQuery.of(context).orientation;
      if (orientation == Orientation.landscape) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    } else {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  static const _pipChannel = MethodChannel('com.example.anime_ai_player/pip');

  Future<void> _enterPip() async {
    try {
      await _pipChannel.invokeMethod('enterPip');
    } catch (e) {
      if (kDebugMode) debugPrint('PiP not available: $e');
    }
  }

  void _showSpeedSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Velocità di riproduzione',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...[0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) => ListTile(
                  title: Text(
                    '${speed}x',
                    style: TextStyle(
                      color: _currentSpeed == speed
                          ? AppTheme.primaryColor
                          : Colors.white,
                      fontWeight: _currentSpeed == speed
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: _currentSpeed == speed
                      ? const Icon(Icons.check, color: AppTheme.primaryColor)
                      : null,
                  onTap: () {
                    widget.controller.setPlaybackSpeed(speed);
                    setState(() => _currentSpeed = speed);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.value;
    final position = _isSeeking ? _seekPosition : value.position;
    final duration = value.duration;
    final isPlaying = value.isPlaying;
    final showSkipIntro = position.inSeconds < widget.skipIntroDuration &&
        position.inSeconds > 0;

    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video
          Center(
            child: AspectRatio(
              aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
              child: VideoPlayer(widget.controller),
            ),
          ),

          // Gesture zones (always active)
          Row(
            children: [
              // Left zone: double-tap backward, vertical drag brightness
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () => _seekBackward(10),
                  onVerticalDragUpdate: (details) {
                    setState(() {
                      _isDraggingBrightness = true;
                      _dragValue = (_dragValue - details.delta.dy / 200)
                          .clamp(0.0, 1.0);
                    });
                  },
                  onVerticalDragEnd: (_) {
                    setState(() => _isDraggingBrightness = false);
                  },
                  child: const SizedBox.expand(),
                ),
              ),
              // Center zone: horizontal drag seek
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: (_) {
                    setState(() {
                      _isSeeking = true;
                      _seekPosition = value.position;
                    });
                  },
                  onHorizontalDragUpdate: (details) {
                    if (duration.inMilliseconds > 0) {
                      final seekDelta = Duration(
                        milliseconds: (details.delta.dx *
                                duration.inMilliseconds /
                                MediaQuery.of(context).size.width)
                            .toInt(),
                      );
                      setState(() {
                        _seekPosition = (_seekPosition + seekDelta)
                            .clamp(Duration.zero, duration);
                      });
                    }
                  },
                  onHorizontalDragEnd: (_) {
                    widget.controller.seekTo(_seekPosition);
                    setState(() => _isSeeking = false);
                  },
                  child: const SizedBox.expand(),
                ),
              ),
              // Right zone: double-tap forward, vertical drag volume
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () => _seekForward(10),
                  onVerticalDragUpdate: (details) {
                    setState(() {
                      _isDraggingVolume = true;
                      _dragValue = (_dragValue - details.delta.dy / 200)
                          .clamp(0.0, 1.0);
                    });
                    widget.controller.setVolume(_dragValue);
                  },
                  onVerticalDragEnd: (_) {
                    setState(() => _isDraggingVolume = false);
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),

          // Left seek ripple
          if (_leftSeekCount > 0)
            Positioned(
              left: 40,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.fast_rewind, color: Colors.white, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '${_leftSeekCount}s',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Right seek ripple
          if (_rightSeekCount > 0)
            Positioned(
              right: 40,
              top: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_rightSeekCount}s',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.fast_forward, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ),

          // Brightness indicator
          if (_isDraggingBrightness)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.brightness_6, color: Colors.white, size: 28),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: RotatedBox(
                        quarterTurns: -1,
                        child: LinearProgressIndicator(
                          value: _dragValue,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Volume indicator
          if (_isDraggingVolume)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.volume_up, color: Colors.white, size: 28),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: RotatedBox(
                        quarterTurns: -1,
                        child: LinearProgressIndicator(
                          value: _dragValue,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Seek position indicator
          if (_isSeeking)
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatDuration(_seekPosition),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // Controls overlay
          AnimatedOpacity(
            opacity: _showControls ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_showControls,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.0, 0.25, 0.75, 1.0],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Top bar
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back,
                                  color: Colors.white),
                              onPressed: widget.onBack,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (widget.subtitle != null)
                                    Text(
                                      widget.subtitle!,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (Platform.isAndroid)
                              IconButton(
                                icon: const Icon(
                                  Icons.picture_in_picture_alt,
                                  color: Colors.white,
                                ),
                                onPressed: _enterPip,
                                tooltip: 'Picture-in-Picture',
                              ),
                            IconButton(
                              icon: Icon(
                                _orientationLocked
                                    ? Icons.screen_lock_rotation
                                    : Icons.screen_rotation,
                                color: Colors.white,
                              ),
                              onPressed: _toggleOrientationLock,
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Center play/pause
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 40,
                            icon: const Icon(Icons.replay_10,
                                color: Colors.white),
                            onPressed: () => _seekBackward(10),
                          ),
                          const SizedBox(width: 24),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              iconSize: 48,
                              icon: Icon(
                                isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                              ),
                              onPressed: _togglePlay,
                            ),
                          ),
                          const SizedBox(width: 24),
                          IconButton(
                            iconSize: 40,
                            icon: const Icon(Icons.forward_10,
                                color: Colors.white),
                            onPressed: () => _seekForward(10),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Bottom bar
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            // Progress bar
                            Row(
                              children: [
                                Text(
                                  _formatDuration(position),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        trackHeight: 3,
                                        thumbShape:
                                            const RoundSliderThumbShape(
                                                enabledThumbRadius: 6),
                                        activeTrackColor:
                                            AppTheme.primaryColor,
                                        inactiveTrackColor: Colors.white24,
                                        thumbColor: AppTheme.primaryColor,
                                        overlayColor: AppTheme.primaryColor
                                            .withOpacity(0.2),
                                      ),
                                      child: Slider(
                                        value: duration.inMilliseconds > 0
                                            ? position.inMilliseconds
                                                .toDouble()
                                                .clamp(
                                                    0,
                                                    duration.inMilliseconds
                                                        .toDouble())
                                            : 0,
                                        max: duration.inMilliseconds > 0
                                            ? duration.inMilliseconds
                                                .toDouble()
                                            : 1,
                                        onChanged: (v) {
                                          widget.controller.seekTo(
                                              Duration(
                                                  milliseconds: v.toInt()));
                                        },
                                        onChangeStart: (_) {
                                          _hideTimer?.cancel();
                                        },
                                        onChangeEnd: (_) {
                                          _resetHideTimer();
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),

                            // Bottom actions
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                // Speed selector
                                GestureDetector(
                                  onTap: _showSpeedSelector,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.white54),
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${_currentSpeed}x',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (widget.onNextEpisode != null)
                                      IconButton(
                                        icon: const Icon(
                                            Icons.skip_next_rounded,
                                            color: Colors.white),
                                        onPressed: widget.onNextEpisode,
                                        tooltip: 'Prossimo episodio',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Skip intro button
          if (showSkipIntro && _showControls)
            Positioned(
              bottom: 100,
              right: 24,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.9),
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                icon: const Icon(Icons.skip_next, size: 20),
                label: const Text('Salta Intro'),
                onPressed: () {
                  widget.controller.seekTo(
                      Duration(seconds: widget.skipIntroDuration));
                },
              ),
            ),
        ],
      ),
    );
  }
}

extension _DurationClamp on Duration {
  Duration clamp(Duration min, Duration max) {
    if (this < min) return min;
    if (this > max) return max;
    return this;
  }
}
