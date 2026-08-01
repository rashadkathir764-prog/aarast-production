import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SharingProvider invite response hardening', () {
    test('concurrent and repeated accept calls perform one mutation', () async {
      final api = _ControlledAcceptApi();
      final provider = SharingProvider(api);

      final first = provider.respondToInvite('invite-1', accept: true);
      final second = provider.respondToInvite('invite-1', accept: true);

      expect(api.acceptCalls, 1);

      api.completeAccept(_acceptedResult('invite-1'));
      expect(await Future.wait([first, second]), [isTrue, isTrue]);
      expect(provider.selectedInvite?.isAccepted, isTrue);
      expect(provider.selectedInvite?.hasActiveMembership, isTrue);
      expect(provider.selectedInvite?.contextKey, 'plan:plan-1:contributor');
      expect(provider.acceptedInviteContextKey, 'plan:plan-1:contributor');

      expect(await provider.respondToInvite('invite-1', accept: true), isTrue);
      expect(api.acceptCalls, 1);
    });

    for (final entry in <String, ApiException>{
      'an ambiguous network failure': const ApiException(
        'connection lost',
        isNetworkFailure: true,
      ),
      'an already-accepted conflict': const ApiException(
        'Invite has already been accepted',
        statusCode: 409,
      ),
    }.entries) {
      test('${entry.key} reconciles through the invite detail', () async {
        final api = _FailedAcceptApi(
          acceptFailure: entry.value,
          observedInvite: _invite(id: 'invite-1', status: 'ACCEPTED'),
        );
        final provider = SharingProvider(api);

        final accepted = await provider.respondToInvite(
          'invite-1',
          accept: true,
        );

        expect(accepted, isTrue);
        expect(api.acceptCalls, 1);
        expect(api.getInviteCalls, 1);
        expect(provider.selectedInvite?.isAccepted, isTrue);
        expect(provider.acceptedInviteContextKey, 'plan:plan-1:contributor');
        expect(provider.errorMessage, isNull);
      });
    }

    test(
      'a malformed accept response reconciles instead of escaping uncaught',
      () async {
        final api = _FailedAcceptApi(
          acceptFailure: const FormatException('missing contextKey'),
          observedInvite: _invite(id: 'invite-1', status: 'ACCEPTED'),
        );
        final provider = SharingProvider(api);

        final accepted = await provider.respondToInvite(
          'invite-1',
          accept: true,
        );

        expect(accepted, isTrue);
        expect(api.getInviteCalls, 1);
        expect(provider.selectedInvite?.isAccepted, isTrue);
        expect(provider.errorMessage, isNull);
      },
    );

    test('an invite parsing failure becomes provider error state', () async {
      final provider = SharingProvider(_MalformedInviteApi());

      await expectLater(provider.loadInvite('invite-1'), completes);

      expect(provider.selectedInvite, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNotEmpty);
    });

    test(
      'concurrent and repeated decline calls perform one mutation',
      () async {
        final api = _ControlledDeclineApi();
        final provider = SharingProvider(api);

        final first = provider.respondToInvite('invite-1', accept: false);
        final second = provider.respondToInvite('invite-1', accept: false);

        expect(api.declineCalls, 1);

        api.completeDecline(_invite(id: 'invite-1', status: 'DECLINED'));
        expect(await Future.wait([first, second]), [isTrue, isTrue]);
        expect(provider.selectedInvite?.isDeclined, isTrue);

        expect(
          await provider.respondToInvite('invite-1', accept: false),
          isTrue,
        );
        expect(api.declineCalls, 1);
      },
    );

    test(
      'an opposite invite decision cannot race an in-flight decision',
      () async {
        final api = _ControlledDecisionApi();
        final provider = SharingProvider(api);

        final accepting = provider.respondToInvite('invite-1', accept: true);
        final declining = await provider.respondToInvite(
          'invite-1',
          accept: false,
        );

        expect(declining, isFalse);
        expect(api.acceptCalls, 1);
        expect(api.declineCalls, 0);
        expect(provider.isSubmitting, isTrue);

        api.completeAccept(_acceptedResult('invite-1'));
        expect(await accepting, isTrue);
        expect(provider.isSubmitting, isFalse);
      },
    );

    for (final entry in <String, ApiException>{
      'an ambiguous decline failure': const ApiException(
        'connection lost',
        isNetworkFailure: true,
      ),
      'an already-declined conflict': const ApiException(
        'Invite has already been declined',
        statusCode: 409,
      ),
    }.entries) {
      test('${entry.key} reconciles to DECLINED', () async {
        final api = _FailedDeclineApi(
          declineFailure: entry.value,
          observedInvite: _invite(id: 'invite-1', status: 'DECLINED'),
        );
        final provider = SharingProvider(api);

        final declined = await provider.respondToInvite(
          'invite-1',
          accept: false,
        );

        expect(declined, isTrue);
        expect(api.declineCalls, 1);
        expect(api.getInviteCalls, 1);
        expect(provider.selectedInvite?.status, 'DECLINED');
        expect(provider.acceptedInviteContextKey, isNull);
        expect(provider.errorMessage, isNull);
      });
    }
  });

  test('loadMyInvites ignores a result from an older request', () async {
    final api = _ControlledInviteLoadApi();
    final provider = SharingProvider(api);

    final older = provider.loadMyInvites(token: 'old-token');
    final newer = provider.loadMyInvites(token: 'new-token');

    api.complete('old-token', _invite(id: 'old-invite', token: 'old-token'));
    await older;

    expect(provider.isLoading, isTrue);
    expect(provider.myInvites, isEmpty);
    expect(provider.selectedInvite, isNull);

    api.complete('new-token', _invite(id: 'new-invite', token: 'new-token'));
    await newer;

    expect(provider.isLoading, isFalse);
    expect(provider.myInvites.single.id, 'new-invite');
    expect(provider.selectedInvite?.id, 'new-invite');
    expect(provider.errorMessage, isNull);
  });

  test('loadAccess ignores a result from an older plan request', () async {
    final api = _ControlledAccessApi();
    final provider = SharingProvider(api);

    final older = provider.loadAccess('plan-old');
    final newer = provider.loadAccess('plan-new');

    api.complete(
      'plan-new',
      const PlanAccessPermissions.owner(weddingPlanId: 'plan-new'),
    );
    expect(await newer, isTrue);
    expect(provider.access.weddingPlanId, 'plan-new');
    expect(provider.access.canManageMembers, isTrue);

    api.complete(
      'plan-old',
      const PlanAccessPermissions.denied(weddingPlanId: 'plan-old'),
    );
    expect(await older, isFalse);
    expect(provider.access.weddingPlanId, 'plan-new');
    expect(provider.access.canManageMembers, isTrue);
  });
}

