import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import '../../data/api_client.dart';

class CommentFilter extends Equatable {
  final String? animeId;
  final String? mangaId;
  final String? episodeId;

  const CommentFilter({
    this.animeId,
    this.mangaId,
    this.episodeId,
  });

  @override
  List<Object?> get props => [animeId, mangaId, episodeId];
}

class Comment {
  final String id;
  final String userId;
  final String? userName;
  final String text;
  final int? rating;
  final String? animeId;
  final String? mangaId;
  final String? episodeId;
  final String? parentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Comment> replies;

  Comment({
    required this.id,
    required this.userId,
    this.userName,
    required this.text,
    this.rating,
    this.animeId,
    this.mangaId,
    this.episodeId,
    this.parentId,
    required this.createdAt,
    required this.updatedAt,
    this.replies = const [],
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName:
          (json['user'] as Map<String, dynamic>?)?['nickname'] as String? ??
              (json['user'] as Map<String, dynamic>?)?['email'] as String?,
      text: json['text'] as String,
      rating: json['rating'] as int?,
      animeId: json['animeId'] as String?,
      mangaId: json['mangaId'] as String?,
      episodeId: json['episodeId'] as String?,
      parentId: json['parentId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      replies: (json['replies'] as List<dynamic>?)
              ?.map((r) => Comment.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class CommentsState {
  final List<Comment> comments;
  final bool isLoading;
  final String? error;
  final bool isSubmitting;

  CommentsState({
    this.comments = const [],
    this.isLoading = false,
    this.error,
    this.isSubmitting = false,
  });

  CommentsState copyWith({
    List<Comment>? comments,
    bool? isLoading,
    String? error,
    bool? isSubmitting,
  }) {
    return CommentsState(
      comments: comments ?? this.comments,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class CommentsNotifier extends StateNotifier<CommentsState> {
  final ApiClient _apiClient;
  final String? animeId;
  final String? mangaId;
  final String? episodeId;

  CommentsNotifier(this._apiClient,
      {this.animeId, this.mangaId, this.episodeId})
      : super(CommentsState()) {
    load();
  }

  Future<void> load({int page = 1}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      String endpoint;
      if (animeId != null) {
        endpoint = '/comments/anime/$animeId?page=$page';
      } else if (mangaId != null) {
        endpoint = '/comments/manga/$mangaId?page=$page';
      } else if (episodeId != null) {
        endpoint = '/comments/episode/$episodeId?page=$page';
      } else {
        state = state.copyWith(isLoading: false);
        return;
      }

      final response = await _apiClient.get(endpoint);
      final List<dynamic> data = response.data as List<dynamic>;
      final comments =
          data.map((c) => Comment.fromJson(c as Map<String, dynamic>)).toList();
      state = state.copyWith(comments: comments, isLoading: false);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        state = state.copyWith(comments: [], isLoading: false, error: null);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load comments',
        );
      }
    }
  }

  Future<bool> addComment({
    required String text,
    int? rating,
    String? parentId,
  }) async {
    state = state.copyWith(
        isSubmitting:
            true); // Don't clear error here to preserve list state if needed
    try {
      final body = <String, dynamic>{
        'text': text,
        if (rating != null) 'rating': rating,
        if (animeId != null) 'animeId': animeId,
        if (mangaId != null) 'mangaId': mangaId,
        if (episodeId != null) 'episodeId': episodeId,
        if (parentId != null) 'parentId': parentId,
      };

      await _apiClient.post('/comments', data: body);
      state = state.copyWith(isSubmitting: false);

      // Reload comments
      await load();
      return true;
    } catch (e) {
      // Don't set state.error as it would replace the list with error view
      // Just stop submitting and return false
      state = state.copyWith(isSubmitting: false);
      return false;
    }
  }

  Future<bool> deleteComment(String commentId) async {
    try {
      await _apiClient.delete('/comments/$commentId');
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void refresh() => load();
}

// Provider that creates a CommentsNotifier for a specific target
final commentsProvider = StateNotifierProvider.family<CommentsNotifier,
    CommentsState, CommentFilter>(
  (ref, filter) {
    return CommentsNotifier(
      ref.read(apiClientProvider),
      animeId: filter.animeId,
      mangaId: filter.mangaId,
      episodeId: filter.episodeId,
    );
  },
);
