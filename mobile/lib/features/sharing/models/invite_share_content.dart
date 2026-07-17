import '../../../core/routing/app_router.dart';
import 'shared_member.dart';

/// The one-time share payload built from the raw token returned when an invite
/// is created. It must stay in memory and must never be persisted or logged.
class InviteShareContent {
  InviteShareContent({required this.token}) {
    if (!_inviteTokenPattern.hasMatch(token.trim())) {
      throw const FormatException('Invalid invite token');
    }
  }

  factory InviteShareContent.fromInvite(PlanInvite invite) {
    return InviteShareContent(token: invite.token);
  }

  final String token;

  Uri get inviteLink => AppRouter.inviteHttpsLink(token.trim());
}

final RegExp _inviteTokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');
