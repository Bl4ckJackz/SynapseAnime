import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';

class ExternalStreamScreen extends ConsumerStatefulWidget {
  const ExternalStreamScreen({super.key});

  @override
  ConsumerState<ExternalStreamScreen> createState() => _ExternalStreamScreenState();
}

class _ExternalStreamScreenState extends ConsumerState<ExternalStreamScreen> {
  final TextEditingController _linkController = TextEditingController();
  VideoPlayerController? _controller;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _controller?.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _loadVideoFromLink() async {
    final link = _linkController.text.trim();
    if (link.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Validate the URL
      if (!link.startsWith('http')) {
        throw Exception('URL deve iniziare con http:// o https://');
      }

      // Dispose of previous controller if exists
      if (_controller != null) {
        await _controller!.dispose();
      }

      // Initialize video player controller
      _controller = VideoPlayerController.network(link);

      // Add error listener to handle playback errors
      _controller!.addListener(() {
        if (_controller!.value.hasError) {
          setState(() {
            _error = _controller!.value.errorDescription;
            _isLoading = false;
          });
        }
      });

      await _controller!.initialize();
      await _controller!.play();
      await _controller!.setLooping(true);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Streaming Esterno'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Input section
            Card(
              color: AppTheme.cardColor,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _linkController,
                      decoration: const InputDecoration(
                        labelText: 'Link Video',
                        hintText: 'Incolla il link del video qui...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _loadVideoFromLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : const Text(
                                'Carica Video',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Error message
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.2),
                  border: Border.all(color: AppTheme.errorColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Errore:',
                      style: TextStyle(
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _error!,
                      style: const TextStyle(color: AppTheme.errorColor),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Video player
            if (_controller != null && _controller!.value.isInitialized)
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              )
            else if (!_isLoading)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.textMuted,
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.videocam,
                    size: 80,
                    color: Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _controller != null && _controller!.value.isPlaying
          ? FloatingActionButton(
              onPressed: () {
                if (_controller!.value.isPlaying) {
                  _controller!.pause();
                } else {
                  _controller!.play();
                }
                setState(() {});
              },
              backgroundColor: AppTheme.primaryColor,
              child: Icon(
                _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            )
          : null,
    );
  }
}