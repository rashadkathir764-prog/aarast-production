import 'dart:async';
import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/widgets/aarast_pressable.dart';
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

void main() {
  group('Phase C sharing screens V3 contract', () {
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
      },
    );
  });

  group('Phase C sharing screens rendering', () {
    testWidgets('g01 with x07: members by stored flags, then who waits', (
      tester,
    ) async {
      _setTallView(tester);
      final api = _FakeSharingApi(
        members: [
          _member(id: 'member-1', userName: 'أمينة', canViewMoney: true),
        ],
        invites: [_invite()],
      );

      await _pumpWithAuth(
        tester,
        provider: SharingProvider(api),
        child: const SharingScreen(weddingPlanId: _planId),
      );
      await tester.pumpAndSettle();

      expect(find.text('المشاركين'), findsOneWidget);
      expect(find.text('مين معك، ومين لسا'), findsOneWidget);
      expect(find.text('أمينة'), findsOneWidget);
      // The line is built from the stored flags: no section, money seen.
      expect(find.text('يشوف بس'), findsWidgets);
      expect(find.text('يشوف المال'), findsOneWidget);
      expect(find.text('معك'), findsOneWidget);
      expect(find.text('ينتظرون'), findsOneWidget);
      expect(find.text('خالد'), findsOneWidget);
      expect(
        find.text('الدعوة محفوظة · أرسل له الرابط بأي طريقة'),
        findsOneWidget,
      );
      expect(find.text('انسخ الرابط'), findsOneWidget);
      expect(find.textContaining('الرابط يشتغل 7 أيام'), findsOneWidget);
      // The ready roles of today only (C63); nothing the build cannot do.
      expect(find.text('مساعد'), findsOneWidget);
      expect(find.text('أهل'), findsOneWidget);
      for (final gone in [
        'العروسة',
        'كاتب الرفد',
        'ما فتحها',
        'طلعوا',
        'ويكتب الرفد',
      ]) {
        expect(find.textContaining(gone), findsNothing, reason: gone);
      }
      expect(find.textContaining('أقساط'), findsNothing);
      expect(api.getSharedMembersCalls, 1);
      expect(api.getPlanInvitesCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'owner sharing reconciles an accepted invite when the app resumes',
      (tester) async {
        _setTallView(tester);
        final members = <SharedMember>[];
        final invites = <PlanInvite>[_invite()];
        final api = _FakeSharingApi(members: members, invites: invites);

        await _pumpWithAuth(
          tester,
          provider: SharingProvider(api),
          child: const SharingScreen(weddingPlanId: _planId),
        );
        await tester.pumpAndSettle();

        expect(find.text('ينتظرون'), findsOneWidget);
        expect(api.getSharedMembersCalls, 1);
        expect(api.getPlanInvitesCalls, 1);

        invites.clear();
        members.add(
          _member(id: 'accepted-contributor', userName: 'المساهم المقبول'),
        );

        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(find.text('ينتظرون'), findsNothing);
        expect(find.text('المساهم المقبول'), findsOneWidget);
        expect(api.getSharedMembersCalls, 2);
        expect(api.getPlanInvitesCalls, 2);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'pending invites poll every controlled interval without flicker and stop when resolved',
      (tester) async {
        _setTallView(tester);
        final members = <SharedMember>[];
        final invites = <PlanInvite>[_invite()];
        final refreshGate = Completer<void>();
        final api = _ControlledPollingSharingApi(
          members: members,
          invites: invites,
          refreshGate: refreshGate,
        );
        final provider = SharingProvider(api);

        await _pumpWithAuth(
          tester,
          provider: provider,
          child: const SharingScreen(
            weddingPlanId: _planId,
            pendingInviteRefreshInterval: Duration(seconds: 30),
          ),
        );
        await tester.pumpAndSettle();

        expect(api.getPlanInvitesCalls, 1);
        // Keep a wide margin because pumpAndSettle advances the fake clock
        // while the initial screen animations finish after the timer starts.
        await tester.pump(const Duration(seconds: 20));
        expect(api.getPlanInvitesCalls, 1);

        await tester.pump(const Duration(seconds: 10));
        await tester.pump();
        await tester.pump();

        expect(api.getPlanInvitesCalls, 2);
        expect(find.text('ينتظرون'), findsOneWidget);
        expect(provider.isLoading, isFalse);

        invites.clear();
        members.add(
          _member(id: 'accepted-contributor', userName: 'المساهم المقبول'),
        );
        refreshGate.complete();
        await tester.pumpAndSettle();

        expect(find.text('ينتظرون'), findsNothing);
        expect(find.text('المساهم المقبول'), findsOneWidget);

        await tester.pump(const Duration(seconds: 30));
        await tester.pump();
        expect(api.getPlanInvitesCalls, 2);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'stale pending invites never poll behind a different-plan permission gate',
      (tester) async {
        _setTallView(tester);
        final api = _PlanAwareAccessSharingApi(
          members: const [],
          invites: [_invite()],
        );
        final provider = SharingProvider(api);
        await provider.loadMembers(_planId);

        await _pumpWithAuth(
          tester,
          provider: provider,
          child: const SharingScreen(
            weddingPlanId: 'plan-without-sharing-access',
            pendingInviteRefreshInterval: Duration(seconds: 30),
          ),
        );
        await tester.pumpAndSettle();

        expect(api.accessCalls, 1);
        expect(api.getPlanInvitesCalls, 1);
        await tester.pump(const Duration(seconds: 60));
        await tester.pump();

        expect(api.accessCalls, 1);
        expect(api.getPlanInvitesCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'phone-only participants and invites stay LTR at 320px and 1.3 scale',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 1200);
        addTearDown(tester.view.reset);

        final api = _FakeSharingApi(
          members: [_member(id: 'phone-member', userName: '')],
          invites: [_invite(name: null)],
        );

        await _pumpWithAuth(
          tester,
          provider: SharingProvider(api),
          child: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: SharingScreen(weddingPlanId: _planId),
          ),
        );
        await tester.pumpAndSettle();

        final phoneTexts = tester.widgetList<Text>(find.text('777 123 456'));
        expect(phoneTexts, hasLength(2));
        expect(
          phoneTexts.every((text) => text.textDirection == TextDirection.ltr),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'reissuing a pending invite sends the rotated link from Aarast',
      (tester) async {
        _setTallView(tester);
        final api = _FakeSharingApi(invites: [_invite()]);

        await _pumpWithAuth(
          tester,
          provider: SharingProvider(api),
          child: const SharingScreen(weddingPlanId: _planId),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('pending-invite-reissue-invite-1')),
        );
        await tester.pumpAndSettle();

        expect(api.reissueCalls, 1);
        // J2-13: the new link has the same life; J2-20: said of anyone.
        expect(
          find.text(
            'وصل رابط جديد على واتساب، والقديم ما عاد يشتغل. '
            'الرابط الجديد له 7 أيام.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('وصله'), findsNothing);
        await tester.pump(const Duration(seconds: 6));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a persisted invite cooldown blocks then unlocks reissue', (
      tester,
    ) async {
      _setTallView(tester);
      final api = _FakeSharingApi(
        invites: [
          _invite(
            deliveryStatus: 'UNCERTAIN',
            deliveryRetryAvailableAt: DateTime.now().add(
              const Duration(seconds: 2),
            ),
          ),
        ],
      );

      await _pumpWithAuth(
        tester,
        provider: SharingProvider(api),
        child: const SharingScreen(weddingPlanId: _planId),
      );
      await tester.pumpAndSettle();

      final retryFinder = find.byKey(
        const Key('pending-invite-reissue-invite-1'),
      );
      expect(tester.widget<AarastPressable>(retryFinder).onTap, isNull);
      expect(api.reissueCalls, 0);

      await tester.pump(const Duration(seconds: 2, milliseconds: 100));
      await tester.pump();

      expect(tester.widget<AarastPressable>(retryFinder).onTap, isNotNull);
      await tester.tap(retryFinder);
      await tester.pumpAndSettle();
      expect(api.reissueCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('clipboard failure keeps the rotated bearer visible', (
      tester,
    ) async {
      _setTallView(tester);
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
      final api = _FakeSharingApi(
        invites: [_invite()],
        reissueDeliveryStatus: 'UNAVAILABLE',
      );

      await _pumpWithAuth(
        tester,
        provider: SharingProvider(api),
        child: const SharingScreen(weddingPlanId: _planId),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('pending-invite-reissue-invite-1')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('invite-link-manual-copy-fallback')),
        findsOneWidget,
      );
      expect(
        find.textContaining('abcdefghijklmnopqrstuvwxyzABCDEFGH123456789'),
        findsOneWidget,
      );
      expect(api.reissueCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'copying a link mints a new one and says the old one stops (C31)',
      (tester) async {
        _setTallView(tester);
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
        final api = _FakeSharingApi(
          invites: [_invite(deliveryStatus: 'UNAVAILABLE')],
          reissueDeliveryStatus: 'UNAVAILABLE',
        );

        await _pumpWithAuth(
          tester,
          provider: SharingProvider(api),
          child: const SharingScreen(weddingPlanId: _planId),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('ما وصلته على واتساب · أرسل له الرابط بأي طريقة'),
          findsOneWidget,
        );
        await tester.tap(find.text('انسخ الرابط'));
        await tester.pumpAndSettle();

        expect(api.reissueCalls, 1);
        expect(copied, startsWith('هذا رابطك الجديد، والقديم ما عاد يشتغل'));
        expect(copied, contains('abcdefghijklmnopqrstuvwxyzABCDEFGH123456789'));
        await tester.pump(const Duration(seconds: 6));
      },
    );

    testWidgets('a delivered invite offers «ذكّره» with when it arrived', (
      tester,
    ) async {
      _setTallView(tester);
      final api = _FakeSharingApi(
        invites: [
          _invite(
            deliveryStatus: 'DELIVERED',
            deliveryAttemptedAt: DateTime.now(),
          ),
        ],
      );

      await _pumpWithAuth(
        tester,
        provider: SharingProvider(api),
        child: const SharingScreen(weddingPlanId: _planId),
      );
      await tester.pumpAndSettle();

      expect(find.text('الدعوة وصلت اليوم'), findsOneWidget);
      expect(find.text('ذكّره'), findsOneWidget);
    });

    testWidgets('cancelling a waiting invite asks first, then deletes it', (
      tester,
    ) async {
      _setTallView(tester);
      final api = _FakeSharingApi(invites: [_invite()]);
      final provider = SharingProvider(api);

      await _pumpWithAuth(
        tester,
        provider: provider,
        child: const SharingScreen(weddingPlanId: _planId),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('pending-invite-invite-1')));
      await tester.pumpAndSettle();
      expect(find.text('تلغي دعوة خالد؟'), findsOneWidget);
      expect(api.cancelCalls, 0);

      await tester.tap(
        find.byKey(const ValueKey('pending-invite-cancel-invite-1')),
      );
      await tester.pumpAndSettle();
      expect(api.cancelCalls, 1);
      expect(provider.invites, isEmpty);
      expect(find.text('ينتظرون'), findsNothing);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('each member line says what their stored flags allow', (
      tester,
    ) async {
      _setTallView(tester);
      final helper = SharedMember(
        id: 'helper',
        weddingPlanId: _planId,
        userId: 'user-helper',
        user: const SharedMemberUser(
          id: 'user-helper',
          name: 'صالح',
          phone: '+967771554220',
        ),
        role: 'HELPER',
        canViewMoney: false,
        canManageTasks: true,
        canManageGuests: true,
        canManageMoney: false,
        createdAt: DateTime(2026, 7, 5),
        updatedAt: DateTime(2026, 7, 5),
      );
      final api = _FakeSharingApi(members: [helper]);

      await _pumpWithAuth(
        tester,
        provider: SharingProvider(api),
        child: const SharingScreen(weddingPlanId: _planId),
      );
      await tester.pumpAndSettle();

      expect(find.text('مين يساعدك في عرسك'), findsOneWidget);
      expect(find.text('يساعد في المهام والضيوف · بدون المال'), findsOneWidget);
      expect(find.text('معك'), findsNothing);
      expect(find.text('ينتظرون'), findsNothing);
      // D80: what every participant reads, and what stays the owner's.
      expect(
        find.text(
          'كل مشارك يشوف أسماء الضيوف والمهام والحجوزات، ويعدّل بس في '
          'القسم اللي تفتحه له. أرقام جوالات الضيوف لك ولمن أضافهم، '
          'ومصادر فلوسك وسلفك تبقى لك.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('يشوف بس الأقسام'), findsNothing);
    });

    testWidgets(
      'J2-13: ended, refused and cancelled invites stay in a small closed group',
      (tester) async {
        _setTallView(tester);
        final api = _FakeSharingApi(
          invites: [
            _invite(),
            _invite(id: 'invite-2', name: 'سعيد', status: 'EXPIRED'),
            _invite(id: 'invite-3', name: 'منى', status: 'DECLINED'),
            _invite(id: 'invite-4', name: 'عمر', status: 'CANCELLED'),
          ],
        );

        await _pumpWithAuth(
          tester,
          provider: SharingProvider(api),
          child: const SharingScreen(weddingPlanId: _planId),
        );
        await tester.pumpAndSettle();

        // The waiting one stays where it was.
        expect(find.text('ينتظرون'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('pending-invite-invite-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('pending-invite-invite-2')),
          findsNothing,
        );
        // Under it, the closed ones with their state word.
        expect(find.text('ما اكتملت'), findsOneWidget);
        for (final (id, word) in [
          ('invite-2', 'انتهت'),
          ('invite-3', 'رفض'),
          ('invite-4', 'أُلغيت'),
        ]) {
          expect(
            find.descendant(
              of: find.byKey(ValueKey('closed-invite-$id')),
              matching: find.text(word),
            ),
            findsOneWidget,
            reason: id,
          );
        }
        // A new invite for the ended and the refused; a cancelled one was
        // the owner's own choice.
        expect(
          find.byKey(const ValueKey('closed-invite-resend-invite-2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('closed-invite-resend-invite-3')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('closed-invite-resend-invite-4')),
          findsNothing,
        );
        expect(find.text('أرسل دعوة جديدة'), findsNWidgets(2));

        await tester.ensureVisible(
          find.byKey(const ValueKey('closed-invite-resend-invite-2')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('closed-invite-resend-invite-2')),
        );
        await tester.pumpAndSettle();
        // The add sheet opens on the same person, ready to send.
        expect(find.text('أضف سعيد'), findsOneWidget);
        expect(find.byKey(const ValueKey('participant-send')), findsOneWidget);
        expect(api.reissueCalls, 0);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('J2-20: the permission gate names the plan\'s owner', (
      tester,
    ) async {
      _setTallView(tester);
      final api = _PlanAwareAccessSharingApi(
        members: const [],
        invites: const [],
      );
      await _pumpWithAuth(
        tester,
        provider: SharingProvider(api),
        child: const SharingScreen(weddingPlanId: 'plan-of-someone-else'),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('العريس هو اللي يضيفهم ويحدد ايش يشوف كل واحد.'),
        findsOneWidget,
      );
      expect(find.textContaining('هو اللي يضيفهم ويحدد'), findsOneWidget);
    });
  });
}

const _planId = 'plan-sharing-1';
const _phaseCPaths = [
  'lib/features/sharing/screens/sharing_screen.dart',
  'lib/features/sharing/screens/edit_shared_member_screen.dart',
  'lib/features/sharing/screens/contribution_history_screen.dart',
  'lib/features/sharing/screens/from_family_screen.dart',
  'lib/features/sharing/screens/invite_decision_screen.dart',
  'lib/features/sharing/screens/participant_plan_state_screen.dart',
  'lib/features/sharing/widgets/add_participant_sheet.dart',
  'lib/features/sharing/widgets/participant_access_editor.dart',
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
  bool canViewMoney = false,
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
    canViewMoney: canViewMoney,
    canManageTasks: false,
    canManageMoney: false,
    createdAt: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
  );
}

PlanInvite _invite({
  String id = 'invite-1',
  String status = 'PENDING',
  String? name = 'خالد',
  String deliveryStatus = 'NOT_REQUESTED',
  DateTime? deliveryRetryAvailableAt,
  DateTime? deliveryAttemptedAt,
}) {
  return PlanInvite(
    id: id,
    weddingPlanId: _planId,
    token: 'invite-token',
    role: 'HELPER',
    status: status,
    expiresAt: DateTime(2026, 7, 20),
    canViewMoney: false,
    canEditPlan: false,
    canManageTasks: true,
    canManageGuests: true,
    canManageProviders: false,
    canInviteMembers: false,
    canManageMoney: false,
    deliveryStatus: deliveryStatus,
    deliveryRetryAvailableAt: deliveryRetryAvailableAt,
    deliveryAttemptedAt: deliveryAttemptedAt,
    phone: '+967777123456',
    name: name,
  );
}

class _FakeSharingApi extends SharingApi {
  _FakeSharingApi({
    this.members = const [],
    this.invites = const [],
    this.reissueDeliveryStatus = 'DELIVERED',
  }) : super(ApiClient(tokenProvider: () async => null));

  final List<SharedMember> members;
  final List<PlanInvite> invites;
  final String reissueDeliveryStatus;

  int getSharedMembersCalls = 0;
  int getPlanInvitesCalls = 0;
  int reissueCalls = 0;
  int cancelCalls = 0;

  @override
  Future<void> cancelPlanInvite({
    required String weddingPlanId,
    required String inviteId,
  }) async {
    cancelCalls += 1;
  }

  @override
  Future<PlanAccessPermissions> getMyPlanPermissions(
    String weddingPlanId,
  ) async {
    return PlanAccessPermissions.owner(weddingPlanId: weddingPlanId);
  }

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
    final invite = invites.firstWhere((item) => item.id == inviteId);
    return PlanInvite(
      id: invite.id,
      weddingPlanId: weddingPlanId,
      token: 'abcdefghijklmnopqrstuvwxyzABCDEFGH123456789',
      role: role ?? invite.role,
      status: invite.status,
      expiresAt: invite.expiresAt,
      canViewMoney: canViewMoney ?? invite.canViewMoney,
      canEditPlan: canEditPlan ?? invite.canEditPlan,
      canManageTasks: canManageTasks ?? invite.canManageTasks,
      canManageGuests: canManageGuests ?? invite.canManageGuests,
      canManageProviders: canManageProviders ?? invite.canManageProviders,
      canInviteMembers: canInviteMembers ?? invite.canInviteMembers,
      canManageMoney: canManageMoney ?? invite.canManageMoney,
      deliveryStatus: reissueDeliveryStatus,
      phone: invite.phone,
      name: invite.name,
      inviterName: 'رشاد',
      weddingPlanTitle: 'خطة الاختبار',
    );
  }
}

class _ControlledPollingSharingApi extends _FakeSharingApi {
  _ControlledPollingSharingApi({
    required super.members,
    required super.invites,
    required this.refreshGate,
  });

  final Completer<void> refreshGate;

  @override
  Future<List<SharedMember>> getSharedMembers(String weddingPlanId) async {
    getSharedMembersCalls += 1;
    if (getSharedMembersCalls > 1) await refreshGate.future;
    return members;
  }

  @override
  Future<List<PlanInvite>> getPlanInvites(String weddingPlanId) async {
    getPlanInvitesCalls += 1;
    if (getPlanInvitesCalls > 1) await refreshGate.future;
    return invites;
  }
}

class _PlanAwareAccessSharingApi extends _FakeSharingApi {
  _PlanAwareAccessSharingApi({required super.members, required super.invites});

  int accessCalls = 0;

  @override
  Future<PlanAccessPermissions> getMyPlanPermissions(
    String weddingPlanId,
  ) async {
    accessCalls += 1;
    return weddingPlanId == _planId
        ? PlanAccessPermissions.owner(weddingPlanId: weddingPlanId)
        : PlanAccessPermissions.denied(weddingPlanId: weddingPlanId);
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
