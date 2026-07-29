import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/account_contexts/widgets/account_context_entry_gate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_context_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('one groom path opens the plan dashboard directly', () async {
    final controller = await _controller([
      accountContext(role: AccountContextRole.owner),
    ]);

    expect(
      resolveAccountContextEntry(controller),
      AccountContextEntryState.planDashboard,
    );
  });

  test('one provider path opens the provider dashboard directly', () async {
    final controller = await _controller([
      accountContext(role: AccountContextRole.provider),
    ]);

    expect(
      resolveAccountContextEntry(controller),
      AccountContextEntryState.providerDashboard,
    );
    expect(controller.selectedContext?.weddingPlanId, isNull);
  });

  test('one contributor path opens the plan dashboard directly', () async {
    final controller = await _controller([
      accountContext(role: AccountContextRole.contributor),
    ]);

    expect(
      resolveAccountContextEntry(controller),
      AccountContextEntryState.planDashboard,
    );
  });

  test(
    'owner and contributor require the standalone selection screen',
    () async {
      final controller = await _controller([
        accountContext(role: AccountContextRole.owner),
        accountContext(role: AccountContextRole.contributor),
      ]);

      expect(
        resolveAccountContextEntry(controller),
        AccountContextEntryState.choosePath,
      );
      expect(controller.selectedContext, isNull);
    },
  );

  test('owner and provider require the standalone selection screen', () async {
    final controller = await _controller([
      accountContext(role: AccountContextRole.owner),
      accountContext(role: AccountContextRole.provider),
    ]);

    expect(
      resolveAccountContextEntry(controller),
      AccountContextEntryState.choosePath,
    );
    expect(controller.selectedContext, isNull);
  });

  test('all three account paths require explicit selection', () async {
    final controller = await _controller([
      accountContext(role: AccountContextRole.owner),
      accountContext(role: AccountContextRole.contributor),
      accountContext(role: AccountContextRole.provider),
    ]);

    expect(
      resolveAccountContextEntry(controller),
      AccountContextEntryState.choosePath,
    );
    expect(controller.availableContexts, hasLength(3));
  });

  test('zero paths returns the existing onboarding path', () async {
    final controller = await _controller(const []);

    expect(
      resolveAccountContextEntry(controller),
      AccountContextEntryState.noPaths,
    );
  });

  test('a valid persisted path survives a cold controller restart', () async {
    final owner = accountContext(role: AccountContextRole.owner);
    final provider = accountContext(role: AccountContextRole.provider);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    await storage.saveAccountContextKey(provider.contextKey);

    final controller = AccountContextController(
      contextsApi: _StaticGateway([owner, provider]),
      authStorage: storage,
      setActiveWeddingPlan: (_) async {},
    );
    await controller.refresh();

    expect(controller.selectedContext, provider);
    expect(
      resolveAccountContextEntry(controller),
      AccountContextEntryState.providerDashboard,
    );
  });

  test(
    'logout clears the path so a later multi-path login asks again',
    () async {
      final owner = accountContext(role: AccountContextRole.owner);
      final provider = accountContext(role: AccountContextRole.provider);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = AuthStorage(preferences);
      await storage.saveAccountContextKey(provider.contextKey);

      final firstSession = AccountContextController(
        contextsApi: _StaticGateway([owner, provider]),
        authStorage: storage,
        setActiveWeddingPlan: (_) async {},
      );
      await firstSession.refresh();
      expect(firstSession.selectedContext, provider);

      await firstSession.clearForLogout();
      expect(storage.readAccountContextKey(), isNull);

      final nextSession = AccountContextController(
        contextsApi: _StaticGateway([owner, provider]),
        authStorage: storage,
        setActiveWeddingPlan: (_) async {},
      );
      await nextSession.refresh();

      expect(
        resolveAccountContextEntry(nextSession),
        AccountContextEntryState.choosePath,
      );
    },
  );

  test(
    'workspace exit never re-enters a remaining single path automatically',
    () async {
      final owner = accountContext(role: AccountContextRole.owner);
      final controller = await _controller([owner]);
      expect(controller.selectedContext, owner);

      await controller.exitWorkspace();
      await controller.refresh();

      expect(controller.selectedContext, isNull);
      expect(controller.selectionRequired, isTrue);
      expect(
        resolveAccountContextEntry(controller),
        AccountContextEntryState.choosePath,
      );
    },
  );

  test('contributor resume rejects owner and unpermitted provider routes', () {
    final contributor = accountContext(role: AccountContextRole.contributor);

    expect(
      compatibleAccountContextResume(
        contributor,
        AppRouter.weddingPlanDashboard(contributor.weddingPlanId!),
      ),
      isNull,
    );
    expect(
      compatibleAccountContextResume(
        contributor,
        AppRouter.providerMarketplace,
      ),
      isNull,
    );
    expect(
      compatibleAccountContextResume(
        contributor,
        AppRouter.tasks(contributor.weddingPlanId!),
      ),
      AppRouter.tasks(contributor.weddingPlanId!),
    );
  });

  test('post-auth resume is carried through the central home entry', () {
    final location = AppRouter.authenticatedEntry('/providers/provider-1');
    final uri = Uri.parse(location);

    expect(uri.path, AppRouter.home);
    expect(uri.queryParameters['resume'], '/providers/provider-1');
    expect(AppRouter.authenticatedEntry('https://example.com'), AppRouter.home);
  });
}

Future<AccountContextController> _controller(
  List<AccountContext> contexts,
) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final controller = AccountContextController(
    contextsApi: _StaticGateway(contexts),
    authStorage: AuthStorage(preferences),
    setActiveWeddingPlan: (_) async {},
  );
  await controller.refresh(allowInitialSingleContext: true);
  return controller;
}

class _StaticGateway implements AccountContextsGateway {
  const _StaticGateway(this.contexts);

  final List<AccountContext> contexts;

  @override
  Future<List<AccountContext>> listContexts() async => contexts;

  @override
  Future<AccountContext> validateContext(String contextKey) async {
    return contexts.firstWhere((context) => context.contextKey == contextKey);
  }
}
