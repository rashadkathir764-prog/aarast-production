import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/account_contexts/screens/account_context_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android path selection opens provider at 320px without overflow',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final controller = AccountContextController(
        contextsApi: _FakeContextsApi([_ownerContext(), _providerContext()]),
        authStorage: AuthStorage(preferences),
        setActiveWeddingPlan: (_) async {},
      );
      await controller.refresh();
      expect(controller.selectedContext, isNull);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AccountContextController>.value(
            value: controller,
            child: const AccountContextSelectionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('account-path-option-provider:provider-1')),
      );
      await tester.pumpAndSettle();

      expect(controller.selectedContext?.role, AccountContextRole.provider);
      expect(tester.takeException(), isNull);
    },
  );
}

AccountContext _ownerContext() => AccountContext(
  contextKey: 'plan:plan-1:owner',
  role: AccountContextRole.owner,
  weddingPlanId: 'plan-1',
  providerId: null,
  membershipId: null,
  membershipAuthorityVersion: null,
  persona: AccountContextPersona.groom,
  displayName: 'خطة طويلة لاختبار الهاتف',
  lifecycle: 'PLANNING',
  accessMode: AccountContextAccessMode.full,
  capabilities: const AccountContextCapabilities(
    canViewProviderProfile: false,
    canManageProviderProfile: false,
    canUseProviderOperations: false,
  ),
  permissions: const AccountContextPermissions(
    canViewPlan: true,
    canEditPlan: true,
    canManageTasks: true,
    canManageGuests: true,
    canManageProviders: true,
    canInviteMembers: true,
    canViewMoney: true,
    canManageMoney: true,
    canManageProviderProfile: false,
  ),
  isAvailable: true,
  unavailableReason: null,
);

AccountContext _providerContext() => AccountContext(
  contextKey: 'provider:provider-1',
  role: AccountContextRole.provider,
  weddingPlanId: null,
  providerId: 'provider-1',
  membershipId: null,
  membershipAuthorityVersion: null,
  persona: null,
  displayName: 'ملف مزود طويل للاختبار',
  lifecycle: 'ACTIVE',
  accessMode: AccountContextAccessMode.full,
  capabilities: const AccountContextCapabilities(
    canViewProviderProfile: true,
    canManageProviderProfile: true,
    canUseProviderOperations: true,
  ),
  permissions: const AccountContextPermissions(
    canViewPlan: false,
    canEditPlan: false,
    canManageTasks: false,
    canManageGuests: false,
    canManageProviders: false,
    canInviteMembers: false,
    canViewMoney: false,
    canManageMoney: false,
    canManageProviderProfile: true,
  ),
  isAvailable: true,
  unavailableReason: null,
);

class _FakeContextsApi implements AccountContextsGateway {
  _FakeContextsApi(this._contexts);

  final List<AccountContext> _contexts;

  @override
  Future<List<AccountContext>> listContexts() async => _contexts;

  @override
  Future<AccountContext> validateContext(String contextKey) async =>
      _contexts.firstWhere((item) => item.contextKey == contextKey);
}
