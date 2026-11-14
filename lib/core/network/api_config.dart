class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'VPAY_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}
