import 'package:flutter/foundation.dart';
import '../constants.dart';

class ImageUtils {
  static String getProxiedUrl(String url, {Map<String, String>? headers}) {
    if (kIsWeb) {
      final uri =
          Uri.parse('${AppConstants.consumetBaseUrl}/utils/image-proxy');
      final queryParameters = Map<String, dynamic>.from(uri.queryParameters);
      queryParameters['url'] = url;
      if (headers != null) {
        // Simple JSON encoding for headers if needed,
        // but for now let's just pass the url as the backend handles basic headers.
        // If we need custom headers like Referer passed from the app, we can add them here.
        // queryParameters['headers'] = jsonEncode(headers);
      }
      return uri.replace(queryParameters: queryParameters).toString();
    }
    return url;
  }

  static String getRefererForSource(String source) {
    switch (source.toLowerCase()) {
      case 'mangaworld':
        return 'https://mangaworld.mx/';
      case 'mangakatana':
        return 'https://mangakatana.com/';
      case 'comick':
        return 'https://comick.io/';
      case 'mangahere':
        return 'https://www.mangahere.cc/';
      case 'mangapill':
        return 'https://mangapill.com/';
      case 'asurascans':
        return 'https://asuracomic.net/';
      case 'weebcentral':
        return 'https://weebcentral.com/';
      case 'mangadex':
        return 'https://mangadex.org/';
      default:
        return 'https://google.com/';
    }
  }
}