class _ControlledAcceptApi extends SharingApi {
  _ControlledAcceptApi()
    : super(ApiClient(tokenProvider: () async => 'access-token'));

  final Completer<AcceptedPlanInvite> _accept = Completer<AcceptedPlanInvite>();
  int acceptCalls = 0;

  @override
  Future<AcceptedPlanInvite> acceptInvite(String token) {
    acceptCalls += 1;
    return _accept.future;
  }

  void completeAccept(AcceptedPlanInvite result) {
    _accept.complete(result);
  }
}

class _FailedAcceptApi extends SharingApi {
  _FailedAcceptApi({required this.acceptFailure, required this.observedInvite})
    : super(ApiClient(tokenProvider: () async => 'access-token'));

  final Object acceptFailure;
  final PlanInvite observedInvite;
  int acceptCalls = 0;
  int getInviteCalls = 0;

  @override
  Future<AcceptedPlanInvite> acceptInvite(String token) async {
    acceptCalls += 1;
    throw acceptFailure;
  }

  @override
  Future<PlanInvite> getInvite(String token) async {
    getInviteCalls += 1;
    return observedInvite;
  }
}

class _ControlledDeclineApi extends SharingApi {
  _ControlledDeclineApi()
    : super(ApiClient(tokenProvider: () async => 'access-token'));

  final Completer<PlanInvite> _decline = Completer<PlanInvite>();
  int declineCalls = 0;

