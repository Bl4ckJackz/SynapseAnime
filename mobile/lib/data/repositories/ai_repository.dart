import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/anime.dart';
import '../../core/constants.dart';
import '../api_client.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref.read(apiClientProvider));
});

class AiRepository {
  final ApiClient _apiClient;

  AiRepository(this._apiClient);

  Future<AiRecommendationResponse> getRecommendations(String message) async {
    try {
      final response = await _apiClient.post(
        AppConstants.aiRecommend,
        data: {'message': message},
      );

      // Check if response contains expected data
      if (response.data == null) {
        throw Exception('Empty response from AI service');
      }

      return AiRecommendationResponse.fromJson(
          response.data as Map<String, dynamic>);
    } catch (e) {
      // Log the error for debugging
      print('AI Repository Error: $e');
      // Return a default response in case of error
      return AiRecommendationResponse(
        message: 'Mi dispiace, sto avendo problemi temporanei. Riprova più tardi.',
        recommendations: [],
      );
    }
  }
}

class AiRecommendationResponse {
  final String message;
  final List<Anime> recommendations;

  AiRecommendationResponse({
    required this.message,
    required this.recommendations,
  });

  factory AiRecommendationResponse.fromJson(Map<String, dynamic> json) {
    return AiRecommendationResponse(
      message: json['message'] as String,
      recommendations: (json['recommendations'] as List<dynamic>)
          .map((e) => Anime.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
