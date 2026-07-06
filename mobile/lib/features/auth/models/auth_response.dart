import 'safe_user.dart';

class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    this.refreshToken,
    this.refreshTokenExpiresAt,
    required this.user,
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
    final normalizedRefreshToken =
        refreshToken is String && refreshToken.trim().isNotEmpty
        ? refreshToken
        : null;
    final expiresAt = refreshTokenExpiresAt == null
        ? null
        : DateTime.tryParse(refreshTokenExpiresAt.toString());
    if (normalizedRefreshToken != null && expiresAt == null) {
      throw const FormatException('Missing refreshTokenExpiresAt');
    }

    return AuthResponse(
      accessToken: accessToken,
      refreshToken: normalizedRefreshToken,
      refreshTokenExpiresAt: expiresAt,
      user: SafeUser.fromJson(Map<String, dynamic>.from(user)),
    );
  }

  final String accessToken;
  final String? refreshToken;
  final DateTime? refreshTokenExpiresAt;
  final SafeUser user;
}
