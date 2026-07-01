class ApiConfig {
  const ApiConfig._();

  static const baseUrl = String.fromEnvironment(
    'AARAST_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3115',
  );
}
