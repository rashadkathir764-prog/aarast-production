import '../../../core/experience_v3/aarast_journey_profile.dart'
    show ReaderVoice;
import '../../../core/session/safe_user.dart';

/// Which number and purpose this phone asked a code for, and when
/// (RA-MO-109): the number as typed.
typedef CodeRequestMark = ({String phone, String purpose, DateTime at});

/// The request left the phone and no answer came back: the code may be in
/// WhatsApp. Said alike to a man and a woman.
const otpLostAnswerNotice =
    'ما وصلنا رد، بس الرمز يمكن وصلك على واتساب. لو وصلك، هنا مكانه.';

/// A code asked again within the minute was refused, and the one this phone
/// asked for a moment ago is still good (RA-MO-109).
const otpEarlierCodeStillLiveNotice =
    'الرمز اللي طلبناه على هذا الرقم قبل أقل من دقيقة لسا شغال، '
    'وهنا مكانه لو وصلك.';

class OtpRequestResult {
  const OtpRequestResult({
    required this.phone,
    required this.purpose,
    required this.expiresAt,
    required this.delivery,
    this.deliveryStatus = 'PENDING',
    this.accountSetupRequired = false,
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
      accountSetupRequired: json['accountSetupRequired'] == true,
      code: json['code']?.toString(),
      message: json['message']?.toString(),
    );
  }

  final String phone;
  final String purpose;
  final DateTime expiresAt;
  final String delivery;
  final String deliveryStatus;
  final bool accountSetupRequired;
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
      return ReaderVoice.say(
        'طلبنا نرسل الرمز على واتساب، بس ما تأكدنا إنه وصل. '
            'اكتبه لو وصلك، أو اطلبه مرة ثانية لما يخلص الوقت.',
        'طلبنا نرسل الرمز على واتساب، بس ما تأكدنا إنه وصل. '
            'اكتبيه لو وصلك، أو اطلبيه مرة ثانية لما يخلص الوقت.',
      );
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
    final refreshTokenExpiresAt = DateTime.tryParse(
      json['refreshTokenExpiresAt']?.toString() ?? '',
    );
    if (json['refreshToken'] != null && refreshTokenExpiresAt == null) {
      throw const FormatException('Missing refreshTokenExpiresAt');
    }
    return OtpVerifyResult(
      verified: json['verified'] == true,
      phone: json['phone']?.toString() ?? '',
      purpose: json['purpose']?.toString() ?? '',
      user: json['user'] is Map<String, dynamic>
          ? SafeUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      accessToken: json['accessToken']?.toString(),
      refreshToken: json['refreshToken']?.toString(),
      refreshTokenExpiresAt: refreshTokenExpiresAt,
    );
  }

  final bool verified;
  final String phone;
  final String purpose;
  final SafeUser? user;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? refreshTokenExpiresAt;

  bool get hasDurableSession =>
      verified &&
      user != null &&
      accessToken?.trim().isNotEmpty == true &&
      refreshToken?.trim().isNotEmpty == true &&
      refreshTokenExpiresAt != null;
}
