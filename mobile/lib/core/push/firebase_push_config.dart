class FirebasePushConfig {
  const FirebasePushConfig._();

  static const apiKey = String.fromEnvironment('AARAST_FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('AARAST_FIREBASE_APP_ID');
  static const messagingSenderId = String.fromEnvironment(
    'AARAST_FIREBASE_MESSAGING_SENDER_ID',
  );
  static const projectId = String.fromEnvironment('AARAST_FIREBASE_PROJECT_ID');

  static bool get isConfigured =>
      apiKey.trim().isNotEmpty &&
      appId.trim().isNotEmpty &&
      messagingSenderId.trim().isNotEmpty &&
      projectId.trim().isNotEmpty;
}
