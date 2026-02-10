import 'package:dio/dio.dart';
import '../../../../core/constants.dart';
import '../../../../domain/entities/user.dart';
import '../../../../data/api_client.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthRepository {
  final ApiClient _apiClient;
  GoogleSignIn? _googleSignIn;

  AuthRepository(this._apiClient);

  /// Lazy initialization of GoogleSignIn to prevent web startup errors
  GoogleSignIn get googleSignIn {
    _googleSignIn ??= GoogleSignIn(
      scopes: ['email', 'profile'],
    );
    return _googleSignIn!;
  }

  Future<User> login(String email, String password) async {
    try {
      final response = await _apiClient.post(
        AppConstants.authLogin,
        data: {'email': email, 'password': password},
      );
      return await _processAuthResponse(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<User> register(String nickname, String email, String password) async {
    try {
      final response = await _apiClient.post(
        AppConstants.authRegister,
        data: {'nickname': nickname, 'email': email, 'password': password},
      );
      return await _processAuthResponse(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<User> loginWithGoogle() async {
    try {
      // On web, we should try silent sign-in first or ensure the popup flow is triggered by a user action
      GoogleSignInAccount? googleUser;

      try {
        // Attempt silent sign-in first
        googleUser = await googleSignIn.signInSilently();
      } catch (e) {
        // Silent sign-in failed, proceed to standard sign-in
      }

      // If silent failed or wasn't tried, use interactive sign-in
      googleUser ??= await googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google Sign In aborted');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Google ID Token not found');
      }

      final response = await _apiClient.post(
        '${AppConstants.authBase}/google',
        data: {'token': idToken},
      );

      return await _processAuthResponse(response.data);
    } catch (e) {
      // Handle "popup_closed" specifically if needed, but generic error handler covers it
      throw _handleError(e);
    }
  }

  Future<User> getUserProfile() async {
    try {
      final response = await _apiClient.get(AppConstants.authProfile);
      return User.fromJson(response.data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    await _apiClient.clearToken();
    try {
      await _googleSignIn?.signOut();
    } catch (_) {}
  }

  Future<User> _processAuthResponse(Map<String, dynamic> data) async {
    if (data['access_token'] != null) {
      final token = data['access_token'];
      _apiClient.setToken(token);
      await _apiClient.saveToken(token);
    }
    return User.fromJson(data['user']);
  }

  Exception _handleError(dynamic error) {
    if (error is DioException) {
      return Exception(
          error.response?.data['message'] ?? 'Errore connessione server');
    }
    return Exception(error.toString());
  }
}
