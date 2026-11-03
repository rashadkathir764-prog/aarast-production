import '../../../core/session/safe_user.dart';

class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    this.refreshToken,
    this.refreshTokenExpiresAt,
    required this.user,
    this.existingAccount = false,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final accessToken = json['accessToken'];
    final refreshToken = json['refreshToken'];
    final refreshTokenExpiresAt = json['refreshTokenExpiresAt'];
    final user = json['user'];
    if (accessToken is! String || accessToken.trim().isEmpty) {
      throw const FormatException('Missing accessToken');
    }
    if (user is! Map) {
      throw const FormatException('Missing user');
    }
    if (refreshToken is! String || refreshToken.trim().isEmpty) {
      throw const FormatException('Missing refreshToken');
    }
    final expiresAt = DateTime.tryParse(
      refreshTokenExpiresAt?.toString() ?? '',
    );
    if (expiresAt == null) {
      throw const FormatException('Missing refreshTokenExpiresAt');
    }

    return AuthResponse(
      accessToken: accessToken,
      refreshToken: refreshToken,
      refreshTokenExpiresAt: expiresAt,
      user: SafeUser.fromJson(Map<String, dynamic>.from(user)),
      existingAccount: json['existingAccount'] == true,
    );
  }

  final String accessToken;
  final String? refreshToken;
  final DateTime? refreshTokenExpiresAt;
  final SafeUser user;

  /// D75: a sign-up code for a number that already has an account signs in
  /// to that account; this says it was not created now. [user] is then that
  /// account, so its name is the one the person is told.
  final bool existingAccount;
}
