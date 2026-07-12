// Visual preview harness for the redesigned sharing screens: compact member
// rows on the main screen and the collapsed permission editor on add-member.
// Regenerate with:
//   flutter test test/sharing_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/add_shared_member_screen.dart';
import 'package:aarast_mobile/features/sharing/screens/sharing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/preview_fonts.dart';

const _planId = 'plan-sharing-preview';

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('sharing screen — compact member rows (420)', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1100);
    addTearDown(tester.view.reset);

    final api = _FakeSharingApi(
      members: [
        _member(
          id: 'm-1',
          name: 'أم العريس',
          role: 'FAMILY',
          canManageTasks: true,
          canManageGuests: true,
          canViewBudget: true,
        ),
        _member(
          id: 'm-2',
          name: 'سارة',
          role: 'BRIDE',
          canManageTasks: true,
          canEditPlan: true,
        ),
        _member(id: 'm-3', name: 'أبو العريس', role: 'VIEWER'),
      ],
      invites: [_invite()],
    );

    await _pumpWithAuth(
      tester,
      provider: SharingProvider(api),
      child: const SharingScreen(weddingPlanId: _planId),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/sharing_members.png'),
    );
  });

  testWidgets('add member — role chips and collapsed permissions (420)', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 1100);
    addTearDown(tester.view.reset);

    final api = _FakeSharingApi();

    await _pumpWithAuth(
      tester,
      provider: SharingProvider(api),
      child: const AddSharedMemberScreen(weddingPlanId: _planId),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/sharing_add_member.png'),
    );
  });
}

Future<void> _pumpWithAuth(
  WidgetTester tester, {
  required SharingProvider provider,
  required Widget child,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  await authStorage.saveSession(
    accessToken: 'sharing-preview-token',
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
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: child,
      ),
    ),
  );
}

SharedMember _member({
  required String id,
  required String name,
  required String role,
  bool canViewBudget = false,
  bool canManageTasks = false,
  bool canManageGuests = false,
  bool canEditPlan = false,
}) {
  return SharedMember(
    id: id,
    weddingPlanId: _planId,
    userId: 'user-$id',
    user: SharedMemberUser(id: 'user-$id', name: name, phone: '+967777123456'),
    role: role,
    canViewBudget: canViewBudget,
    canViewExpenses: false,
    canViewFinancialRecords: false,
    canEditPlan: canEditPlan,
    canManageTasks: canManageTasks,
    canManageGuests: canManageGuests,
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
    role: 'VIEWER',
    status: 'PENDING',
    expiresAt: DateTime(2026, 7, 20),
    canViewBudget: false,
    canViewExpenses: false,
    canViewFinancialRecords: false,
    canEditPlan: false,
    canManageTasks: false,
    canManageGuests: false,
    canManageProviders: false,
    canInviteMembers: false,
    canManageFinancialRecords: false,
    phone: '+967777123456',
    name: 'أبو همدان',
  );
}

class _FakeSharingApi extends SharingApi {
  _FakeSharingApi({this.members = const [], this.invites = const []})
    : super(ApiClient(tokenProvider: () async => null));

  final List<SharedMember> members;
  final List<PlanInvite> invites;

  @override
  Future<List<SharedMember>> getSharedMembers(String weddingPlanId) async {
    return members;
  }

  @override
  Future<List<PlanInvite>> getPlanInvites(String weddingPlanId) async {
    return invites;
  }
}
