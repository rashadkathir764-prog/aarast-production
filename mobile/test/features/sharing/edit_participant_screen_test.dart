import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/edit_shared_member_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// Editing a participant uses g06's roles and levels.

void main() {
  testWidgets('opens on the stored role and levels, same controls as g06', (
    tester,
  ) async {
    final api = _Api(_member(role: 'FAMILY', canViewMoney: true));
    await _pump(tester, api);

    expect(find.text('صالح'), findsOneWidget);
    expect(find.textContaining('أهل'), findsWidgets);
    expect(find.byType(JourneyLevelSwitch), findsNWidgets(4));
    final family = tester.widget<JourneyChip>(
      find.byKey(const ValueKey('participant-preset-FAMILY')),
    );
    expect(family.selected, isTrue);
    final money = tester.widget<JourneyLevelSwitch>(
      find.byKey(const ValueKey('participant-level-المال')),
    );
    expect(money.options, ['لا', 'يشوف', 'يعدّل']);
    expect(money.selected, 1);
    final tasks = tester.widget<JourneyLevelSwitch>(
      find.byKey(const ValueKey('participant-level-المهام')),
    );
    expect(tasks.options, ['لا', 'يعدّل']);
    expect(tasks.selected, 1);
    expect(find.text('العروسة'), findsNothing);
    expect(find.text('الرفد'), findsNothing);
  });

  testWidgets('saves one full snapshot and keeps the flags it does not show', (
    tester,
  ) async {
    final api = _Api(
      _member(role: 'HELPER', canEditPlan: true, canInviteMembers: true),
    );
    await _pump(tester, api);

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('participant-level-المال')),
        matching: find.text('يعدّل'),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('member-save')));
    await tester.tap(find.byKey(const ValueKey('member-save')));
    await tester.pumpAndSettle();

    final sent = api.lastUpdate!;
    expect(sent['role'], 'HELPER');
    expect(sent['canManageMoney'], isTrue);
    expect(sent['canViewMoney'], isTrue);
    expect(sent['canManageTasks'], isTrue);
    expect(sent['canEditPlan'], isTrue);
    expect(sent['canInviteMembers'], isTrue);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('choosing «يشوف بس» resets the levels to the viewer role', (
    tester,
  ) async {
    final api = _Api(_member(role: 'HELPER'));
    await _pump(tester, api);

    await tester.tap(find.byKey(const ValueKey('participant-preset-VIEWER')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('member-save')));
    await tester.tap(find.byKey(const ValueKey('member-save')));
    await tester.pumpAndSettle();

    expect(api.lastUpdate!['role'], 'VIEWER');
    expect(api.lastUpdate!['canManageTasks'], isFalse);
    expect(api.lastUpdate!['canManageGuests'], isFalse);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('taking someone off the plan asks first', (tester) async {
    final api = _Api(_member(role: 'HELPER'));
    await _pump(tester, api);

    await tester.ensureVisible(find.byKey(const ValueKey('member-remove')));
    await tester.tap(find.byKey(const ValueKey('member-remove')));
    await tester.pumpAndSettle();
    expect(find.text('تشيل صالح من الخطة؟'), findsOneWidget);
    expect(api.deleted, 0);

    await tester.tap(find.byKey(const ValueKey('member-remove-confirm')));
    await tester.pumpAndSettle();
    expect(api.deleted, 1);
    expect(find.text('participants-list'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });
}

Future<void> _pump(WidgetTester tester, _Api api) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 1200);
  addTearDown(tester.view.reset);
  final provider = SharingProvider(api)..selectMember(api.member);
  final router = GoRouter(
    initialLocation: '/edit',
    routes: [
      GoRoute(
        path: '/edit',
        builder: (_, _) =>
            const EditSharedMemberScreen(sharedMemberId: 'member-1'),
      ),
      GoRoute(
        path: '/wedding-plans/:id/sharing',
        builder: (_, _) => const Text('participants-list'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<SharingProvider>.value(
      value: provider,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _Api extends SharingApi {
  _Api(this.member) : super(ApiClient(tokenProvider: () async => null));

  final SharedMember member;
  Map<String, dynamic>? lastUpdate;
  int deleted = 0;

  @override
  Future<PlanAccessPermissions> getMyPlanPermissions(
    String weddingPlanId,
  ) async => PlanAccessPermissions.owner(weddingPlanId: weddingPlanId);

  @override
  Future<List<SharedMember>> getSharedMembers(String weddingPlanId) async => [
    member,
  ];

  @override
  Future<List<PlanInvite>> getPlanInvites(String weddingPlanId) async =>
      const [];

  @override
  Future<SharedMember> updateSharedMember(
    String weddingPlanId,
    String id,
    Map<String, dynamic> data,
  ) async {
    lastUpdate = data;
    return member;
  }

  @override
  Future<void> deleteSharedMember(String weddingPlanId, String id) async {
    deleted += 1;
  }
}

SharedMember _member({
  required String role,
  bool canViewMoney = false,
  bool canEditPlan = false,
  bool canInviteMembers = false,
}) {
  return SharedMember(
    id: 'member-1',
    weddingPlanId: 'plan-1',
    userId: 'user-1',
    user: const SharedMemberUser(
      id: 'user-1',
      name: 'صالح',
      phone: '+967771554220',
    ),
    role: role,
    canViewMoney: canViewMoney,
    canEditPlan: canEditPlan,
    canManageTasks: true,
    canManageGuests: true,
    canInviteMembers: canInviteMembers,
    canManageMoney: false,
    createdAt: DateTime(2026, 7, 16),
    updatedAt: DateTime(2026, 7, 16),
  );
}
