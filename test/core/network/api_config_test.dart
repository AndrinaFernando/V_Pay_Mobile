import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpay_mobile/core/network/api_config.dart';

void main() {
  const configuredUrl = String.fromEnvironment('VPAY_API_BASE_URL');

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('desktop and iOS simulator default to localhost', () {
    for (final platform in [
      TargetPlatform.windows,
      TargetPlatform.macOS,
      TargetPlatform.linux,
      TargetPlatform.iOS,
    ]) {
      debugDefaultTargetPlatformOverride = platform;
      expect(
        ApiConfig.baseUrl,
        configuredUrl.isNotEmpty ? configuredUrl : 'http://localhost:3000',
      );
    }
  });

  test('Android defaults to emulator host unless overridden', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(
      ApiConfig.baseUrl,
      configuredUrl.isNotEmpty ? configuredUrl : 'http://10.0.2.2:3000',
    );
  });

  test('explicit backend URL overrides every platform', () {
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      expect(ApiConfig.baseUrl, configuredUrl);
    }
  }, skip: configuredUrl.isEmpty ? 'Run with VPAY_API_BASE_URL defined' : null);
}
