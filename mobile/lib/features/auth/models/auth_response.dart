import 'safe_user.dart';

class AuthResponse {
  const AuthResponse({required this.accessToken, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'].toString(),
      user: SafeUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  final String accessToken;
  final SafeUser user;
}
