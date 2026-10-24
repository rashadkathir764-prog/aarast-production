import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/chat/data/chat_api.dart';
import 'package:aarast_mobile/features/chat/data/chat_realtime_client.dart';
import 'package:aarast_mobile/features/chat/models/chat_models.dart';
import 'package:aarast_mobile/features/chat/providers/chat_provider.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/provider_portal/data/provider_approval_ledger.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_approved_screen.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_pending_screen.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_portal_screen.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_suspended_screen.dart';
import 'package:aarast_mobile/features/provider_portal/widgets/provider_join_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The review states the portal opens on: p08 while the team reviews, p10
// once after an approval or a claim this phone waited for, and p12 while
// suspended. Each says only what the server keeps.

void main() {
  group('p08 pending', () {
    testWidgets('says when it was sent and that the notice comes here', (
      tester,
    ) async {
      final now = DateTime.now();
      final api = _Api(
        status: 'PENDING',
        createdAt: DateTime(now.year, now.month, now.day, 10),
      );
      await _pumpPortal(tester, api);

      expect(find.byType(ProviderPendingScreen), findsOneWidget);
      expect(find.text('طلبك قيد المراجعة'), findsOneWidget);
      expect(find.text('أرسلته اليوم 10 الصبح. نبلغك هنا.'), findsOneWidget);
      expect(find.text('استوديو ضوء صنعاء'), findsOneWidget);
      expect(find.text('التصوير · صنعاء'), findsOneWidget);
      expect(find.text('ملفك مخفي عن العرسان لين نوافق'), findsOneWidget);
      expect(find.text('تقدر تعدّل بيانات ملفك وأنت تنتظر'), findsOneWidget);
      // No WhatsApp, no review time, no photos before approval (F2).
      expect(find.textContaining('واتساب'), findsNothing);
      expect(find.textContaining('يومين'), findsNothing);
      expect(find.textContaining('تضيف صور'), findsNothing);
      // No tabs while waiting.
      expect(find.text('الطلبات'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('edits the request, previews it and reaches the account', (
      tester,
    ) async {
      final api = _Api(status: 'PENDING');
      await _pumpPortal(tester, api);

      await tester.tap(find.byKey(const Key('provider-pending-preview')));
      await tester.pumpAndSettle();
      expect(find.text('كذا بيشوفك العرسان'), findsOneWidget);
      expect(find.byType(ProviderPreviewCard), findsOneWidget);
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('provider-pending-edit')));
      await tester.pumpAndSettle();
      expect(find.text('تعديل الملف'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('provider-state-account')));
      await tester.pumpAndSettle();
      expect(find.text('حسابي'), findsOneWidget);
    });

    testWidgets('pulls to read the status again', (tester) async {
      final api = _Api(status: 'PENDING');
      await _pumpPortal(tester, api);

      final loads = api.profileLoads;
      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();
      expect(api.profileLoads, greaterThan(loads));
    });
  });

  group('p10 approved', () {
    testWidgets('welcomes once after the review this phone waited for', (
      tester,
    ) async {
      final api = _Api(status: 'PENDING');
      await _pumpPortal(tester, api);
      expect(find.byType(ProviderPendingScreen), findsOneWidget);

      api.status = 'ACTIVE';
      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.byType(ProviderApprovedScreen), findsOneWidget);
      expect(find.text('مبروك، صرت في اعّرست'), findsOneWidget);
      expect(find.text('العرسان في صنعاء يشوفونك من الآن.'), findsOneWidget);
      expect(find.text('حدّث تقويمك'), findsOneWidget);
      expect(find.text('أضف خدماتك وأسعارك'), findsOneWidget);
      expect(find.text('شغّل التنبيهات'), findsOneWidget);
      // No verification request and no visibility promise (F17).
      expect(find.text('وثّق ملفك'), findsNothing);
      expect(find.textContaining('تزيد الطلبات'), findsNothing);
      expect(find.textContaining('ظهورك'), findsNothing);

      await tester.tap(find.byKey(const Key('provider-approved-start')));
      await tester.pumpAndSettle();
      expect(find.byType(ProviderApprovedScreen), findsNothing);
      expect(find.text('الطلبات'), findsWidgets);

      final ledger = ProviderApprovalLedger(
        await SharedPreferences.getInstance(),
      );
      expect(await ledger.welcomeDue('provider-1', 'ACTIVE'), isFalse);
    });

    testWidgets('an approval this phone never waited for opens the portal', (
      tester,
    ) async {
      await _pumpPortal(tester, _Api(status: 'ACTIVE'));
      expect(find.byType(ProviderApprovedScreen), findsNothing);
      expect(find.text('الطلبات'), findsWidgets);
    });

    for (final (step, location) in [
      ('provider-first-step-services', 'خدمة جديدة'),
      ('provider-first-step-notifications', 'التنبيهات'),
    ]) {
      testWidgets('a first step opens its place: $location', (tester) async {
        await _pumpPortal(tester, _Api(status: 'ACTIVE'), seen: 'PENDING');
        expect(find.byType(ProviderApprovedScreen), findsOneWidget);

        await tester.tap(find.byKey(Key(step)));
        await tester.pumpAndSettle();
        expect(find.text(location), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(ProviderApprovedScreen), findsNothing);
      });
    }

    testWidgets('the calendar step lands on the home tab and its days', (
      tester,
    ) async {
      await _pumpPortal(tester, _Api(status: 'ACTIVE'), seen: 'CLAIMED');
      await tester.tap(find.byKey(const Key('provider-first-step-calendar')));
      await tester.pumpAndSettle();
      expect(find.byType(ProviderApprovedScreen), findsNothing);
      expect(find.text('الرئيسية'), findsWidgets);
    });
  });

  group('p12 suspended', () {
    testWidgets('since when, why, and the confirmed weddings ahead', (
      tester,
    ) async {
      final now = DateTime.now();
      final api = _Api(
        status: 'SUSPENDED',
        reviewNote: '3 بلاغات عن تأخير تسليم الصور.',
        reviewedAt: DateTime(now.year, now.month, now.day - 1, 9),
        bookings: [
          _booking('booking-1', 'CONFIRMED', 20),
          _booking('booking-2', 'CONFIRMED', 40),
          _booking('booking-3', 'REQUESTED', 30),
        ],
      );
      await _pumpPortal(tester, api);

      expect(find.byType(ProviderSuspendedScreen), findsOneWidget);
      expect(find.text('حسابك موقوف مؤقتًا'), findsOneWidget);
      expect(
        find.text('من أمس. ما توصلك طلبات جديدة لين ينحل الموضوع.'),
        findsOneWidget,
      );
      expect(find.text('السبب'), findsOneWidget);
      expect(find.text('3 بلاغات عن تأخير تسليم الصور.'), findsOneWidget);
      expect(find.text('حجوزاتك المؤكدة مستمرة'), findsOneWidget);
      expect(
        find.text('عرسين جايين. العرسان معتمدين عليك، كمّلها.'),
        findsOneWidget,
      );
      expect(api.bookingLoads, 1);

      await tester.tap(find.byKey(const Key('provider-suspended-support')));
      await tester.pumpAndSettle();
      expect(find.text('صفحة الدعم'), findsOneWidget);
    });

    testWidgets('no confirmed wedding ahead, no bookings box', (tester) async {
      await _pumpPortal(tester, _Api(status: 'SUSPENDED'));
      expect(
        find.byKey(const Key('provider-suspended-bookings')),
        findsNothing,
      );
      expect(find.byKey(const Key('provider-suspended-reason')), findsNothing);
    });

    testWidgets('an unread bookings list shows no number', (tester) async {
      await _pumpPortal(tester, _Api(status: 'SUSPENDED', failBookings: true));
      expect(find.text('حجوزاتك المؤكدة مستمرة'), findsOneWidget);
      expect(find.text('العرسان معتمدين عليك، كمّلها.'), findsOneWidget);
    });
  });

  group('the welcome record', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('a review this phone waited for is welcomed until seen', () async {
      final ledger = ProviderApprovalLedger(
        await SharedPreferences.getInstance(),
      );
      expect(await ledger.welcomeDue('p', 'PENDING'), isFalse);
      expect(await ledger.welcomeDue('p', 'ACTIVE'), isTrue);
      expect(await ledger.welcomeDue('p', 'ACTIVE'), isTrue);
      await ledger.markWelcomed('p');
      expect(await ledger.welcomeDue('p', 'ACTIVE'), isFalse);
    });

    test(
      'a first look at an active profile or a lifted suspension is not',
      () async {
        final ledger = ProviderApprovalLedger(
          await SharedPreferences.getInstance(),
        );
        expect(await ledger.welcomeDue('a', 'ACTIVE'), isFalse);
        expect(await ledger.welcomeDue('b', 'SUSPENDED'), isFalse);
        expect(await ledger.welcomeDue('b', 'ACTIVE'), isFalse);
        await ledger.markClaimed('c');
        expect(await ledger.welcomeDue('c', 'ACTIVE'), isTrue);
      },
    );

    test('the moment reads as the design writes it', () {
      final now = DateTime(2026, 10, 24, 15);
      expect(
        providerMomentLabel(DateTime(2026, 10, 24, 10), now: now),
        'اليوم 10 الصبح',
      );
      expect(
        providerMomentLabel(DateTime(2026, 10, 23, 16, 30), now: now),
        'أمس 4:30 العصر',
      );
      expect(
        providerMomentLabel(DateTime(2026, 10, 1, 20), now: now),
        '1 أكتوبر 8 المسا',
      );
      expect(providerDayLabel(DateTime(2026, 10, 23), now: now), 'أمس');
    });
  });
}

