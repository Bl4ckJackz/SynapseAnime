import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Standardized API response parsing helpers.
/// Eliminates duplicated response.data parsing patterns across repositories.
class ApiHelpers {
  const ApiHelpers._();

  /// Parse a list response that may come as:
  /// - Direct `List<dynamic>`
  /// - Wrapped in `{ "data": [...] }`
  /// - Wrapped in `{ "results": [...] }`
  static List<dynamic> parseListResponse(dynamic data,
      {String dataKey = 'data'}) {
    if (data == null) return [];
    if (data is List) return data;
    if (data is Map) {
      final nested = data[dataKey] ?? data['results'] ?? data['data'];
      if (nested is List) return nested;
    }
    return [];
  }

  /// Parse list response and map each element through a factory.
  /// Safely handles type casting and skips malformed entries.
  static List<T> parseAndMap<T>(
    dynamic data,
    T Function(Map<String, dynamic>) factory, {
    String dataKey = 'data',
  }) {
    final list = parseListResponse(data, dataKey: dataKey);
    final results = <T>[];
    for (final item in list) {
      try {
        if (item is Map<String, dynamic>) {
          results.add(factory(item));
        } else if (item is Map) {
          results.add(factory(Map<String, dynamic>.from(item)));
        }
      } catch (e) {
        if (kDebugMode) debugPrint('ApiHelpers: Failed to parse item: $e');
      }
    }
    return results;
  }

  /// Safely extract a Map from response data, handling wrapper patterns.
  static Map<String, dynamic>? parseMapResponse(dynamic data,
      {String dataKey = 'data'}) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) {
      // Check if it's wrapped
      if (data.containsKey(dataKey) && data[dataKey] is Map) {
        return Map<String, dynamic>.from(data[dataKey] as Map);
      }
      return data;
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  /// Standard error logging with context.
  static void logError(String context, Object error) {
    if (kDebugMode) {
      final message = error is DioException
          ? '${error.type}: ${error.response?.statusCode} ${error.message}'
          : error.toString();
      debugPrint('[$context] Error: $message');
    }
  }

  /// Check if a DioException is a 404.
  static bool is404(Object error) {
    return error is DioException && error.response?.statusCode == 404;
  }

  /// Check if a DioException indicates a network/connection error.
  static bool isNetworkError(Object error) {
    if (error is! DioException) return false;
    return error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.receiveTimeout;
  }
}
