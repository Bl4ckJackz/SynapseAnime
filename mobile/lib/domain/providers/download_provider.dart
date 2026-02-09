import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../core/constants.dart';

enum DownloadStatus { pending, downloading, completed, failed, cancelled }

class Download {
  final String id;
  final String animeId;
  final String animeName;
  final String episodeId;
  final int episodeNumber;
  final String? episodeTitle;
  final DownloadStatus status;
  final int progress;
  final String? filePath;
  final String? fileName;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  final String? thumbnailPath;

  Download({
    required this.id,
    required this.animeId,
    required this.animeName,
    required this.episodeId,
    required this.episodeNumber,
    this.episodeTitle,
    required this.status,
    required this.progress,
    this.filePath,
    this.fileName,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
    this.thumbnailPath,
  });

  factory Download.fromJson(Map<String, dynamic> json) {
    return Download(
      id: json['id'],
      animeId: json['animeId'],
      animeName: json['animeName'],
      episodeId: json['episodeId'],
      episodeNumber: json['episodeNumber'],
      episodeTitle: json['episodeTitle'],
      status: _parseStatus(json['status']),
      progress: json['progress'] ?? 0,
      filePath: json['filePath'],
      fileName: json['fileName'],
      errorMessage: json['errorMessage'],
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      thumbnailPath: json['thumbnailPath'],
    );
  }

  static DownloadStatus _parseStatus(String? status) {
    switch (status) {
      case 'pending':
        return DownloadStatus.pending;
      case 'downloading':
        return DownloadStatus.downloading;
      case 'completed':
        return DownloadStatus.completed;
      case 'failed':
        return DownloadStatus.failed;
      case 'cancelled':
        return DownloadStatus.cancelled;
      default:
        return DownloadStatus.pending;
    }
  }
}

class DownloadState {
  final List<Download> queue;
  final List<Download> history;
  final bool isLoading;
  final String? error;

  const DownloadState({
    this.queue = const [],
    this.history = const [],
    this.isLoading = false,
    this.error,
  });

  DownloadState copyWith({
    List<Download>? queue,
    List<Download>? history,
    bool? isLoading,
    String? error,
  }) {
    return DownloadState(
      queue: queue ?? this.queue,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class DownloadNotifier extends StateNotifier<DownloadState> {
  final Ref ref;
  static const _storage = FlutterSecureStorage();

  DownloadNotifier(this.ref) : super(const DownloadState());

  Future<String?> _getAuthToken() async {
    return await _storage.read(key: AppConstants.accessTokenKey);
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> loadQueue({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true, error: null);
    }
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/download/queue'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final downloads = data.map((d) => Download.fromJson(d)).toList();
        state = state.copyWith(queue: downloads, isLoading: false);
      } else {
        throw Exception('Failed to load download queue');
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadHistory({int limit = 50}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/download/history?limit=$limit'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final downloads = data.map((d) => Download.fromJson(d)).toList();
        state = state.copyWith(history: downloads);
      }
    } catch (e) {
      // Silently fail for history
    }
  }

  Future<bool> downloadSeason(String animeId, int season,
      {String? source, String? title}) async {
    try {
      final headers = await _getHeaders();

      // Build query parameters
      final queryParams = <String, String>{};
      if (source != null) queryParams['source'] = source;
      if (title != null) queryParams['title'] = title;

      final queryString = queryParams.isNotEmpty
          ? '?${queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'
          : '';

      final uri = Uri.parse(
        '${AppConstants.apiBaseUrl}/download/season/$animeId/$season$queryString',
      );

      print('[DownloadProvider] POST $uri');
      print('[DownloadProvider] Headers: $headers');

      final response = await http.post(uri, headers: headers);

      print('[DownloadProvider] Response status: ${response.statusCode}');
      print('[DownloadProvider] Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        await loadQueue();
        return true;
      }
      return false;
    } catch (e) {
      print('[DownloadProvider] Error: $e');
      return false;
    }
  }

  Future<bool> downloadEpisode(String animeId, String episodeId,
      {String? source}) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(
        '${AppConstants.apiBaseUrl}/download/episode/$animeId/$episodeId${source != null ? '?source=$source' : ''}',
      );

      final response = await http.post(uri, headers: headers);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await loadQueue();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> cancelDownload(String downloadId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${AppConstants.apiBaseUrl}/download/$downloadId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        await loadQueue();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Downloads an episode directly from a stream URL
  Future<bool> downloadFromUrl({
    required String url,
    required String animeName,
    required int episodeNumber,
    String? episodeTitle,
  }) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${AppConstants.apiBaseUrl}/download/url');

      print('[DownloadProvider] POST $uri');
      print(
          '[DownloadProvider] Body: url=$url, animeName=$animeName, episodeNumber=$episodeNumber');

      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode({
          'url': url,
          'animeName': animeName,
          'episodeNumber': episodeNumber,
          'episodeTitle': episodeTitle,
        }),
      );

      print('[DownloadProvider] Response status: ${response.statusCode}');
      print('[DownloadProvider] Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        await loadQueue();
        return true;
      }
      return false;
    } catch (e) {
      print('[DownloadProvider] Error: $e');
      return false;
    }
  }
}

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  return DownloadNotifier(ref);
});
