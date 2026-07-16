import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rapid reissue calls rotate one invite token only once', () async {
    final api = _DelayedReissueApi();
    final provider = SharingProvider(api);
    final invite = _invite(token: 'identity-token');

    final first = provider.reissueInvite(invite);
    final second = provider.reissueInvite(invite);

    expect(api.calls, 1);
    api.complete(_invite(token: 'new-raw-token'));
    final results = await Future.wait([first, second]);

    expect(results[0]?.token, 'new-raw-token');
    expect(results[1]?.token, 'new-raw-token');
    expect(api.calls, 1);
  });
}

class _DelayedReissueApi extends SharingApi {
  _DelayedReissueApi() : super(ApiClient(tokenProvider: () async => 'token'));

  Completer<PlanInvite> _completer = Completer<PlanInvite>();
  int calls = 0;

  @override
  Future<PlanInvite> reissuePlanInvite({
    required String weddingPlanId,
    required String inviteId,
  }) {
    calls += 1;
    return _completer.future;
  }

  void complete(PlanInvite invite) {
    _completer.complete(invite);
    _completer = Completer<PlanInvite>();
  }
}

PlanInvite _invite({required String token}) {
  return PlanInvite(
    id: 'invite-1',
    weddingPlanId: 'plan-1',
    token: token,
    role: 'VIEWER',
    status: 'PENDING',
    expiresAt: DateTime.utc(2026, 8),
    canViewMoney: false,
    canEditPlan: false,
    canManageTasks: false,
    canManageGuests: false,
    canManageProviders: false,
    canInviteMembers: false,
    canManageMoney: false,
  );
}
