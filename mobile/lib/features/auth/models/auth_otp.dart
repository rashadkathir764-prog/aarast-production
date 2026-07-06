import 'safe_user.dart';

class OtpRequestResult {
  const OtpRequestResult({
    required this.phone,
    required this.purpose,
    required this.expiresAt,
    required this.delivery,
    this.code,
    this.message,
  });

  factory OtpRequestResult.fromJson(Map<String, dynamic> json) {
    return OtpRequestResult(
      phone: json['phone']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
      expiresAt: DateTime.parse(json['expiresAt'].toString()),
      delivery: json['delivery']?.toString() ?? '',
      code: json['code']?.toString(),
      message: json['message']?.toString(),
    );
  }

  final String phone;
  final String purpose;
  final DateTime expiresAt;
  final String delivery;
  final String? code;
  final String? message;

  bool get isLocalDev => delivery == 'LOCAL_DEV' && code != null;

  String? get localDevMessage {
    if (!isLocalDev) return null;
    return message ?? 'رمز التحقق مؤقت للتجربة المحلية: $code';
  }
}

class OtpVerifyResult {
  const OtpVerifyResult({
    required this.verified,
    required this.phone,
    required this.purpose,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.refreshTokenExpiresAt,
  });

  factory OtpVerifyResult.fromJson(Map<String, dynamic> json) {
    return OtpVerifyResult(
      verified: json['verified'] == true,
      phone: json['phone']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
      user: json['user'] is Map<String, dynamic>
          ? SafeUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      accessToken: json['accessToken']?.toString(),
      refreshToken: json['refreshToken']?.toString(),
      refreshTokenExpiresAt: DateTime.tryParse(
        json['refreshTokenExpiresAt']?.toString() ?? '',
      ),
    );
  }

  final bool verified;
  final String phone;
  final String purpose;
  final SafeUser? user;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? refreshTokenExpiresAt;
}