  @override
  Future<PlanInvite> declineInvite(String token) {
    declineCalls += 1;
    return _decline.future;
  }

  void completeDecline(PlanInvite invite) {
    _decline.complete(invite);
  }
}

class _ControlledDecisionApi extends SharingApi {
  _ControlledDecisionApi()
    : super(ApiClient(tokenProvider: () async => 'access-token'));

  final Completer<AcceptedPlanInvite> _accept = Completer<AcceptedPlanInvite>();
  int acceptCalls = 0;
  int declineCalls = 0;

  @override
  Future<AcceptedPlanInvite> acceptInvite(String token) {
    acceptCalls += 1;
    return _accept.future;
  }

  @override
  Future<PlanInvite> declineInvite(String token) async {
    declineCalls += 1;
    return _invite(id: token, token: token, status: 'DECLINED');
  }

  void completeAccept(AcceptedPlanInvite result) {
    _accept.complete(result);
  }
}

class _FailedDeclineApi extends SharingApi {
  _FailedDeclineApi({
    required this.declineFailure,
    required this.observedInvite,
  }) : super(ApiClient(tokenProvider: () async => 'access-token'));

  final Object declineFailure;
  final PlanInvite observedInvite;
  int declineCalls = 0;
  int getInviteCalls = 0;

  @override
  Future<PlanInvite> declineInvite(String token) async {
    declineCalls += 1;
    throw declineFailure;
  }

  @override
  Future<PlanInvite> getInvite(String token) async {
    getInviteCalls += 1;
    return observedInvite;
  }
}

class _MalformedInviteApi extends SharingApi {
  _MalformedInviteApi()
    : super(ApiClient(tokenProvider: () async => 'access-token'));

  @override
  Future<PlanInvite> getInvite(String token) async {
    throw const FormatException('invalid invite payload');
  }
}

class _ControlledInviteLoadApi extends SharingApi {
  _ControlledInviteLoadApi()
    : super(ApiClient(tokenProvider: () async => 'access-token'));

  final Map<String, Completer<PlanInvite>> _requests = {};

  @override
  Future<PlanInvite> getInvite(String token) {
    final request = Completer<PlanInvite>();
    _requests[token] = request;
    return request.future;
  }

  void complete(String token, PlanInvite invite) {
    final request = _requests.remove(token);
    if (request == null) {
      throw StateError('No request is pending for $token');
    }
    request.complete(invite);
  }
}

class _ControlledAccessApi extends SharingApi {
  _ControlledAccessApi()
    : super(ApiClient(tokenProvider: () async => 'access-token'));

  final Map<String, Completer<PlanAccessPermissions>> _requests = {};

  @override
  Future<PlanAccessPermissions> getMyPlanPermissions(String weddingPlanId) {
    final request = Completer<PlanAccessPermissions>();
    _requests[weddingPlanId] = request;
    return request.future;
  }

  void complete(String planId, PlanAccessPermissions permissions) {
    final request = _requests.remove(planId);
    if (request == null) {
      throw StateError('No access request is pending for $planId');
    }
    request.complete(permissions);
  }
}

AcceptedPlanInvite _acceptedResult(String token) {
  final invite = _invite(
    id: token,
    token: token,
    status: 'ACCEPTED',
    withContextKey: false,
  );
  return AcceptedPlanInvite(
    invite: invite,
    member: SharedMember(
      id: 'member-1',
      weddingPlanId: 'plan-1',
      userId: 'user-1',
      role: 'VIEWER',
      canViewMoney: false,
      canManageTasks: false,
      canManageMoney: false,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
    contextKey: 'plan:plan-1:contributor',
  );
}

PlanInvite _invite({
  required String id,
  String? token,
  String status = 'PENDING',
  bool withContextKey = true,
}) {
  return PlanInvite(
    id: id,
    weddingPlanId: 'plan-1',
    token: token ?? id,
    contextKey: status == 'ACCEPTED' && withContextKey
        ? 'plan:plan-1:contributor'
        : null,
    role: 'VIEWER',
    status: status,
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
