import 'safe_user.dart';

class OtpRequestResult {
  const OtpRequestResult({
    required this.phone,
    required this.purpose,
    required this.expiresAt,
    required this.delivery,
    this.deliveryStatus = 'PENDING',
    this.code,
    this.message,
  });

  factory OtpRequestResult.fromJson(Map<String, dynamic> json) {
    return OtpRequestResult(
      phone: json['phone']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
      expiresAt: DateTime.parse(json['expiresAt'].toString()),
      delivery: json['delivery']?.toString() ?? '',
      deliveryStatus:
          json['deliveryStatus']?.toString() ??
          (json['delivery'] == 'LOCAL_DEV' ? 'LOCAL_DEV' : 'PENDING'),
      code: json['code']?.toString(),
      message: json['message']?.toString(),
    );
  }

  final String phone;
  final String purpose;
  final DateTime expiresAt;
  final String delivery;
  final String deliveryStatus;
  final String? code;
  final String? message;

  bool get isLocalDev => delivery == 'LOCAL_DEV' && code != null;
  bool get isDeliveryConfirmed => deliveryStatus == 'DELIVERED';

  String? get noticeMessage {
    if (isLocalDev) {
      return message ?? 'رمز التحقق مؤقت للتجربة المحلية: $code';
    }
    final normalized = message?.trim();
    if (!isDeliveryConfirmed) {
      if (normalized != null &&
          normalized.isNotEmpty &&
          !_containsUnconfirmedDeliveryClaim(normalized)) {
        return normalized;
      }
      return 'طلبنا إرسال الرمز عبر واتساب، لكن لم نتأكد من وصوله. '
          'أدخله إذا وصلك، أو أعد المحاولة بعد انتهاء المهلة.';
    }
    if (normalized != null && normalized.isNotEmpty) return normalized;
    return null;
  }
}

bool _containsUnconfirmedDeliveryClaim(String message) {
  final normalized = message.toLowerCase();
  return const [
    'تم إرسال',
    'تم الإرسال',
    'تم تسليم',
    'أرسلنا',
    'sent',
    'delivered',
  ].any(normalized.contains);
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
