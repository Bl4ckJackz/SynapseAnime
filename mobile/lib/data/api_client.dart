import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';
import 'package:http/http.dart' as http;

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late final http.Client httpClient;

  ApiClient({http.Client? httpClient})
      : httpClient = httpClient ?? http.Client() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.apiBaseUrl,
        connectTimeout: AppConstants.connectionTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Add auth token if available
          final token = await _storage.read(key: AppConstants.accessTokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            print('ApiClient: Added Bearer token to ${options.path}');
          } else {
            print('ApiClient: NO TOKEN FOUND for ${options.path}');
          }
          print('ApiClient Headers: ${options.headers}');
          return handler.next(options);
        },
        onError: (error, handler) {
          print(
              'ApiClient Error [${error.response?.statusCode}] at ${error.requestOptions.path}: ${error.message}');
          // Handle 401 errors (token expired)
          if (error.response?.statusCode == 401) {
            // Could trigger logout here
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.get<T>(path, queryParameters: queryParameters);
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.post<T>(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.put<T>(path, data: data, queryParameters: queryParameters);
  }

  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return _dio.delete<T>(path, queryParameters: queryParameters);
  }

  // Auth token management
  Future<void> saveToken(String token) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: token);
  }

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<String?> getToken() async {
    return _storage.read(key: AppConstants.accessTokenKey);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
    _dio.options.headers.remove('Authorization');
  }
}
