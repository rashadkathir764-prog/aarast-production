import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_ui.dart';
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

      final api = _FakeSharingApi(createDeliveryStatus: 'DELIVERED');
      final provider = SharingProvider(api);
      await _pumpScreen(tester, provider: provider);

      await tester.enterText(find.byType(TextFormField).first, '777123456');
      await tester.tap(find.text('إرسال دعوة المشاركة'));
      await tester.tap(find.text('إرسال دعوة المشاركة'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('invite-created-view')), findsOneWidget);
      expect(find.text('تم إنشاء الدعوة وتسليم الرابط'), findsOneWidget);
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
      final retryFinder = find.byKey(const Key('invite-retry-delivery'));
      expect(retryFinder, findsOneWidget);
      expect(tester.widget<AarastButton>(retryFinder).onPressed, isNull);
      expect(find.textContaining('تعذر إرسال رابطها'), findsOneWidget);

      await tester.pump(const Duration(seconds: 60, milliseconds: 100));
      await tester.pump();
      expect(tester.widget<AarastButton>(retryFinder).onPressed, isNotNull);
      await tester.tap(retryFinder);
      await tester.pumpAndSettle();

      expect(api.createCalls, 1);
      expect(api.reissueCalls, 1);
      expect(find.text('تم إنشاء الدعوة وتسليم الرابط'), findsOneWidget);
      expect(find.byKey(const Key('invite-retry-delivery')), findsNothing);
      expect(find.textContaining('تم تسليم رابط المشاركة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'uncertain delivery keeps the invite without claiming success or offering an immediate duplicate send',
    (tester) async {
      final api = _FakeSharingApi(createDeliveryStatus: 'UNCERTAIN');
      await _pumpScreen(tester, provider: SharingProvider(api));

      await tester.enterText(find.byType(TextFormField).first, '777123456');
      await tester.tap(find.text('إرسال دعوة المشاركة'));
      await tester.pumpAndSettle();

      expect(api.createCalls, 1);
      expect(find.byKey(const Key('invite-created-view')), findsOneWidget);
      expect(find.text('تم إنشاء دعوة المساهم'), findsOneWidget);
      expect(
        find.textContaining('لم نتأكد من وصول رسالة واتساب'),
        findsOneWidget,
      );
      expect(find.textContaining('تسليم الرابط'), findsNothing);
      final retryFinder = find.byKey(const Key('invite-retry-delivery'));
      expect(retryFinder, findsOneWidget);
      expect(tester.widget<AarastButton>(retryFinder).onPressed, isNull);
      expect(find.byKey(const Key('invite-copy-link')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an existing pending invite is reissued instead of blocking submit',
    (tester) async {
      final existingInvite = _invite(
        weddingPlanId: 'plan-1',
        role: 'FAMILY',
        deliveryStatus: 'UNAVAILABLE',
        canManageTasks: true,
      );
      final api = _FakeSharingApi(
        createDeliveryStatus: 'DELIVERED',
        existingInvites: [existingInvite],
      );
      final provider = SharingProvider(api);
      await _pumpScreen(tester, provider: provider);

      await tester.enterText(find.byType(TextFormField).first, '777123456');
      await tester.tap(find.text('إرسال دعوة المشاركة'));
      await tester.pumpAndSettle();

      expect(api.createCalls, 0);
      expect(api.reissueCalls, 1);
      expect(api.lastReissueRole, 'VIEWER');
      expect(api.lastReissueCanManageTasks, isFalse);
      expect(find.byKey(const Key('invite-created-view')), findsOneWidget);
      expect(find.text('تم إنشاء الدعوة وتسليم الرابط'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an existing pending invite honors its persisted cooldown', (
    tester,
  ) async {
    final existingInvite = _invite(
      weddingPlanId: 'plan-1',
      role: 'VIEWER',
      deliveryStatus: 'UNCERTAIN',
      deliveryRetryAvailableAt: DateTime.now().add(const Duration(seconds: 60)),
    );
    final api = _FakeSharingApi(
      createDeliveryStatus: 'DELIVERED',
      existingInvites: [existingInvite],
    );
    await _pumpScreen(tester, provider: SharingProvider(api));

    await tester.enterText(find.byType(TextFormField).first, '777123456');
    await tester.tap(find.text('إرسال دعوة المشاركة'));
    await tester.pump();

    expect(api.createCalls, 0);
    expect(api.reissueCalls, 0);
    expect(find.textContaining('الدعوة محفوظة لهذا الرقم'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'direct navigation refreshes invite state for the current plan only',
    (tester) async {
      final api = _FakeSharingApi(
        createDeliveryStatus: 'DELIVERED',
        invitesByPlan: {
          'plan-old': [
            _invite(
              id: 'invite-old',
              weddingPlanId: 'plan-old',
              role: 'VIEWER',
              deliveryStatus: 'NOT_REQUESTED',
            ),
          ],
          'plan-new': [
            _invite(
              id: 'invite-new',
              weddingPlanId: 'plan-new',
              role: 'VIEWER',
              deliveryStatus: 'NOT_REQUESTED',
            ),
          ],
        },
      );
      final provider = SharingProvider(api);
      await provider.loadMembers('plan-old');

      await _pumpScreen(tester, provider: provider, weddingPlanId: 'plan-new');
      await tester.enterText(find.byType(TextFormField).first, '777123456');
      await tester.tap(find.text('إرسال دعوة المشاركة'));
      await tester.pumpAndSettle();

      expect(api.createCalls, 0);
      expect(api.reissueCalls, 1);
      expect(api.lastReissueInviteId, 'invite-new');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a delayed permission refresh keeps the form alive and submits once',
    (tester) async {
      final permissionBarrier = Completer<void>();
      final api = _FakeSharingApi(
        createDeliveryStatus: 'DELIVERED',
        secondPermissionBarrier: permissionBarrier,
      );
      await _pumpScreen(tester, provider: SharingProvider(api));

      await tester.enterText(find.byType(TextFormField).first, '777123456');
      await tester.tap(find.text('إرسال دعوة المشاركة'));
      await tester.pump();

      permissionBarrier.complete();
      await tester.pumpAndSettle();

      expect(api.createCalls, 1);
      expect(find.byKey(const Key('invite-created-view')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a delayed permission refresh keeps the lookup form alive', (
    tester,
  ) async {
    final permissionBarrier = Completer<void>();
    final api = _FakeSharingApi(
      createDeliveryStatus: 'DELIVERED',
      secondPermissionBarrier: permissionBarrier,
    );
    await _pumpScreen(tester, provider: SharingProvider(api));

    await tester.enterText(find.byType(TextFormField).first, '777123456');
    await tester.tap(find.bySemanticsLabel('بحث عن المستخدم'));
    await tester.pump();

    permissionBarrier.complete();
    await tester.pumpAndSettle();

    expect(api.lookupCalls, 1);
    expect(find.text('أمينة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      final done = find.byKey(const Key('invite-done'));
      await tester.ensureVisible(done);
      await tester.pumpAndSettle();
      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(find.text('هل حفظت رابط الدعوة؟'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required SharingProvider provider,
  String weddingPlanId = 'plan-1',
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
        home: AddSharedMemberScreen(weddingPlanId: weddingPlanId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeSharingApi extends SharingApi {
  _FakeSharingApi({
    required this.createDeliveryStatus,
    this.existingInvites = const [],
    this.invitesByPlan = const {},
    this.secondPermissionBarrier,
  }) : super(ApiClient(tokenProvider: () async => null));

  final String createDeliveryStatus;
  final List<PlanInvite> existingInvites;
  final Map<String, List<PlanInvite>> invitesByPlan;
  final Completer<void>? secondPermissionBarrier;
  int createCalls = 0;
  int reissueCalls = 0;
  int permissionCalls = 0;
  int lookupCalls = 0;
  String? lastReissueInviteId;
  String? lastReissueRole;
  bool? lastReissueCanManageTasks;

  @override
  Future<List<SharedMember>> getSharedMembers(String weddingPlanId) async {
    return const [];
  }

  @override
  Future<List<PlanInvite>> getPlanInvites(String weddingPlanId) async {
    return invitesByPlan[weddingPlanId] ?? existingInvites;
  }

  @override
  Future<PlanAccessPermissions> getMyPlanPermissions(
    String weddingPlanId,
  ) async {
    permissionCalls += 1;
    if (permissionCalls == 2) await secondPermissionBarrier?.future;
    return PlanAccessPermissions.owner(weddingPlanId: weddingPlanId);
  }

  @override
  Future<SharedUserLookup> lookupUserByPhone(
    String weddingPlanId,
    String phone,
  ) async {
    lookupCalls += 1;
    return const SharedUserLookup(
      id: 'invitee-1',
      name: 'أمينة',
      phone: '+967777123456',
    );
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
      deliveryRetryAvailableAt: createDeliveryStatus == 'DELIVERED'
          ? null
          : DateTime.now().add(const Duration(seconds: 60)),
    );
  }

  @override
  Future<PlanInvite> reissuePlanInvite({
    required String weddingPlanId,
    required String inviteId,
    String? role,
    bool? canViewMoney,
    bool? canEditPlan,
    bool? canManageTasks,
    bool? canManageGuests,
    bool? canManageProviders,
    bool? canInviteMembers,
    bool? canManageMoney,
    bool? receiveNotifications,
  }) async {
    reissueCalls += 1;
    lastReissueInviteId = inviteId;
    lastReissueRole = role;
    lastReissueCanManageTasks = canManageTasks;
    return _invite(
      id: inviteId,
      weddingPlanId: weddingPlanId,
      role: role ?? 'VIEWER',
      deliveryStatus: 'DELIVERED',
      canViewMoney: canViewMoney ?? false,
      canEditPlan: canEditPlan ?? false,
      canManageTasks: canManageTasks ?? false,
      canManageGuests: canManageGuests ?? false,
      canManageProviders: canManageProviders ?? false,
      canInviteMembers: canInviteMembers ?? false,
      canManageMoney: canManageMoney ?? false,
    );
  }
}

PlanInvite _invite({
  String id = 'invite-1',
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
  DateTime? deliveryRetryAvailableAt,
}) {
  return PlanInvite(
    id: id,
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
    deliveryRetryAvailableAt: deliveryRetryAvailableAt,
    phone: '+967777123456',
    name: 'أمينة',
    inviterName: 'رشاد',
    weddingPlanTitle: 'عرس رشاد وسارة',
  );
}
