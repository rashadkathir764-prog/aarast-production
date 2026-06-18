import 'safe_user.dart';

class AuthResponse {
  const AuthResponse({required this.accessToken, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final accessToken = json['accessToken'];
    final user = json['user'];
    if (accessToken is! String || accessToken.trim().isEmpty) {
      throw const FormatException('Missing accessToken');
    }
    if (user is! Map) {
      throw const FormatException('Missing user');
    }

    return AuthResponse(
      accessToken: accessToken,
      user: SafeUser.fromJson(Map<String, dynamic>.from(user)),
    );
  }

  final String accessToken;
  final SafeUser user;
}
