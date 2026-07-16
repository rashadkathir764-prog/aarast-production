import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/add_shared_member_screen.dart';
import 'package:aarast_mobile/features/sharing/services/invite_share_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'keeps the one-time invite on the same screen and opens WhatsApp once',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      addTearDown(tester.view.reset);

      final api = _FakeSharingApi();
      final launcher = _FakeInviteShareLauncher();
      final provider = SharingProvider(api);
      await _pumpScreen(tester, provider: provider, launcher: launcher);

      await tester.enterText(find.byType(TextFormField).first, '777123456');
      await tester.tap(find.text('إرسال دعوة المشاركة'));
      await tester.tap(find.text('إرسال دعوة المشاركة'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('invite-created-view')), findsOneWidget);
      expect(find.text('تم إنشاء الدعوة بأمان'), findsOneWidget);
      expect(find.text('+967 777 123 456'), findsOneWidget);
      expect(api.createCalls, 1);
      expect(provider.invites.single.token, provider.invites.single.id);

      await tester.tap(find.byKey(const Key('invite-share-whatsapp')));
      await tester.pumpAndSettle();

      expect(launcher.calls, 1);
      expect(launcher.lastUri?.host, 'wa.me');
      expect(launcher.lastUri?.path, '/967777123456');
      expect(
        launcher.lastUri?.queryParameters['text'],
        contains('https://aarast.shadowgardn.com/invites/'),
      );
      expect(api.createCalls, 1);

      await tester.tap(find.byKey(const Key('invite-done')));
      await tester.pumpAndSettle();
      expect(find.text('هل حفظت رابط الدعوة؟'), findsOneWidget);
      await tester.tap(find.text('البقاء'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('invite-created-view')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'WhatsApp failure keeps the invite available without creating it again',
    (tester) async {
      final api = _FakeSharingApi();
      final launcher = _FakeInviteShareLauncher(result: false);
      await _pumpScreen(
        tester,
        provider: SharingProvider(api),
        launcher: launcher,
      );

      await tester.enterText(find.byType(TextFormField).first, '777123456');
      await tester.tap(find.text('إرسال دعوة المشاركة'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('invite-share-whatsapp')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('invite-created-view')), findsOneWidget);
      expect(find.textContaining('تعذر فتح واتساب'), findsOneWidget);
      expect(api.createCalls, 1);
      expect(launcher.calls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clipboard failure keeps the one-time link unacknowledged', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'clipboard_unavailable');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final api = _FakeSharingApi();
    await _pumpScreen(
      tester,
      provider: SharingProvider(api),
      launcher: _FakeInviteShareLauncher(),
    );

    await tester.enterText(find.byType(TextFormField).first, '777123456');
    await tester.tap(find.text('إرسال دعوة المشاركة'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('invite-copy-link')));
    await tester.pumpAndSettle();

    expect(find.textContaining('تعذر نسخ الرابط'), findsOneWidget);
    await tester.tap(find.byKey(const Key('invite-done')));
    await tester.pumpAndSettle();
    expect(find.text('هل حفظت رابط الدعوة؟'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required SharingProvider provider,
  required InviteShareLauncher launcher,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final authStorage = AuthStorage(preferences);
  await authStorage.saveSession(
    accessToken: 'invite-share-test-token',
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
        theme: AppTheme.light(),
        home: AddSharedMemberScreen(
          weddingPlanId: 'plan-1',
          inviteShareLauncher: launcher,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeInviteShareLauncher implements InviteShareLauncher {
  _FakeInviteShareLauncher({this.result = true});

  final bool result;
  int calls = 0;
  Uri? lastUri;

  @override
  Future<bool> openWhatsApp(Uri uri) async {
    calls += 1;
    lastUri = uri;
    return result;
  }
}

class _FakeSharingApi extends SharingApi {
  _FakeSharingApi() : super(ApiClient(tokenProvider: () async => null));

  int createCalls = 0;

  @override
  Future<PlanAccessPermissions> getMyPlanPermissions(
    String weddingPlanId,
  ) async {
    return PlanAccessPermissions.owner(weddingPlanId: weddingPlanId);
  }

  @override
  Future<PlanInvite> createPlanInvite({
    required String weddingPlanId,
    required String phone,
    String? name,
    required String role,
    required bool canViewMoney,
    required bool canEditPlan,
    required bool canManageTasks,
    required bool canManageGuests,
    required bool canManageProviders,
    required bool canInviteMembers,
    required bool canManageMoney,
    required bool receiveNotifications,
  }) async {
    createCalls += 1;
    return PlanInvite(
      id: 'invite-1',
      weddingPlanId: weddingPlanId,
      token: 'abcdefghijklmnopqrstuvwxyzABCDEFGH123456789',
      role: role,
      status: 'PENDING',
      expiresAt: DateTime(2026, 8),
      canViewMoney: canViewMoney,
      canEditPlan: canEditPlan,
      canManageTasks: canManageTasks,
      canManageGuests: canManageGuests,
      canManageProviders: canManageProviders,
      canInviteMembers: canInviteMembers,
      canManageMoney: canManageMoney,
      phone: '+967777123456',
      name: 'أمينة',
      inviterName: 'رشاد',
      weddingPlanTitle: 'عرس رشاد وسارة',
    );
  }
}
