import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/edit_shared_member_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('SharingProvider plan isolation', () {
    test('clears the previous plan when the next plan load fails', () async {
      final api = _ControlledSharingApi();
      final provider = SharingProvider(api);

      final firstLoad = provider.loadMembers('plan-a');
      api.completeMembers('plan-a', [_member('plan-a', 'member-a', 'أمينة')]);
      api.completeInvites('plan-a', [_invite('plan-a', 'invite-a')]);
      await firstLoad;
      expect(provider.members.single.id, 'member-a');
      expect(provider.invites.single.id, 'invite-a');

      final failedLoad = provider.loadMembers('plan-b');
      expect(provider.members, isEmpty);
      expect(provider.invites, isEmpty);
      api.failMembers('plan-b');
      api.failInvites('plan-b');
      await failedLoad;

      expect(provider.members, isEmpty);
      expect(provider.invites, isEmpty);
      // J2-20: the sharing messages are Yemeni.
      expect(provider.errorMessage, 'ما قدرنا نجيب المشاركين.');
    });

    test('ignores a late result after a newer plan has loaded', () async {
      final api = _ControlledSharingApi();
      final provider = SharingProvider(api);

      final oldLoad = provider.loadMembers('plan-a');
      final currentLoad = provider.loadMembers('plan-b');

      api.completeMembers('plan-b', [_member('plan-b', 'member-b', 'بشرى')]);
      api.completeInvites('plan-b', [_invite('plan-b', 'invite-b')]);
      await currentLoad;
      expect(provider.members.single.id, 'member-b');

      api.completeMembers('plan-a', [_member('plan-a', 'member-a', 'أمينة')]);
      api.completeInvites('plan-a', [_invite('plan-a', 'invite-a')]);
      await oldLoad;

      expect(provider.members.single.id, 'member-b');
      expect(provider.invites.single.id, 'invite-b');
      expect(provider.errorMessage, isNull);
    });
  });

  group('EditSharedMemberScreen access gate', () {
    testWidgets('does not render stale member data before access is verified', (
      tester,
    ) async {
      final permissionGate = Completer<PlanAccessPermissions>();
      final api = _EditSharingApi(
        permissionGate: permissionGate,
        members: [_member('plan-a', 'member-1', 'الاسم الجديد')],
      );
      final provider = SharingProvider(api)
        ..selectMember(_member('plan-a', 'member-1', 'الاسم القديم'));

      await _pumpEditScreen(tester, provider);
      await tester.pump();

      expect(find.text('الاسم القديم'), findsNothing);
      expect(find.text('احفظ'), findsNothing);

      permissionGate.complete(
        const PlanAccessPermissions.owner(weddingPlanId: 'plan-a'),
      );
      await tester.pumpAndSettle();

      expect(find.text('الاسم الجديد'), findsOneWidget);
      expect(find.text('الاسم القديم'), findsNothing);
      expect(api.getSharedMembersCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('member without management permission sees no member actions', (
      tester,
    ) async {
      final api = _EditSharingApi(
        permissions: const PlanAccessPermissions.denied(
          weddingPlanId: 'plan-a',
        ),
        members: [_member('plan-a', 'member-1', 'عضو خاص')],
      );
      final provider = SharingProvider(api)
        ..selectMember(_member('plan-a', 'member-1', 'عضو قديم'));

      await _pumpEditScreen(tester, provider);
      await tester.pumpAndSettle();

      expect(find.text('المشاركين يديرهم صاحب الخطة'), findsOneWidget);
      expect(find.text('عضو قديم'), findsNothing);
      expect(find.text('احفظ'), findsNothing);
      expect(find.text('شيله من الخطة'), findsNothing);
      expect(api.getSharedMembersCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('access failure shows a retryable error without stale data', (
      tester,
    ) async {
      final api = _EditSharingApi(
        permissionsError: const ApiException(
          'permission service unavailable',
          statusCode: 503,
        ),
      );
      final provider = SharingProvider(api)
        ..selectMember(_member('plan-a', 'member-1', 'عضو قديم'));

      await _pumpEditScreen(tester, provider);
      await tester.pumpAndSettle();

      expect(find.text('ما قدرنا نجيبها'), findsOneWidget);
      expect(find.text('عضو قديم'), findsNothing);
      expect(find.text('احفظ'), findsNothing);
      expect(find.text('حاول مرة ثانية'), findsOneWidget);
      expect(api.getSharedMembersCalls, 0);
      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pumpEditScreen(
  WidgetTester tester,
  SharingProvider provider,
) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<SharingProvider>.value(
      value: provider,
      child: const MaterialApp(
        home: EditSharedMemberScreen(sharedMemberId: 'member-1'),
      ),
    ),
  );
}

class _ControlledSharingApi extends SharingApi {
  _ControlledSharingApi() : super(ApiClient(tokenProvider: () async => null));

  final Map<String, List<Completer<List<SharedMember>>>> _memberRequests = {};
  final Map<String, List<Completer<List<PlanInvite>>>> _inviteRequests = {};

  @override
  Future<List<SharedMember>> getSharedMembers(String weddingPlanId) {
    final request = Completer<List<SharedMember>>();
    _memberRequests.putIfAbsent(weddingPlanId, () => []).add(request);
    return request.future;
  }

  @override
  Future<List<PlanInvite>> getPlanInvites(String weddingPlanId) {
    final request = Completer<List<PlanInvite>>();
    _inviteRequests.putIfAbsent(weddingPlanId, () => []).add(request);
    return request.future;
  }

  void completeMembers(String planId, List<SharedMember> members) {
    _next(_memberRequests, planId).complete(members);
  }

  void completeInvites(String planId, List<PlanInvite> invites) {
    _next(_inviteRequests, planId).complete(invites);
  }

  void failMembers(String planId) {
    _next(_memberRequests, planId).completeError(StateError('members failed'));
  }

  void failInvites(String planId) {
    _next(_inviteRequests, planId).completeError(StateError('invites failed'));
  }
}

class _EditSharingApi extends SharingApi {
  _EditSharingApi({
    this.permissions,
    this.permissionGate,
    this.permissionsError,
    this.members = const [],
  }) : super(ApiClient(tokenProvider: () async => null));

  final PlanAccessPermissions? permissions;
  final Completer<PlanAccessPermissions>? permissionGate;
  final ApiException? permissionsError;
  final List<SharedMember> members;
  int getSharedMembersCalls = 0;

  @override
  Future<PlanAccessPermissions> getMyPlanPermissions(
    String weddingPlanId,
  ) async {
    final error = permissionsError;
    if (error != null) throw error;
    final gate = permissionGate;
    if (gate != null) return gate.future;
    return permissions ??
        PlanAccessPermissions.owner(weddingPlanId: weddingPlanId);
  }

  @override
  Future<List<SharedMember>> getSharedMembers(String weddingPlanId) async {
    getSharedMembersCalls += 1;
    return members;
  }

  @override
  Future<List<PlanInvite>> getPlanInvites(String weddingPlanId) async {
    return const [];
  }
}

Completer<List<T>> _next<T>(
  Map<String, List<Completer<List<T>>>> requests,
  String planId,
) {
  final queue = requests[planId];
  if (queue == null || queue.isEmpty) {
    throw StateError('No pending request for $planId');
  }
  return queue.removeAt(0);
}

SharedMember _member(String planId, String id, String name) {
  return SharedMember(
    id: id,
    weddingPlanId: planId,
    userId: 'user-$id',
    user: SharedMemberUser(id: 'user-$id', name: name, phone: '+967777123456'),
    role: 'VIEWER',
    canViewMoney: false,
    canManageTasks: false,
    canManageMoney: false,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

PlanInvite _invite(String planId, String id) {
  return PlanInvite(
    id: id,
    weddingPlanId: planId,
    token: id,
    role: 'VIEWER',
    status: 'PENDING',
    expiresAt: DateTime(2026, 8),
    canViewMoney: false,
    canEditPlan: false,
    canManageTasks: false,
    canManageGuests: false,
    canManageProviders: false,
    canInviteMembers: false,
    canManageMoney: false,
  );
}
