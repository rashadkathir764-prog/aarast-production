import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/sharing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// g06 «أضف مشارك», opened by the add route over the participants list.

void main() {
  testWidgets(
    'the helper preset sends HELPER with its flags for 7 days, once',
    (tester) async {
      final api = _FakeSharingApi(createDeliveryStatus: 'DELIVERED');
      final provider = SharingProvider(api);
      await _pumpScreen(tester, provider: provider);

      expect(find.text('أضف مشارك'), findsWidgets);
      await _fill(tester, name: 'صالح', phone: '771554220');
      await tester.tap(find.byKey(const ValueKey('participant-send')));
      await tester.tap(
        find.byKey(const ValueKey('participant-send')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(api.createCalls, 1);
      final sent = api.lastCreate!;
      expect(sent['role'], 'HELPER');
      expect(sent['name'], 'صالح');
      expect(sent['phone'], '771554220');
      expect(sent['canManageTasks'], isTrue);
      expect(sent['canManageGuests'], isTrue);
      expect(sent['canManageProviders'], isTrue);
      expect(sent['canViewMoney'], isFalse);
      expect(sent['canManageMoney'], isFalse);
      expect(sent['canEditPlan'], isFalse);
      expect(sent['canInviteMembers'], isFalse);
      expect(sent['expiresInDays'], 7);
      // Delivered: the sheet closes and says so.
      expect(find.byKey(const ValueKey('participant-send')), findsNothing);
      expect(find.textContaining('وصلته الدعوة على واتساب'), findsOneWidget);
      expect(provider.invites.single.token, provider.invites.single.id);
      await _settleToast(tester);
    },
  );

  testWidgets('each ready role maps to today\'s role and flags (C63)', (
    tester,
  ) async {
    final api = _FakeSharingApi(createDeliveryStatus: 'DELIVERED');
    await _pumpScreen(tester, provider: SharingProvider(api));

    // Only the three roles of today; no bride and no rafd writer.
    expect(find.text('العروسة'), findsNothing);
    expect(find.text('كاتب الرفد'), findsNothing);
    expect(find.text('الرفد'), findsNothing);
    expect(find.textContaining('أقساط'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('participant-preset-FAMILY')));
    await tester.pump();
    await _fill(tester, name: 'الوالد', phone: '777123456');
    await tester.tap(find.byKey(const ValueKey('participant-send')));
    await tester.pumpAndSettle();
    expect(api.lastCreate!['role'], 'FAMILY');
    expect(api.lastCreate!['canManageTasks'], isTrue);
    expect(api.lastCreate!['canManageGuests'], isTrue);
    expect(api.lastCreate!['canManageProviders'], isFalse);
    expect(api.lastCreate!['canViewMoney'], isFalse);
    await _settleToast(tester);
  });

  testWidgets('«يشوف بس» sends VIEWER with no section rights', (tester) async {
    final api = _FakeSharingApi(createDeliveryStatus: 'DELIVERED');
    await _pumpScreen(tester, provider: SharingProvider(api));

    await tester.tap(find.byKey(const ValueKey('participant-preset-VIEWER')));
    await tester.pump();
    await _fill(tester, name: 'عادل', phone: '777123456');
    await tester.tap(find.byKey(const ValueKey('participant-send')));
    await tester.pumpAndSettle();
    final sent = api.lastCreate!;
    expect(sent['role'], 'VIEWER');
    for (final flag in [
      'canManageTasks',
      'canManageGuests',
      'canManageProviders',
      'canViewMoney',
      'canManageMoney',
    ]) {
      expect(sent[flag], isFalse, reason: flag);
    }
    await _settleToast(tester);
  });

  testWidgets('money has three levels; the other sections have two', (
    tester,
  ) async {
    final api = _FakeSharingApi(createDeliveryStatus: 'DELIVERED');
    await _pumpScreen(tester, provider: SharingProvider(api));

    Finder level(String section, String word) => find.descendant(
      of: find.byKey(ValueKey('participant-level-$section')),
      matching: find.text(word),
    );
    for (final section in ['المهام', 'الضيوف', 'المزودين']) {
      expect(level(section, 'لا'), findsOneWidget, reason: section);
      expect(level(section, 'يعدّل'), findsOneWidget, reason: section);
      expect(level(section, 'يشوف'), findsNothing, reason: section);
    }
    expect(level('المال', 'لا'), findsOneWidget);
    expect(level('المال', 'يشوف'), findsOneWidget);
    expect(level('المال', 'يعدّل'), findsOneWidget);

    // «يشوف» shows money without changing it; tasks off.
    await tester.tap(level('المال', 'يشوف'));
    await tester.pump();
    await tester.tap(level('المهام', 'لا'));
    await tester.pump();
    await _fill(tester, name: 'صالح', phone: '777123456');
    await tester.tap(find.byKey(const ValueKey('participant-send')));
    await tester.pumpAndSettle();
    expect(api.lastCreate!['role'], 'HELPER');
    expect(api.lastCreate!['canViewMoney'], isTrue);
    expect(api.lastCreate!['canManageMoney'], isFalse);
    expect(api.lastCreate!['canManageTasks'], isFalse);
    await _settleToast(tester);
  });

  testWidgets('«المال: يعدّل» sends both money flags', (tester) async {
    final api = _FakeSharingApi(createDeliveryStatus: 'DELIVERED');
    await _pumpScreen(tester, provider: SharingProvider(api));

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('participant-level-المال')),
        matching: find.text('يعدّل'),
      ),
    );
    await tester.pump();
    await _fill(tester, name: 'صالح', phone: '777123456');
    await tester.tap(find.byKey(const ValueKey('participant-send')));
    await tester.pumpAndSettle();
    expect(api.lastCreate!['canViewMoney'], isTrue);
    expect(api.lastCreate!['canManageMoney'], isTrue);
    await _settleToast(tester);
  });

  testWidgets('a wrong number is caught before anything is sent', (
    tester,
  ) async {
    final api = _FakeSharingApi(createDeliveryStatus: 'DELIVERED');
    await _pumpScreen(tester, provider: SharingProvider(api));

    await _fill(tester, name: 'صالح', phone: '12');
    await tester.tap(find.byKey(const ValueKey('participant-send')));
    await tester.pumpAndSettle();
    expect(api.createCalls, 0);
    expect(find.text('اكتب رقم جوال يمني صحيح'), findsOneWidget);
  });

  testWidgets('failed delivery keeps the sheet open with the link to copy', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
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
    final api = _FakeSharingApi(createDeliveryStatus: 'UNAVAILABLE');
    await _pumpScreen(tester, provider: SharingProvider(api));

    await _fill(tester, name: 'أمينة', phone: '777123456');
    await tester.tap(find.byKey(const ValueKey('participant-send')));
    await tester.pumpAndSettle();

    expect(api.createCalls, 1);
    expect(find.byKey(const ValueKey('invite-created-view')), findsOneWidget);
    expect(find.text('الدعوة جاهزة'), findsOneWidget);
    expect(find.textContaining('ما قدرنا نرسلها على واتساب'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('invite-created-view')),
        matching: find.textContaining('الرابط يشتغل 7 أيام'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('invite-copy-link')));
    await tester.pumpAndSettle();
    expect(find.textContaining('نسخنا الرابط'), findsOneWidget);
    // The first link is copied as it is; no new link was minted.
    expect(copied, endsWith('abcdefghijklmnopqrstuvwxyzABCDEFGH123456789'));
    await _settleToast(tester);
    await tester.tap(find.byKey(const ValueKey('invite-done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invite-created-view')), findsNothing);
  });

  testWidgets('uncertain delivery never claims WhatsApp delivered it', (
    tester,
  ) async {
    final api = _FakeSharingApi(createDeliveryStatus: 'UNCERTAIN');
    await _pumpScreen(tester, provider: SharingProvider(api));

    await _fill(tester, name: 'أمينة', phone: '777123456');
    await tester.tap(find.byKey(const ValueKey('participant-send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('invite-created-view')), findsOneWidget);
    expect(find.textContaining('ما تأكدنا إنها وصلته'), findsOneWidget);
    expect(find.textContaining('وصلته الدعوة'), findsNothing);
    expect(find.byKey(const ValueKey('invite-copy-link')), findsOneWidget);
  });

  testWidgets(
    'a number already waiting gets a new link with the chosen levels',
    (tester) async {
      final api = _FakeSharingApi(
        createDeliveryStatus: 'DELIVERED',
        existingInvites: [
          _invite(
            weddingPlanId: 'plan-1',
            role: 'VIEWER',
            deliveryStatus: 'UNAVAILABLE',
          ),
        ],
      );
      await _pumpScreen(tester, provider: SharingProvider(api));

      await tester.tap(find.byKey(const ValueKey('participant-preset-FAMILY')));
      await tester.pump();
      await _fill(tester, name: 'أمينة', phone: '777123456');
      await tester.tap(find.byKey(const ValueKey('participant-send')));
      await tester.pumpAndSettle();

      expect(api.createCalls, 0);
      expect(api.reissueCalls, 1);
      expect(api.lastReissueRole, 'FAMILY');
      expect(api.lastReissueCanManageTasks, isTrue);
      expect(find.textContaining('والقديم ما عاد يشتغل'), findsOneWidget);
      await _settleToast(tester);
    },
  );

  testWidgets('a number already waiting honors its persisted cooldown', (
    tester,
  ) async {
    final api = _FakeSharingApi(
      createDeliveryStatus: 'DELIVERED',
      existingInvites: [
        _invite(
          weddingPlanId: 'plan-1',
          role: 'VIEWER',
          deliveryStatus: 'UNCERTAIN',
          deliveryRetryAvailableAt: DateTime.now().add(
            const Duration(seconds: 60),
          ),
        ),
      ],
    );
    await _pumpScreen(tester, provider: SharingProvider(api));

    await _fill(tester, name: 'أمينة', phone: '777123456');
    await tester.tap(find.byKey(const ValueKey('participant-send')));
    await tester.pump();

    expect(api.createCalls, 0);
    expect(api.reissueCalls, 0);
    expect(find.textContaining('تقدر ترسل له رابط جديد بعد'), findsOneWidget);
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('only the current plan\'s waiting invite is reissued', (
    tester,
  ) async {
    final api = _FakeSharingApi(
      createDeliveryStatus: 'DELIVERED',
      invitesByPlan: {
        'plan-old': [
          _invite(
            id: 'invite-old',
            weddingPlanId: 'plan-old',
            role: 'VIEWER',
            deliveryStatus: 'UNAVAILABLE',
          ),
        ],
        'plan-new': [
          _invite(
            id: 'invite-new',
            weddingPlanId: 'plan-new',
            role: 'VIEWER',
            deliveryStatus: 'UNAVAILABLE',
          ),
        ],
      },
    );
    final provider = SharingProvider(api);
    await provider.loadMembers('plan-old');

    await _pumpScreen(tester, provider: provider, weddingPlanId: 'plan-new');
    await _fill(tester, name: 'أمينة', phone: '777123456');
    await tester.tap(find.byKey(const ValueKey('participant-send')));
    await tester.pumpAndSettle();

    expect(api.createCalls, 0);
    expect(api.reissueCalls, 1);
    expect(api.lastReissueInviteId, 'invite-new');
    await _settleToast(tester);
  });

  testWidgets('clipboard failure shows the one-time link to copy by hand', (
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

    await _pumpScreen(
      tester,
      provider: SharingProvider(
        _FakeSharingApi(createDeliveryStatus: 'UNAVAILABLE'),
      ),
    );
    await _fill(tester, name: 'أمينة', phone: '777123456');
    await tester.tap(find.byKey(const ValueKey('participant-send')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('invite-copy-link')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('invite-link-manual-copy-fallback')),
      findsOneWidget,
    );
    expect(
      find.textContaining('abcdefghijklmnopqrstuvwxyzABCDEFGH123456789'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _fill(
  WidgetTester tester, {
  required String name,
  required String phone,
}) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(const ValueKey('participant-name')),
      matching: find.byType(TextField),
    ),
    name,
  );
  await tester.enterText(
    find.descendant(
      of: find.byKey(const ValueKey('participant-phone-field')),
      matching: find.byType(TextField),
    ),
    phone,
  );
  await tester.pump();
  await tester.ensureVisible(find.byKey(const ValueKey('participant-send')));
  await tester.pumpAndSettle();
}

Future<void> _settleToast(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required SharingProvider provider,
  String weddingPlanId = 'plan-1',
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1600);
  addTearDown(tester.view.reset);
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
        home: SharingScreen(weddingPlanId: weddingPlanId, startAdding: true),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(find.byType(JourneyLevelSwitch), findsNWidgets(4));
}

class _FakeSharingApi extends SharingApi {
  _FakeSharingApi({
    required this.createDeliveryStatus,
    this.existingInvites = const [],
    this.invitesByPlan = const {},
  }) : super(ApiClient(tokenProvider: () async => null));

  final String createDeliveryStatus;
  final List<PlanInvite> existingInvites;
  final Map<String, List<PlanInvite>> invitesByPlan;
  int createCalls = 0;
  int reissueCalls = 0;
  Map<String, Object?>? lastCreate;
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
    int expiresInDays = 7,
  }) async {
    createCalls += 1;
    lastCreate = {
      'phone': phone,
      'name': name,
      'role': role,
      'canViewMoney': canViewMoney || canManageMoney,
      'canEditPlan': canEditPlan,
      'canManageTasks': canManageTasks,
      'canManageGuests': canManageGuests,
      'canManageProviders': canManageProviders,
      'canInviteMembers': canInviteMembers,
      'canManageMoney': canManageMoney,
      'expiresInDays': expiresInDays,
    };
    return _invite(
      weddingPlanId: weddingPlanId,
      role: role,
      deliveryStatus: createDeliveryStatus,
      canManageTasks: canManageTasks,
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
      canManageTasks: canManageTasks ?? false,
    );
  }
}

PlanInvite _invite({
  String id = 'invite-1',
  required String weddingPlanId,
  required String role,
  required String deliveryStatus,
  bool canManageTasks = false,
  DateTime? deliveryRetryAvailableAt,
}) {
  return PlanInvite(
    id: id,
    weddingPlanId: weddingPlanId,
    token: 'abcdefghijklmnopqrstuvwxyzABCDEFGH123456789',
    role: role,
    status: 'PENDING',
    expiresAt: DateTime(2026, 8),
    canViewMoney: false,
    canEditPlan: false,
    canManageTasks: canManageTasks,
    canManageGuests: false,
    canManageProviders: false,
    canInviteMembers: false,
    canManageMoney: false,
    deliveryStatus: deliveryStatus,
    deliveryRetryAvailableAt: deliveryRetryAvailableAt,
    phone: '+967777123456',
    name: 'أمينة',
    inviterName: 'رشاد',
    weddingPlanTitle: 'عرس رشاد وسارة',
  );
}
