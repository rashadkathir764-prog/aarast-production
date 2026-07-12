import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/models/shared_wedding_plan.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/shared_wedding_plans_screen.dart';
import 'package:aarast_mobile/features/sharing/screens/sharing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Phase C sharing screens premium contract', () {
    test(
      'sharing screens and visible cards use Lucide and avoid stale leaks',
      () {
        for (final path in _phaseCPaths) {
          final source = _readSource(path);

          expect(source, contains('LucideIcons.'), reason: path);
          expect(_materialIconLines(source), isEmpty, reason: path);
          expect(
            source,
            isNot(contains('AarastComingSoonScreen')),
            reason: path,
          );
          expect(source, isNot(contains('PLANNING')), reason: path);
          expect(source, isNot(contains("'YER'")), reason: path);
        }

        expect(
          _readSource('lib/features/sharing/widgets/shared_plan_card.dart'),
          contains('currencyLabelAr'),
        );
      },
    );
  });

  group('Phase C sharing screens rendering', () {
    testWidgets('sharing screen renders truthful privacy metrics', (
      tester,
    ) async {
      _setTallView(tester);
      final api = _FakeSharingApi(
        members: [
          _member(id: 'member-1', userName: 'أمينة', canViewBudget: true),
        ],
        invites: [_invite()],
      );

      await _pumpWithAuth(
        tester,
        provider: SharingProvider(api),
        child: const SharingScreen(weddingPlanId: _planId),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('المال خاص افتراضيًا — لا يظهر لأي عضو إلا بصلاحية تمنحها.'),
        findsOneWidget,
      );
      expect(find.text('المشاركون (1)'), findsOneWidget);
      expect(find.text('الدعوات المعلقة (1)'), findsOneWidget);
      expect(find.text('أمينة'), findsOneWidget);
      // ملخص صلاحيات صادق: مشاهدة فقط مع اطلاع مالي (canViewBudget).
      expect(find.text('عرض فقط · اطلاع مالي محدود'), findsOneWidget);
      expect(find.text('مساعد · بانتظار القبول'), findsOneWidget);
      expect(api.getSharedMembersCalls, 1);
      expect(api.getPlanInvitesCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shared plans show Arabic currency labels', (tester) async {
      _setTallView(tester);
      final api = _FakeSharingApi(sharedPlans: [_sharedPlan()]);

      await _pumpWithAuth(
        tester,
        provider: SharingProvider(api),
        child: const SharedWeddingPlansScreen(),
      );
      expect(find.text('الخطط المشتركة'), findsOneWidget);
      expect(find.text('الخطط المشتركة معي'), findsNothing);
      await tester.pumpAndSettle();

      expect(find.text('1 خطة مشتركة معك'), findsOneWidget);
      expect(find.textContaining('ر.س'), findsWidgets);
      expect(find.textContaining('SAR'), findsNothing);
      expect(find.textContaining('YER'), findsNothing);
      expect(api.getSharedWeddingPlansCalls, 1);
      expect(tester.takeException(), isNull);
    });
  });
}

const _planId = 'plan-sharing-1';
const _phaseCPaths = [
  'lib/features/sharing/screens/add_shared_member_screen.dart',
  'lib/features/sharing/screens/sharing_screen.dart',
  'lib/features/sharing/screens/edit_shared_member_screen.dart',
  'lib/features/sharing/screens/shared_wedding_plans_screen.dart',
  'lib/features/sharing/widgets/shared_member_card.dart',
  'lib/features/sharing/widgets/shared_plan_card.dart',
  'lib/features/sharing/widgets/permission_editor.dart',
];

Future<void> _pumpWithAuth(
  WidgetTester tester, {
  required SharingProvider provider,
  required Widget child,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  await authStorage.saveSession(
    accessToken: 'phase-c-token',
    user: const SafeUser(
      id: 'user-1',
      name: 'رشاد',
      role: 'USER',
      status: 'ACTIVE',
    ),
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        ChangeNotifierProvider<SharingProvider>.value(value: provider),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: child),
    ),
  );
}

SharedMember _member({
  required String id,
  required String userName,
  bool canViewBudget = false,
}) {
  return SharedMember(
    id: id,
    weddingPlanId: _planId,
    userId: 'user-$id',
    user: SharedMemberUser(
      id: 'user-$id',
      name: userName,
      phone: '+967777123456',
    ),
    role: 'VIEWER',
    canViewBudget: canViewBudget,
    canViewExpenses: false,
    canViewFinancialRecords: false,
    canManageTasks: false,
    canManageFinancialRecords: false,
    createdAt: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
  );
}

PlanInvite _invite() {
  return PlanInvite(
    id: 'invite-1',
    weddingPlanId: _planId,
    token: 'invite-token',
    role: 'HELPER',
    status: 'PENDING',
    expiresAt: DateTime(2026, 7, 20),
    canViewBudget: false,
    canViewExpenses: false,
    canViewFinancialRecords: false,
    canEditPlan: false,
    canManageTasks: true,
    canManageGuests: true,
    canManageProviders: false,
    canInviteMembers: false,
    canManageFinancialRecords: false,
    phone: '+967777123456',
    name: 'خالد',
  );
}

SharedWeddingPlan _sharedPlan() {
  return SharedWeddingPlan(
    id: _planId,
    title: 'خطة الرياض',
    city: 'الرياض',
    weddingDate: DateTime(2026, 8, 20),
    currency: 'SAR',
    status: 'ACTIVE',
    sharedMember: _member(id: 'member-shared', userName: 'رشاد'),
  );
}

class _FakeSharingApi extends SharingApi {
  _FakeSharingApi({
    this.members = const [],
    this.invites = const [],
    this.sharedPlans = const [],
  }) : super(ApiClient(tokenProvider: () async => null));

  final List<SharedMember> members;
  final List<PlanInvite> invites;
  final List<SharedWeddingPlan> sharedPlans;

  int getSharedMembersCalls = 0;
  int getPlanInvitesCalls = 0;
  int getSharedWeddingPlansCalls = 0;

  @override
  Future<List<SharedMember>> getSharedMembers(String weddingPlanId) async {
    getSharedMembersCalls += 1;
    return members;
  }

  @override
  Future<List<PlanInvite>> getPlanInvites(String weddingPlanId) async {
    getPlanInvitesCalls += 1;
    return invites;
  }

  @override
  Future<List<SharedWeddingPlan>> getSharedWeddingPlans() async {
    getSharedWeddingPlansCalls += 1;
    return sharedPlans;
  }
}

List<String> _materialIconLines(String source) {
  return source
      .split('\n')
      .where(
        (line) => line.contains('Icons.') && !line.contains('LucideIcons.'),
      )
      .toList();
}

String _readSource(String relativePath) {
  return File('${_findMobileRoot()}$relativePath').readAsStringSync();
}

void _setTallView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 1800);
  addTearDown(tester.view.reset);
}

String _findMobileRoot() {
  final cwd = Directory.current.path;
  if (cwd.endsWith('${Platform.pathSeparator}mobile') ||
      cwd.endsWith('/mobile')) {
    return '$cwd${Platform.pathSeparator}';
  }
  return '$cwd${Platform.pathSeparator}mobile${Platform.pathSeparator}';
}
