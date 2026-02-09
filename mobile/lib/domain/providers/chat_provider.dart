import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/chat_message.dart';
import '../../data/repositories/repositories.dart';

final chatProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMessage>>((ref) {
  return ChatNotifier(ref.watch(aiRepositoryProvider));
});

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final AiRepository _repository;
  bool _isLoading = false;

  ChatNotifier(this._repository) : super([]) {
    // Add initial welcome message
    state = [
      ChatMessage.ai(
        'Ciao! Sono il tuo assistente anime. Dimmi cosa ti piace o chiedimi un consiglio!',
      ),
    ];
  }

  bool get isLoading => _isLoading;

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    // Add user message immediately
    state = [...state, ChatMessage.user(text)];
    _isLoading = true;

    try {
      // Get AI response
      final responseContent = await _repository.sendChatMessage(
        state
            .map((m) =>
                {'role': m.isUser ? 'user' : 'assistant', 'content': m.content})
            .toList(),
      );

      // Add AI response message
      state = [
        ...state,
        ChatMessage.ai(responseContent),
      ];
    } catch (e) {
      state = [
        ...state,
        ChatMessage.ai('Scusa, ho avuto un problema. Riprova più tardi.'),
      ];
    } finally {
      _isLoading = false;
    }
  }
}
