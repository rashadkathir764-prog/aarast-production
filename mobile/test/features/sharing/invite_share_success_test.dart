import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/add_shared_member_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'creates one pending participant and confirms server-side WhatsApp delivery',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 900);
      addTearDown(tester.view.reset);

      final api = _FakeSharingApi(createDeliveryStatus: 'SENT');
      final provider = SharingProvider(api);
      await _pumpScreen(tester, provider: provider);

      await tester.enterText(find.byType(TextFormField).first, '777123456');
      await tester.tap(find.text('إرسال دعوة المشاركة'));
      await tester.tap(find.text('إرسال دعوة المشاركة'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('invite-created-view')), findsOneWidget);
      expect(find.text('تمت إضافة المشارك وإرسال الرابط'), findsOneWidget);
      expect(find.textContaining('بانتظار التحقق'), findsWidgets);
      expect(find.text('+967 777 123 456'), findsOneWidget);
      expect(find.byKey(const Key('invite-share-whatsapp')), findsNothing);
      expect(find.byKey(const Key('invite-retry-delivery')), findsNothing);
      expect(api.createCalls, 1);
      expect(provider.invites.single.token, provider.invites.single.id);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed delivery keeps one invite and retries by rotating and sending it from Aarast',
    (tester) async {
      final api = _FakeSharingApi(createDeliveryStatus: 'UNAVAILABLE');
      await _pumpScreen(tester, provider: SharingProvider(api));

      await tester.enterText(find.byType(TextFormField).first, '777123456');
      await tester.tap(find.text('إرسال دعوة المشاركة'));
      await tester.pumpAndSettle();

      expect(api.createCalls, 1);
      expect(find.byKey(const Key('invite-retry-delivery')), findsOneWidget);
      expect(find.textContaining('تعذر إرسال رابطها'), findsOneWidget);

      await tester.tap(find.byKey(const Key('invite-retry-delivery')));
      await tester.pumpAndSettle();

      expect(api.createCalls, 1);
      expect(api.reissueCalls, 1);
      expect(find.text('تمت إضافة المشارك وإرسال الرابط'), findsOneWidget);
      expect(find.byKey(const Key('invite-retry-delivery')), findsNothing);
      expect(find.textContaining('تم إرسال رابط المشاركة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'clipboard failure keeps an unsent one-time link unacknowledged',
    (tester) async {
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

      await _pumpScreen(
        tester,
        provider: SharingProvider(
          _FakeSharingApi(createDeliveryStatus: 'UNAVAILABLE'),
        ),
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
    },
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required SharingProvider provider,
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
        home: const AddSharedMemberScreen(weddingPlanId: 'plan-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeSharingApi extends SharingApi {
  _FakeSharingApi({required this.createDeliveryStatus})
    : super(ApiClient(tokenProvider: () async => null));

  final String createDeliveryStatus;
  int createCalls = 0;
  int reissueCalls = 0;

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
    return _invite(
      weddingPlanId: weddingPlanId,
      role: role,
      deliveryStatus: createDeliveryStatus,
      canViewMoney: canViewMoney,
      canEditPlan: canEditPlan,
      canManageTasks: canManageTasks,
      canManageGuests: canManageGuests,
      canManageProviders: canManageProviders,
      canInviteMembers: canInviteMembers,
      canManageMoney: canManageMoney,
    );
  }

  @override
  Future<PlanInvite> reissuePlanInvite({
    required String weddingPlanId,
    required String inviteId,
  }) async {
    reissueCalls += 1;
    return _invite(
      weddingPlanId: weddingPlanId,
      role: 'VIEWER',
      deliveryStatus: 'SENT',
    );
  }
}

PlanInvite _invite({
  required String weddingPlanId,
  required String role,
  required String deliveryStatus,
  bool canViewMoney = false,
  bool canEditPlan = false,
  bool canManageTasks = false,
  bool canManageGuests = false,
  bool canManageProviders = false,
  bool canInviteMembers = false,
  bool canManageMoney = false,
}) {
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
    deliveryStatus: deliveryStatus,
    phone: '+967777123456',
    name: 'أمينة',
    inviterName: 'رشاد',
    weddingPlanTitle: 'عرس رشاد وسارة',
  );
}