MarketplaceBooking _booking(String id, String status, int daysAhead) {
  final day = DateTime.now().add(Duration(days: daysAhead));
  return MarketplaceBooking.fromJson({
    'id': id,
    'quoteRequestId': 'quote-$id',
    'providerId': 'provider-1',
    'eventDate': MarketplaceBooking.dayParam(day),
    'status': status,
    'lifecycleStatus': status,
  });
}

Future<void> _pumpPortal(WidgetTester tester, _Api api, {String? seen}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 900);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({
    'aarast_provider_review_status:provider-1': ?seen,
  });
  final storage = AuthStorage(await SharedPreferences.getInstance());
  final chat = _IdleChat(storage);
  addTearDown(chat.dispose);
  final router = GoRouter(
    initialLocation: '/portal',
    routes: [
      GoRoute(path: '/portal', builder: (_, _) => const ProviderPortalScreen()),
      GoRoute(
        path: '/support',
        builder: (_, _) => const Scaffold(body: Text('صفحة الدعم')),
      ),
      GoRoute(
        path: '/more',
        builder: (_, _) =>
            Scaffold(appBar: AppBar(), body: const Text('حسابي')),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) =>
            Scaffold(appBar: AppBar(), body: const Text('التنبيهات')),
      ),
      GoRoute(
        path: '/provider/profile/edit',
        builder: (_, _) =>
            Scaffold(appBar: AppBar(), body: const Text('تعديل الملف')),
      ),
      GoRoute(
        path: '/provider/services/new',
        builder: (_, _) =>
            Scaffold(appBar: AppBar(), body: const Text('خدمة جديدة')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ProviderDashboardProvider>(
          create: (_) => ProviderDashboardProvider(api),
        ),
        ChangeNotifierProvider<ChatProvider>.value(value: chat),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _IdleChat extends ChatProvider {
  _IdleChat(AuthStorage storage)
    : super(
        api: ChatApi(ApiClient(tokenProvider: () async => null)),
        realtime: ChatRealtimeClient(storage),
        authStorage: storage,
      );

  @override
  List<ChatConversation> get conversations => const [];

  @override
  Future<void> initialize() async {}
}

class _Api extends ProviderDashboardApi {
  _Api({
    required this.status,
    this.createdAt,
    this.reviewNote,
    this.reviewedAt,
    this.bookings = const [],
    this.failBookings = false,
  }) : super(ApiClient(tokenProvider: () async => null));

  String status;
  final DateTime? createdAt;
  final String? reviewNote;
  final DateTime? reviewedAt;
  final List<MarketplaceBooking> bookings;
  final bool failBookings;
  int profileLoads = 0;
  int bookingLoads = 0;

  @override
  Future<ProviderDashboardProfile> getProfile() async {
    profileLoads += 1;
    return ProviderDashboardProfile.fromJson({
      'id': 'provider-1',
      'businessName': 'استوديو ضوء صنعاء',
      'status': status,
      'ratingAverage': '0',
      'ratingCount': 0,
      'cityId': 'city-sanaa',
      'city': {'id': 'city-sanaa', 'nameAr': 'صنعاء'},
      'primaryCategoryId': 'cat-photo',
      'primaryCategory': {
        'id': 'cat-photo',
        'nameAr': 'التصوير',
        'showForGroom': true,
        'showForBride': true,
      },
      'reviewNote': reviewNote,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
    });
  }

  @override
  Future<ProviderDashboardSummary> getSummary() async =>
      ProviderDashboardSummary.empty();

  @override
  Future<List<MarketplaceService>> getServices() async => const [];

  @override
  Future<List<ProviderPackage>> getPackages() async => const [];

  @override
  Future<List<QuoteRequest>> getQuoteRequests() async => const [];

  @override
  Future<List<ProviderReview>> getReviews() async => const [];

  @override
  Future<List<MarketplaceBooking>> getBookings() async {
    bookingLoads += 1;
    if (failBookings) throw const ApiException('offline');
    return bookings;
  }

  @override
  Future<List<DateTime>> getBlockedDates() async => const [];
}
