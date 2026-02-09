import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../domain/providers/comment_provider.dart';

/// X.com-style comment section with floating input
class CommentSection extends ConsumerStatefulWidget {
  final String? animeId;
  final String? mangaId;
  final String? episodeId;

  const CommentSection({
    super.key,
    this.animeId,
    this.mangaId,
    this.episodeId,
  });

  @override
  ConsumerState<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends ConsumerState<CommentSection> {
  final _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _selectedRating = 0;
  bool _isExpanded = false;

  CommentFilter get _params => CommentFilter(
        animeId: widget.animeId,
        mangaId: widget.mangaId,
        episodeId: widget.episodeId,
      );

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final success =
        await ref.read(commentsProvider(_params).notifier).addComment(
              text: _commentController.text.trim(),
              rating: _selectedRating > 0 ? _selectedRating : null,
            );

    if (success && mounted) {
      _commentController.clear();
      setState(() {
        _selectedRating = 0;
        _isExpanded = false;
      });
      _focusNode.unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Commento pubblicato!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Errore durante l\'invio del commento'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsState = ref.watch(commentsProvider(_params));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_outline,
                  color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Commenti',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${commentsState.comments.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // X.com-style Comment Input (always visible at top)
        _buildCommentInput(commentsState.isSubmitting),

        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),

        // Comments list
        _buildCommentsList(commentsState),
      ],
    );
  }

  Widget _buildCommentInput(bool isSubmitting) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isExpanded ? AppTheme.primaryColor : AppTheme.cardColor,
          width: _isExpanded ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Main input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // User avatar
              Padding(
                padding: const EdgeInsets.all(12),
                child: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  radius: 18,
                  child:
                      const Icon(Icons.person, color: Colors.white, size: 18),
                ),
              ),
              // Text field
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Scrivi un commento...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  maxLines: _isExpanded ? 3 : 1,
                  style: const TextStyle(fontSize: 15),
                  onTap: () {
                    setState(() => _isExpanded = true);
                  },
                ),
              ),
              // Send button (always visible)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: isSubmitting
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: Icon(
                          Icons.send_rounded,
                          color: _commentController.text.isNotEmpty
                              ? AppTheme.primaryColor
                              : Colors.grey,
                        ),
                        onPressed: _commentController.text.isNotEmpty
                            ? _submitComment
                            : null,
                      ),
              ),
            ],
          ),

          // Expanded options (rating)
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text(
                    'Valutazione:',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 8),
                  ...List.generate(5, (index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedRating =
                              _selectedRating == index + 1 ? 0 : index + 1;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          index < _selectedRating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 22,
                        ),
                      ),
                    );
                  }),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isExpanded = false;
                        _selectedRating = 0;
                      });
                      _focusNode.unfocus();
                    },
                    child:
                        const Text('Annulla', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentsList(CommentsState commentsState) {
    // Handle different states without infinite spinner
    if (commentsState.error != null) {
      return _buildErrorState(commentsState.error!);
    }

    if (commentsState.isLoading && commentsState.comments.isEmpty) {
      // Only show loading if we're loading for the first time
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Caricamento commenti...',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    if (commentsState.comments.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: commentsState.comments
          .map((comment) => _CommentCard(comment: comment))
          .toList(),
    );
  }

  Widget _buildErrorState(String error) {
    // Check if it's a 404 or connection error - treat as empty
    if (error.contains('404') || error.contains('SocketException')) {
      return _buildEmptyState();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.cloud_off, color: Colors.grey, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Impossibile caricare i commenti',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () =>
                  ref.read(commentsProvider(_params).notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.forum_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'Nessun commento ancora',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sii il primo a condividere la tua opinione!',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final Comment comment;

  const _CommentCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            backgroundColor: AppTheme.accentColor,
            radius: 18,
            child: Text(
              (comment.userName ?? 'U')[0].toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Text(
                      comment.userName ?? 'Utente',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimeAgo(comment.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    if (comment.rating != null) ...[
                      const Spacer(),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < comment.rating!
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 12,
                          );
                        }),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Text
                Text(
                  comment.text,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                // Replies
                if (comment.replies.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.only(left: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.grey[700]!, width: 2),
                      ),
                    ),
                    child: Column(
                      children: comment.replies
                          .map((reply) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          reply.userName ?? 'Utente',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatTimeAgo(reply.createdAt),
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      reply.text,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}a';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}m';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}g';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}min';
    } else {
      return 'ora';
    }
  }
}
