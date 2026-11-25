import 'package:aarast_mobile/core/diagnostics/crash_report_switch.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/preferences/device_preferences.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/session/session_teardown_coordinator.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/settings/data/settings_api.dart';
import 'package:aarast_mobile/features/settings/models/account_deletion_impact.dart';
import 'package:aarast_mobile/core/utils/app_clock.dart';
import 'package:aarast_mobile/features/settings/screens/delete_account_screen.dart';
import 'package:aarast_mobile/features/settings/screens/deletion_pending_screen.dart';
import 'package:aarast_mobile/features/settings/screens/privacy_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/app_route_table.dart';

// D63: w05 «حذف الحساب» and w40 «الخصوصية» against the server's answers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _pendingScreenTests();

  testWidgets(
    'w05 names what goes and who is told, and asks only after «حذف»',
    (tester) async {
      _tallPhone(tester);
      final world = await _World.create(
        impact: const AccountDeletionImpact(
          graceDays: 30,
          ownedPlans: [
            DeletionPlanImpact(
              id: 'plan-1',
              title: 'عرس محمد',
              memberNames: ['صالح', 'الوالد'],
              upcomingBookings: 1,
            ),
          ],
          memberOfPlans: 0,
          provider: null,
          blockedByUpcomingBookings: false,
        ),
      );
      final opened = <Uri>[];
      await tester.pumpWidget(
        world.app(
          DeleteAccountScreen(
            downloadOpener: (link) async {
              opened.add(link);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('متأكد يا محمد؟'), findsOneWidget);
      expect(find.text('خطتك ومالك ومهامك وضيوفك تنحذف كلها'), findsOneWidget);
      expect(
        find.text('صالح والوالد يطلعون من الخطة، ويوصلهم تنبيه'),
        findsOneWidget,
      );
      expect(
        find.text('الحجوزات المؤكدة تنلغي، ونبلّغ المزودين'),
        findsOneWidget,
      );
      expect(find.text('عندك 30 يوم ترجع فيها لو غيّرت رأيك'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('delete-account-download')));
      await tester.pumpAndSettle();
      expect(opened.single.path, startsWith('/api/v1/data-exports/'));

      final button = find.byKey(const ValueKey('delete-account-confirm'));
      await tester.tap(button);
      await tester.pump();
      expect(world.repository.requestCalls, 0);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('delete-account-input')),
          matching: find.byType(EditableText),
        ),
        'حذف',
      );
      await tester.pump();
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(world.repository.requestCalls, 1);
      expect(world.controller.deletionPending, isTrue);
      expect(find.text('HOME'), findsOneWidget);
    },
  );

  testWidgets('w05 refuses a provider with weddings still to do (B-33)', (
    tester,
  ) async {
    _tallPhone(tester);
    final world = await _World.create(
      impact: const AccountDeletionImpact(
        graceDays: 30,
        ownedPlans: [],
        memberOfPlans: 1,
        provider: DeletionProviderImpact(
          businessName: 'ضيافة الأصالة',
          upcomingBookings: 3,
        ),
        blockedByUpcomingBookings: true,
      ),
    );
    await tester.pumpWidget(world.app(const DeleteAccountScreen()));
    await tester.pumpAndSettle();

    expect(find.text('حسابك وبياناتك تنحذف كلها'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('delete-account-blocked')),
      findsOneWidget,
    );
    expect(find.textContaining('3 حجوزات جاية'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('delete-account-input')),
        matching: find.byType(EditableText),
      ),
      'حذف',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('delete-account-confirm')));
    await tester.pumpAndSettle();
    expect(world.repository.requestCalls, 0);
  });

  // RA-MO-160: unread, the switch said «الاسم الأول بس» as if known.
  testWidgets('w40 says when the review name could not be read', (
    tester,
  ) async {
    _tallPhone(tester);
    final world = await _World.create();
    world.settings.failReviewRead = true;
    await tester.pumpWidget(world.app(const PrivacyScreen()));
    await tester.pumpAndSettle();

    expect(find.text('ما قدرنا نقرأ اختيارك الحين'), findsOneWidget);
    expect(find.text('الاسم الأول بس'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets(
    'w40 keeps what the product has: reports, the review name, the download',
    (tester) async {
      _tallPhone(tester);
      final world = await _World.create(reviewFirstNameOnly: false);
      final opened = <Uri>[];
      await tester.pumpWidget(
        world.app(
          PrivacyScreen(
            downloadOpener: (link) async {
              opened.add(link);
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('أرسل تقارير الأعطال'), findsOneWidget);
      expect(find.text('اسمك كامل'), findsOneWidget);
      // No open plan here: the assistant's row waits for one.
      expect(find.byKey(const ValueKey('privacy-assistant')), findsNothing);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('privacy-review-name')),
          matching: find.bySemanticsLabel('اسمي في التقييمات'),
        ),
      );
      await tester.pumpAndSettle();
      expect(world.settings.savedReviewFirstNameOnly, [true]);
      expect(find.text('الاسم الأول بس'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('privacy-crash-reports')),
          matching: find.bySemanticsLabel('أرسل تقارير الأعطال'),
        ),
      );
      await tester.pumpAndSettle();
      expect(world.preferences.crashReports, isFalse);
      expect(CrashReportSwitch.enabled, isFalse);

      await tester.tap(find.byKey(const ValueKey('privacy-download')));
      await tester.pumpAndSettle();
      expect(opened, hasLength(1));

      await tester.tap(find.byKey(const ValueKey('privacy-delete-account')));
      await tester.pumpAndSettle();
      expect(find.text('DELETE'), findsOneWidget);
      CrashReportSwitch.set(true);
    },
  );

  // Item 9 (RA-BE-161): the consent is the account's. With no plan the
  // reader reads (removed from the partner's plan, say), the row was hidden
  // and the stored consent could never be taken back.
  testWidgets('w40 shows and takes back the assistant consent with no plan', (
    tester,
  ) async {
    _tallPhone(tester);
    final world = await _World.create();
    final client = _AccountConsentClient();
    await tester.pumpWidget(world.app(const PrivacyScreen(), client: client));
    await tester.pumpAndSettle();

    expect(client.reads, ['/api/v1/me/assistant/consent']);
    final row = find.byKey(const ValueKey('privacy-assistant'));
    expect(row, findsOneWidget);
    expect(find.text('المساعد الذكي'), findsOneWidget);
    expect(find.text('3 أسئلة في اليوم'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: row,
        matching: find.bySemanticsLabel('المساعد الذكي'),
      ),
    );
    await tester.pumpAndSettle();
    expect(client.deletes, ['/api/v1/me/assistant/consent']);
    // Without a plan it is taken back only; turning it on needs a plan.
    await tester.tap(
      find.descendant(
        of: row,
        matching: find.bySemanticsLabel('المساعد الذكي'),
      ),
    );
    await tester.pumpAndSettle();
    expect(client.deletes, hasLength(1));
    expect(client.puts, isEmpty);
  });

  testWidgets('w40 shows no assistant row when the account never agreed', (
    tester,
  ) async {
    _tallPhone(tester);
    final world = await _World.create();
    final client = _AccountConsentClient(consentedAt: null);
    await tester.pumpWidget(world.app(const PrivacyScreen(), client: client));
    await tester.pumpAndSettle();
    expect(client.reads, ['/api/v1/me/assistant/consent']);
    expect(find.byKey(const ValueKey('privacy-assistant')), findsNothing);
  });
}

/// Item 9: the server's account route for the assistant consent.
class _AccountConsentClient extends ApiClient {
  _AccountConsentClient({this.consentedAt = '2026-11-20T10:00:00.000Z'})
    : super(tokenProvider: () async => null);

  String? consentedAt;
  final reads = <String>[];
  final deletes = <String>[];
  final puts = <String>[];

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    reads.add(path);
    return {'consentedAt': consentedAt, 'dailyLimit': 3};
  }

  @override
  Future<Map<String, dynamic>> deleteJson(String path) async {
    deletes.add(path);
    consentedAt = null;
    return {'consentedAt': null};
  }

  @override
  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    puts.add(path);
    return {'consentedAt': consentedAt};
  }
}

