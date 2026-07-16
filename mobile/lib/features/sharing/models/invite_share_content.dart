import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/routing/app_router.dart';
import 'shared_member.dart';

/// The one-time share payload built from the raw token returned when an invite
/// is created. It must stay in memory and must never be persisted or logged.
class InviteShareContent {
  InviteShareContent({
    required this.token,
    required this.recipientPhone,
    this.inviterName,
    this.weddingPlanTitle,
  }) {
    if (!_inviteTokenPattern.hasMatch(token.trim())) {
      throw const FormatException('Invalid invite token');
    }
  }

  factory InviteShareContent.fromInvite(PlanInvite invite) {
    return InviteShareContent(
      token: invite.token,
      recipientPhone: invite.phone ?? '',
      inviterName: invite.inviterName,
      weddingPlanTitle: invite.weddingPlanTitle,
    );
  }

  final String token;
  final String recipientPhone;
  final String? inviterName;
  final String? weddingPlanTitle;

  Uri get inviteLink => AppRouter.inviteHttpsLink(token.trim());

  String get message {
    final inviter = _cleanOrFallback(inviterName, 'صاحب الخطة');
    final plan = _cleanOrFallback(weddingPlanTitle, 'خطة الزفاف');
    return [
      'مرحبًا 👋',
      '',
      '$inviter دعاك عبر أعرست للمشاركة في $plan.',
      '',
      'افتح الرابط وتحقق من رقم هاتفك لعرض الدعوة:',
      inviteLink.toString(),
      '',
      'هذا الرابط خاص بك، لا تشاركه مع الآخرين.',
    ].join('\n');
  }

  Uri get whatsappUri {
    final normalizedPhone = normalizeYemeniPhone(recipientPhone);
    final digits = normalizedPhone.substring(1);
    return Uri.https('wa.me', '/$digits', {'text': message});
  }
}

final RegExp _inviteTokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

String _cleanOrFallback(String? value, String fallback) {
  final clean = value?.trim();
  return clean == null || clean.isEmpty ? fallback : clean;
}
