import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  static const String _configuredUrl = String.fromEnvironment(
    'VPAY_API_BASE_URL',
  );

  static String get baseUrl {
    if (kReleaseMode) {
      final url = Uri.tryParse(_configuredUrl);
      if (url == null ||
          url.scheme != 'https' ||
          url.host.isEmpty ||
          const {'localhost', '127.0.0.1', '10.0.2.2'}.contains(url.host)) {
        throw StateError(
          'A reachable HTTPS VPAY_API_BASE_URL is required for release.',
        );
      }
    }
    if (_configuredUrl.isNotEmpty) return _configuredUrl;
    if (kIsWeb) return 'http://localhost:3000';
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:3000'
        : 'http://localhost:3000';
  }
}