/// w06 counts the real 30 days (C4: requested 19 Oct, erased 18 Nov).
void _pendingScreenTests() {
  testWidgets('w06 says the day of the erasure and the days left', (
    tester,
  ) async {
    _tallPhone(tester);
    pinAppClock(DateTime(2026, 10, 22, 10));
    addTearDown(resetAppClock);
    final world = await _World.create(
      pending: (
        requestedAt: DateTime(2026, 10, 19, 9),
        scheduledFor: DateTime(2026, 11, 18, 9),
      ),
    );
    await tester.pumpWidget(world.app(const DeletionPendingScreen()));
    await tester.pumpAndSettle();

    expect(find.text('حسابك ينحذف بعد 27 يوم'), findsOneWidget);
    expect(
      find.text(
        'طلبت الحذف 19 أكتوبر. لين 18 نوفمبر تقدر ترجع وكل شيء كما هو.',
      ),
      findsOneWidget,
    );
    expect(find.text('تراجعت، رجّع حسابي'), findsOneWidget);
    expect(
      find.text('ما أحد يقدر يدخل خطتك خلال هذي المدة، ولا توصلك تذكيرات.'),
      findsOneWidget,
    );
  });

  // RA-MO-157 (C59): «اطلع» here signed out at once, wiping what the phone
  // had not sent; g11 names it first, and so does this screen now.
  testWidgets('w06 names unsent changes before signing out', (tester) async {
    _tallPhone(tester);
    pinAppClock(DateTime(2026, 10, 22, 10));
    addTearDown(resetAppClock);
    final world = await _World.create(
      pending: (
        requestedAt: DateTime(2026, 10, 19, 9),
        scheduledFor: DateTime(2026, 11, 18, 9),
      ),
    );
    SharedPreferences.setMockInitialValues({});
    final database = JsonLocalDatabase(await SharedPreferences.getInstance());
    await database.initialize();
    final sync = _UnsentSync(database);
    await tester.pumpWidget(
      world.app(const DeletionPendingScreen(), sync: sync),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deletion-pending-sign-out')));
    await tester.pumpAndSettle();
    expect(
      find.text('تغييرين على جوالك ما انرسل، ويضيع لو طلعت الحين.'),
      findsOneWidget,
    );
    await tester.tap(find.text('رجوع'));
    await tester.pumpAndSettle();
    expect(world.controller.user, isNotNull);
  });

  // RA-BE-56: the 30 days before erasure are when someone leaving wants
  // their data; the wait screen had no way to it and the server refused it.
  testWidgets('w06 downloads the account\'s data during the wait', (
    tester,
  ) async {
    _tallPhone(tester);
    pinAppClock(DateTime(2026, 10, 22, 10));
    addTearDown(resetAppClock);
    final world = await _World.create(
      pending: (
        requestedAt: DateTime(2026, 10, 19, 9),
        scheduledFor: DateTime(2026, 11, 18, 9),
      ),
    );
    final opened = <Uri>[];
    await tester.pumpWidget(
      world.app(
        DeletionPendingScreen(
          openDownload: (link) async {
            opened.add(link);
            return true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('deletion-pending-download')));
    await tester.pumpAndSettle();

    expect(opened, [
      Uri.parse('https://api.example.test/api/v1/data-exports/token'),
    ]);
  });
}

/// The whole screen in one frame, so every row is built.
void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(780, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _World {
  _World({
    required this.controller,
    required this.repository,
    required this.settings,
    required this.preferences,
  });

  final AuthController controller;
  final _Repository repository;
  final _Settings settings;
  final DevicePreferences preferences;

  static Future<_World> create({
    AccountDeletionImpact? impact,
    bool reviewFirstNameOnly = true,
    ({DateTime requestedAt, DateTime scheduledFor})? pending,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final shared = await SharedPreferences.getInstance();
    final storage = AuthStorage(shared);
    final client = ApiClient(tokenProvider: storage.readAccessToken);
    final repository = _Repository(client, storage)
      ..current = pending == null
          ? _Repository.user
          : _Repository.user.withDeletion(
              requestedAt: pending.requestedAt,
              scheduledFor: pending.scheduledFor,
            );
    final controller = AuthController(
      repository,
      sessionTeardownCoordinator: SessionTeardownCoordinator(
        auth: repository,
        clearLocalAccountData: () async {},
        clearGuestDraft: () async {},
      ),
    );
    await controller.restoreSession();
    return _World(
      controller: controller,
      repository: repository,
      settings: _Settings(client, impact, reviewFirstNameOnly),
      preferences: DevicePreferences(shared),
    );
  }

  Widget app(Widget screen, {OfflineSyncService? sync, ApiClient? client}) {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => screen),
        GoRoute(path: appRoute('/home'), builder: (_, _) => const Text('HOME')),
        GoRoute(path: appRoute('/more'), builder: (_, _) => const Text('MORE')),
        GoRoute(
          path: appRoute('/settings/delete-account'),
          builder: (_, _) => const Text('DELETE'),
        ),
      ],
    );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: controller),
        Provider<SettingsApi>.value(value: settings),
        ChangeNotifierProvider<DevicePreferences>.value(value: preferences),
        if (sync != null)
          ChangeNotifierProvider<OfflineSyncService>.value(value: sync),
        if (client != null) Provider<ApiClient>.value(value: client),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }
}

/// A phone holding two changes not sent yet.
class _UnsentSync extends OfflineSyncService {
  _UnsentSync(JsonLocalDatabase database)
    : super(
        database: database,
        apiClient: ApiClient(tokenProvider: () async => null),
      );

  @override
  int get unsyncedCount => 2;
}

class _Settings extends SettingsApi {
  _Settings(super.client, this.impact, this.reviewFirstNameOnlyValue);

  final AccountDeletionImpact? impact;
  bool reviewFirstNameOnlyValue;
  final savedReviewFirstNameOnly = <bool>[];

  @override
  Future<AccountDeletionImpact> deletionImpact() async => impact!;

  /// The read of the review name fails (no network).
  bool failReviewRead = false;

  @override
  Future<bool> reviewFirstNameOnly() async {
    if (failReviewRead) {
      throw const ApiException('ما وصلنا', isNetworkFailure: true);
    }
    return reviewFirstNameOnlyValue;
  }

  @override
  Future<bool> setReviewFirstNameOnly(bool value) async {
    savedReviewFirstNameOnly.add(value);
    reviewFirstNameOnlyValue = value;
    return value;
  }

  @override
  Future<Uri> createDataExport() async =>
      Uri.parse('https://api.example.test/api/v1/data-exports/token');
}

class _Repository extends AuthRepository {
  _Repository(super.apiClient, super.authStorage);

  static const user = SafeUser(
    id: 'user-a',
    name: 'محمد الحمدي',
    role: 'USER',
    status: 'ACTIVE',
  );

  int requestCalls = 0;
  SafeUser current = user;

  @override
  SafeUser? readCachedUser() => current;

  @override
  Future<String?> readAccessToken() async => 'access-a';

  @override
  Future<SafeUser> me() async => current;

  @override
  Future<({DateTime requestedAt, DateTime scheduledFor})>
  requestAccountDeletion() async {
    requestCalls += 1;
    final now = appNow();
    return (requestedAt: now, scheduledFor: now.add(const Duration(days: 30)));
  }

  @override
  Future<void> captureRemoteCredentials(SessionAuthTeardownLease lease) async {}

  @override
  Future<void> clearLocalSession(SessionAuthTeardownLease lease) async {}

  @override
  Future<void> revokeRemoteSession(
    SessionAuthTeardownLease lease, {
    required CancelToken cancelToken,
  }) async {}
}
