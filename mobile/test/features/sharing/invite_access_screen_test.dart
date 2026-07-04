import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/invite_decision_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'invite access starts with phone verification and no plan creation',
    (tester) async {
      final auth = await _authController();
      final sharing = SharingProvider(_FakeSharingApi());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: auth),
            ChangeNotifierProvider<SharingProvider>.value(value: sharing),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const InviteDecisionScreen(),
          ),
        ),
      );

      expect(find.text('وصلتني دعوة لخطة'), findsOneWidget);
      expect(find.text('أدخل الرقم الذي وصلت إليه الدعوة.'), findsWidgets);
      expect(find.byKey(const Key('invite-phone-field')), findsOneWidget);
      expect(find.text('إنشاء خطة'), findsNothing);
      expect(find.text('أجهز عرسي'), findsNothing);
      expect(find.text('إرسال رمز التحقق'), findsOneWidget);
    },
  );

  test('invite permission labels keep financial access explicit', () {
    final helperInvite = _invite(canManageTasks: true);
    expect(helperInvite.permissionLabels, contains('عرض الخطة'));
    expect(helperInvite.permissionLabels, contains('المهام'));
    expect(helperInvite.permissionLabels, isNot(contains('إدارة المال')));
    expect(helperInvite.permissionLabels, isNot(contains('عرض مالي محدود')));

    final financeInvite = _invite(
      canViewBudget: true,
      canViewExpenses: true,
      canViewDebts: true,
      canManageFinancialRecords: true,
    );
    expect(financeInvite.permissionLabels, contains('إدارة المال'));
  });
}

Future<AuthController> _authController() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  return AuthController(_FakeAuthRepository(authStorage));
}

PlanInvite _invite({
  bool canViewBudget = false,
  bool canViewExpenses = false,
  bool canViewDebts = false,
  bool canEditPlan = false,
  bool canManageTasks = false,
  bool canManageGuests = false,
  bool canManageProviders = false,
  bool canInviteMembers = false,
  bool canManageFinancialRecords = false,
}) {
  return PlanInvite(
    id: 'invite-1',
    weddingPlanId: 'plan-1',
    token: 'token-1',
    role: 'HELPER',
    status: 'PENDING',
    expiresAt: DateTime(2026),
    canViewBudget: canViewBudget,
    canViewExpenses: canViewExpenses,
    canViewDebts: canViewDebts,
    canEditPlan: canEditPlan,
    canManageTasks: canManageTasks,
    canManageGuests: canManageGuests,
    canManageProviders: canManageProviders,
    canInviteMembers: canInviteMembers,
    canManageFinancialRecords: canManageFinancialRecords,
  );
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(AuthStorage storage)
    : super(ApiClient(tokenProvider: () async => null), storage);
}

class _FakeSharingApi extends SharingApi {
  _FakeSharingApi() : super(ApiClient(tokenProvider: () async => null));
}
