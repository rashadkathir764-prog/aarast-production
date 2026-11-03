/// D84: what build this is, for the connection report. The commit comes
/// from `--dart-define=AARAST_BUILD_COMMIT=<short sha>` at build time; a
/// build without it is a development build.
class BuildInfo {
  const BuildInfo._();

  static const commit = String.fromEnvironment('AARAST_BUILD_COMMIT');

  static const environment = String.fromEnvironment(
    'AARAST_ENVIRONMENT',
    defaultValue: 'development',
  );

  /// «نسخة a9b62ae5» or «نسخة تطوير».
  static String get label =>
      commit.trim().isEmpty ? 'نسخة تطوير' : 'نسخة ${commit.trim()}';
}
