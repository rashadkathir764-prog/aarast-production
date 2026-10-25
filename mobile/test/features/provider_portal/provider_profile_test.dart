import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_gallery_screen.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_portal_tabs.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_services_screen.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_settings_screen.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_share_screen.dart';
import 'package:aarast_mobile/features/provider_portal/widgets/provider_profile_parts.dart';
import 'package:aarast_mobile/features/settings/data/settings_api.dart';
import 'package:aarast_mobile/features/settings/models/user_settings.dart';
import 'package:aarast_mobile/features/settings/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_requests_test.dart' show RequestsApi, bookingJson, quoteJson;

// Provider slice 4 (D40): p35 «ملفي», p36 his services, p37 his gallery,
// p40 his settings, p48 the share card and p14 the home before his first
// request. Nothing shows a figure or a promise the server does not keep:
// no teams, no season price, no review tag, no visibility claim, no QR.

final _now = DateTime.now();

const _service = MarketplaceService(
  id: 'service-1',
  providerId: 'provider-1',
  title: 'صور وفيديو',
  isFeatured: false,
  isActive: true,
  basePrice: '550000',
  currency: 'YER',
  description: 'مصوّرين، 300 صورة، فيلم 10 دقايق',
  images: [
    ProviderServiceImage(id: 'image-1', imageUrl: 'https://x.test/1.jpg'),
    ProviderServiceImage(id: 'image-2', imageUrl: 'https://x.test/2.jpg'),
  ],
);

const _package = ProviderPackage(
  id: 'pkg-1',
  providerId: 'provider-1',
  title: 'صور فقط',
  isActive: false,
  price: '350000',
  currency: 'YER',
  description: '300 صورة معدّلة',
);

class ProfileApi extends RequestsApi {
  ProfileApi({
    super.quotes,
    super.bookings,
    this.status = 'ACTIVE',
    this.verifiedAt,
    this.ratingCount = 0,
    this.services = const [_service],
    this.packageList = const [_package],
    this.reviews = const [],
    this.hours,
    this.description = 'تصوير أعراس من 2015',
    this.logoUrl,
    this.views = 14,
    this.featuredStartsAt,
    this.featuredEndsAt,
  });

  final DateTime? featuredStartsAt;
  final DateTime? featuredEndsAt;

  final String status;
  final DateTime? verifiedAt;
  final int ratingCount;
  final List<MarketplaceService> services;
  final List<ProviderPackage> packageList;
  final List<ProviderReview> reviews;
  final int? hours;
  final String? description;
  final String? logoUrl;
  final int views;
  final updated = <String>[];
  final activations = <String>[];
  final deletedImages = <String>[];

  @override
  Future<ProviderDashboardProfile> getProfile() async =>
      ProviderDashboardProfile(
        id: 'provider-1',
        businessName: 'استوديو ضوء صنعاء',
        status: status,
        ratingAverage: 4.7,
        ratingCount: ratingCount,
        city: const MarketplaceCity(id: 'city-1', nameAr: 'صنعاء'),
        primaryCategory: const ProviderCategory(id: 'cat-1', nameAr: 'تصوير'),
        verifiedAt: verifiedAt,
        description: description,
        logoUrl: logoUrl,
        address: 'شارع حدة',
        featuredStartsAt: featuredStartsAt,
        featuredEndsAt: featuredEndsAt,
      );

  @override
  Future<ProviderDashboardSummary> getSummary() async =>
      ProviderDashboardSummary.fromJson({
        'stats': {
          'windowDays': 30,
          'profileViews': views,
          'quoteRequests': 27,
          'offersAccepted': 9,
          'offersDecided': 27,
          'acceptanceRate': 33,
          'upcomingBookings': 5,
          'completedBookings': 2,
        },
      });

  @override
  Future<List<MarketplaceService>> getServices() async => services;

  @override
  Future<List<ProviderPackage>> getPackages() async => packageList;

  @override
  Future<List<ProviderReview>> getReviews() async => reviews;

  @override
  Future<ProviderResponsiveness?> getResponsiveness(String providerId) async =>
      hours == null
      ? null
      : ProviderResponsiveness(
          sampleSize: 6,
          answeredPercent: 90,
          typicalResponseHours: hours,
        );

  @override
  Future<ProviderPackage> updatePackage({
    required String packageId,
    String? title,
    String? serviceId,
    String? description,
    String? price,
    String? currency,
    List<String>? items,
    bool? isActive,
  }) async {
    if (isActive != null) {
      activations.add('$packageId:$isActive');
    } else {
      updated.add('$packageId:$title:$price');
    }
    return ProviderPackage(
      id: packageId,
      providerId: 'provider-1',
      title: title ?? _package.title,
      isActive: isActive ?? _package.isActive,
      price: price ?? _package.price,
      currency: currency ?? 'YER',
      description: description ?? _package.description,
    );
  }

  @override
  Future<void> deleteServiceImage({
    required String serviceId,
    required String imageId,
  }) async {
    deletedImages.add('$serviceId:$imageId');
  }
}

class _SettingsApi extends SettingsApi {
  _SettingsApi() : super(ApiClient(tokenProvider: () async => null));

  bool messages = true;

  UserSettings _settings() => UserSettings.fromJson({
    'id': 'settings-1',
    'userId': 'user-1',
    'providerMessagesEnabled': messages,
    'taskRemindersEnabled': true,
    'paymentRemindersEnabled': true,
  });

  @override
  Future<UserSettings> getSettings() async => _settings();

  @override
  Future<UserSettings> updateSettings(UserSettings settings) async {
    messages = settings.providerMessagesEnabled;
    return _settings();
  }
}

class _AuthController extends AuthController {
  _AuthController(AuthStorage storage)
    : super(
        AuthRepository(ApiClient(tokenProvider: () async => null), storage),
      );

  int logouts = 0;

  @override
  Future<void> logout() async => logouts++;
}

Future<
  ({
    ProviderDashboardProvider dashboard,
    List<String> opened,
    _SettingsApi settings,
    _AuthController auth,
  })
>
_pump(
  WidgetTester tester,
  ProfileApi api,
  Widget Function() home, {
  Size size = const Size(420, 1200),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final storage = AuthStorage(await SharedPreferences.getInstance());
  await storage.saveSession(
    accessToken: 'token',
    user: const SafeUser(
      id: 'user-1',
      name: 'صاحب الاستوديو',
      role: 'USER',
      status: 'ACTIVE',
    ),
  );
  final dashboard = ProviderDashboardProvider(api);
  await dashboard.loadDashboard();
  final settingsApi = _SettingsApi();
  final settings = SettingsProvider(settingsApi);
  final auth = _AuthController(storage);
  final opened = <String>[];
  Widget page(String label) => Builder(
    builder: (context) {
      opened.add(GoRouterState.of(context).uri.toString());
      return Scaffold(body: Text(label));
    },
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: home()),
        ),
      ),
      for (final path in [
        '/provider/services',
        '/provider/services/new',
        '/provider/packages/new',
        '/provider/gallery',
        '/provider/performance',
        '/provider/settings',
        '/provider/share',
        '/provider/profile/edit',
        '/providers/:id',
        '/support',
      ])
        GoRoute(path: path, builder: (_, state) => page(path)),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ProviderDashboardProvider>.value(
          value: dashboard,
        ),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<AuthController>.value(value: auth),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (
    dashboard: dashboard,
    opened: opened,
    settings: settingsApi,
    auth: auth,
  );
}

void main() {
  group('p35 me', () {
    testWidgets('tags only from what the server holds, and a row per piece', (
      tester,
    ) async {
      final pumped = await _pump(
        tester,
        ProfileApi(
          verifiedAt: _now.subtract(const Duration(days: 15)),
          ratingCount: 38,
          hours: 3,
          reviews: const [ProviderReview(id: 'review-1', rating: 5)],
        ),
        () => ProviderProfileTab(now: _now),
      );

      expect(find.text('استوديو ضوء صنعاء'), findsOneWidget);
      expect(find.text('تصوير · صنعاء'), findsOneWidget);
      expect(find.byKey(const Key('provider-me-verified')), findsOneWidget);
      expect(find.text('★ 4.7 · 38 تقييم'), findsOneWidget);
      expect(find.text('يرد عادة خلال 3 ساعات'), findsOneWidget);
      expect(find.text('كيف يشوفك العرسان'), findsOneWidget);
      expect(find.text('خدماتك وباقاتك'), findsOneWidget);
      expect(find.text('خدمة · باقة · من 550,000'), findsOneWidget);
      expect(find.text('صورتين'), findsOneWidget);
      expect(find.text('التغطية'), findsOneWidget);
      expect(find.text('موثّق من أسبوعين'), findsOneWidget);
      expect(find.text('آخر 30 يوم'), findsOneWidget);
      expect(find.textContaining('تيك توك'), findsNothing);
      expect(find.textContaining('فرق'), findsNothing);
      expect(find.textContaining('ما رديت عليه'), findsNothing);

      for (final (key, path) in [
        ('provider-profile-services', '/provider/services'),
        ('provider-me-gallery', '/provider/gallery'),
        ('provider-me-performance', '/provider/performance'),
        ('provider-me-share', '/provider/share'),
        ('provider-me-settings', '/provider/settings'),
        ('provider-me-preview', '/providers/provider-1'),
      ]) {
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expect(pumped.opened.last, path);
        GoRouter.of(tester.element(find.byType(Scaffold).last)).pop();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('without verification, ratings or a reply speed, nothing '
        'stands in for them', (tester) async {
      await _pump(tester, ProfileApi(), () => ProviderProfileTab(now: _now));
      expect(find.byKey(const Key('provider-me-verified')), findsNothing);
      expect(find.byKey(const Key('provider-me-verification')), findsNothing);
      expect(find.byKey(const Key('provider-me-responds')), findsNothing);
      expect(find.textContaining('★'), findsNothing);
      expect(find.text('ما فيه تقييم لسا'), findsOneWidget);
    });

    testWidgets('a rejected profile keeps only what still applies', (
      tester,
    ) async {
      await _pump(
        tester,
        ProfileApi(status: 'REJECTED'),
        () => ProviderProfileTab(now: _now),
      );
      expect(find.byKey(const Key('provider-me-preview')), findsNothing);
      expect(find.byKey(const Key('provider-profile-services')), findsNothing);
      expect(find.byKey(const Key('provider-me-edit')), findsNothing);
      expect(find.byKey(const Key('provider-me-featured')), findsNothing);
      expect(find.byKey(const Key('provider-me-settings')), findsOneWidget);
    });

    // B-43: the placement the team records after he pays them outside the
    // app; asking for it or renewing it goes to the team.
    testWidgets('his featured placement and until when, or how to ask for '
        'it', (tester) async {
      final pumped = await _pump(
        tester,
        ProfileApi(
          // Through 31 December in Sana'a: the next day starts at 21:00 UTC.
          featuredStartsAt: DateTime.utc(2026, 9, 30, 21),
          featuredEndsAt: DateTime.utc(2026, 12, 31, 21),
        ),
        () => ProviderProfileTab(now: DateTime.utc(2026, 10, 25, 9)),
      );
      expect(find.text('الظهور المميز'), findsOneWidget);
      expect(find.text('مميز لين 31 ديسمبر'), findsOneWidget);
      await tester.tap(find.byKey(const Key('provider-me-featured')));
      await tester.pumpAndSettle();
      expect(pumped.opened.last, '/support');
    });

    test('the featured line reads the days in Sana\'a', () {
      final now = DateTime.utc(2026, 10, 25, 9);
      expect(
        providerFeaturedLine(now: now),
        'ظهور عادي · تبي تطلع أول؟ كلّم فريق اعّرست',
      );
      expect(
        providerFeaturedLine(
          startsAt: DateTime.utc(2026, 12, 31, 21),
          endsAt: DateTime.utc(2027, 3, 31, 21),
          now: now,
        ),
        'يبدأ 1 يناير · لين 31 مارس',
      );
      expect(
        providerFeaturedLine(
          startsAt: DateTime.utc(2026, 10, 20, 9),
          endsAt: DateTime.utc(2026, 10, 31, 21),
          now: now,
        ),
        'مميز لين 31 أكتوبر',
      );
    });
  });

  group('p27 review card', () {
    testWidgets('the name, the stars, when it was written and the words; '
        'no tags, reply or report', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ProviderReviewCard(
              now: _now,
              review: ProviderReview(
                id: 'review-1',
                rating: 4,
                userName: 'محمد',
                comment: 'الصور رهيبة، بس الفيلم تأخر أسبوعين عن الموعد.',
                createdAt: _now.subtract(const Duration(days: 15)),
              ),
            ),
          ),
        ),
      );

      expect(find.text('محمد'), findsOneWidget);
      expect(find.bySemanticsLabel('4 من 5'), findsOneWidget);
      final stars = tester
          .widgetList<Icon>(find.byIcon(LucideIcons.star))
          .map((icon) => icon.color)
          .toList();
      expect(stars, [
        for (var i = 0; i < 4; i++) AarastV3Color.saffron,
        AarastV3Color.line,
      ]);
      expect(find.text('قبل أسبوعين'), findsOneWidget);
      expect(
        find.text('«الصور رهيبة، بس الفيلم تأخر أسبوعين عن الموعد.»'),
        findsOneWidget,
      );
      // No occasion, tags, reply or report on the server (B-09, B-28).
      expect(find.text('انشر الرد'), findsNothing);
      expect(find.textContaining('بلّغ'), findsNothing);
    });

    testWidgets('a review without a name or words keeps the stars only', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: ProviderReviewCard(
              review: ProviderReview(id: 'review-2', rating: 5),
            ),
          ),
        ),
      );
      expect(find.text('عريس من اعّرست'), findsOneWidget);
      expect(find.bySemanticsLabel('5 من 5'), findsOneWidget);
      expect(find.textContaining('«'), findsNothing);
    });
  });

  group('p36 services', () {
    testWidgets('each service and package with its price and what it '
        'includes; no season price and no teams', (tester) async {
      await _pump(
        tester,
        ProfileApi(),
        () => ProviderServicesScreen(now: _now),
      );

      expect(find.text('خدماتك'), findsOneWidget);
      expect(find.text('تصوير · خدمة · باقة'), findsOneWidget);
      expect(find.text('صور وفيديو'), findsOneWidget);
      expect(find.text('550,000'), findsOneWidget);
      expect(find.text('يشمل: مصوّرين، 300 صورة، فيلم 10 دقايق'), findsOne);
      expect(find.text('صور فقط'), findsOneWidget);
      expect(find.text('موقوفة، ما يشوفها العرسان'), findsOneWidget);
      expect(find.byKey(const Key('provider-services-footer')), findsOneWidget);
      expect(find.text('الأسعار بريال يمني'), findsOneWidget);
      expect(find.textContaining('الموسم'), findsNothing);
      expect(find.text('الفرق'), findsNothing);
    });

    testWidgets('a package opens its edit; showing it applies at once and '
        'the rest is saved', (tester) async {
      final api = ProfileApi();
      await _pump(tester, api, () => ProviderServicesScreen(now: _now));

      await tester.tap(find.byKey(const Key('provider-package-pkg-1')));
      await tester.pumpAndSettle();
      expect(find.text('عدّل الباقة'), findsOneWidget);

      await tester.tap(find.byKey(const Key('provider-listing-active')));
      await tester.pumpAndSettle();
      expect(api.activations, ['pkg-1:true']);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('provider-listing-price')),
          matching: find.byType(TextField),
        ),
        '12,5x',
      );
      await tester.tap(find.byKey(const Key('provider-listing-save')));
      await tester.pumpAndSettle();
      expect(find.text('اكتب المبلغ أرقام بس.'), findsOneWidget);
      expect(api.updated, isEmpty);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('provider-listing-price')),
          matching: find.byType(TextField),
        ),
        '400,000',
      );
      await tester.tap(find.byKey(const Key('provider-listing-save')));
      await tester.pumpAndSettle();
      expect(api.updated, ['pkg-1:صور فقط:400000']);
      expect(find.text('عدّل الباقة'), findsNothing);
    });
  });

  group('p37 gallery', () {
    testWidgets('one album per service, live photos, and where he works', (
      tester,
    ) async {
      final api = ProfileApi();
      await _pump(tester, api, ProviderGalleryScreen.new);

      expect(find.text('معرض الشغل'), findsOneWidget);
      expect(find.text('صورتين'), findsOneWidget);
      expect(
        find.byKey(const Key('provider-gallery-album-service-1')),
        findsOne,
      );
      expect(find.byKey(const Key('provider-gallery-photo-image-1')), findsOne);
      expect(find.textContaining('نراجع'), findsNothing);
      expect(
        find.text('الصور اللي تضيفها تظهر في ملفك للعرسان على طول.'),
        findsOneWidget,
      );
      expect(find.text('المدينة'), findsOneWidget);
      expect(find.text('صنعاء'), findsOneWidget);
      expect(find.text('شارع حدة'), findsOneWidget);
      expect(find.textContaining('يسافر'), findsNothing);

      await tester.tap(find.byKey(const Key('provider-gallery-photo-image-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('provider-gallery-photo-delete')));
      await tester.pumpAndSettle();
      expect(api.deletedImages, ['service-1:image-1']);
    });

    testWidgets('with no service, photos wait for one', (tester) async {
      await _pump(
        tester,
        ProfileApi(services: const []),
        ProviderGalleryScreen.new,
      );
      expect(find.byKey(const Key('provider-gallery-empty')), findsOneWidget);
    });
  });

  group('p40 settings', () {
    testWidgets('one switch for requests and messages, the account, and the '
        'bookings ahead before deleting', (tester) async {
      final pumped = await _pump(
        tester,
        ProfileApi(
          bookings: [
            bookingJson(status: 'CONFIRMED', day: '2027-01-21'),
            bookingJson(
              id: 'booking-2',
              quoteId: 'quote-2',
              status: 'CONFIRMED',
              day: '2027-02-04',
            ),
          ],
        ),
        () => const ProviderSettingsScreen(devicePushAvailableOverride: true),
      );

      expect(find.text('الإعدادات'), findsOneWidget);
      expect(find.text('تنبيه لكل طلب ورسالة'), findsOneWidget);
      expect(
        find.text('تنبيهات الجوال تشتغل من إذن التنبيهات في جوالك.'),
        findsOneWidget,
      );
      expect(find.text('افتح خطة عرسي'), findsOneWidget);
      expect(find.text('عندك حجزين جاية، الغها قبل ما تحذف'), findsOneWidget);
      for (final dropped in [
        'رقمك يظهر للعرسان',
        'ملخص يومي',
        'مين يدير الحساب',
      ]) {
        expect(find.text(dropped), findsNothing);
      }
      expect(find.textContaining('تعهّد'), findsNothing);

      await tester.tap(find.byKey(const Key('provider-settings-messages')));
      await tester.pumpAndSettle();
      expect(pumped.settings.messages, isFalse);

      await tester.tap(find.byKey(const Key('provider-logout-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('provider-logout-confirm')));
      await tester.pumpAndSettle();
      expect(pumped.auth.logouts, 1);
    });

    testWidgets('with no booking ahead, deleting says what it removes', (
      tester,
    ) async {
      await _pump(
        tester,
        ProfileApi(),
        () => const ProviderSettingsScreen(devicePushAvailableOverride: false),
      );
      expect(find.text('يحذف حسابك وملفك نهائيًا'), findsOneWidget);
      expect(
        find.text('هذي النسخة ما توصلها تنبيهات الجوال، تلقاها داخل التطبيق.'),
        findsOneWidget,
      );
    });
  });

  group('p48 share card', () {
    testWidgets('name, kind, rating and «موثّق» only when held; no QR, link '
        'or free nights; WhatsApp gets the words', (tester) async {
      final sent = <String>[];
      await _pump(
        tester,
        ProfileApi(verifiedAt: _now, ratingCount: 38),
        () => ProviderShareScreen(
          share: (text) async {
            sent.add(text);
            return true;
          },
        ),
      );

      expect(find.byKey(const Key('provider-share-card')), findsOneWidget);
      expect(find.text('تصوير · صنعاء'), findsOneWidget);
      expect(find.text('★ 4.7 · 38 تقييم'), findsOneWidget);
      expect(find.byKey(const Key('provider-share-verified')), findsOneWidget);
      expect(find.textContaining('ليالي'), findsNothing);
      expect(find.text('تيك توك'), findsNothing);

      await tester.tap(find.byKey(const Key('provider-share-whatsapp')));
      await tester.pumpAndSettle();
      expect(sent.single, contains('استوديو ضوء صنعاء · تصوير · صنعاء'));
      expect(sent.single, contains('موثّق في اعّرست'));
      expect(sent.single, contains('ابحث باسم «استوديو ضوء صنعاء»'));
    });

    testWidgets('without ratings or verification the card claims neither', (
      tester,
    ) async {
      await _pump(tester, ProfileApi(), () => const ProviderShareScreen());
      expect(find.textContaining('★'), findsNothing);
      expect(find.byKey(const Key('provider-share-verified')), findsNothing);
    });
  });

  group('p14 first home', () {
    testWidgets('before his first request: what completes his profile and '
        'his page\'s views, with no visibility promise', (tester) async {
      final opened = <int>[];
      await _pump(
        tester,
        ProfileApi(description: null, services: const []),
        () => ProviderHomeTab(onOpenTab: opened.add),
      );

      expect(find.text('ما وصلك طلب لسا'), findsOneWidget);
      expect(find.text('هذا اللي يكمّل ملفك قدام العرسان:'), findsOneWidget);
      expect(find.text('أضف خدمة بسعرها'), findsOneWidget);
      expect(find.text('أضف شعارك'), findsOneWidget);
      expect(find.text('اكتب نبذة عن شغلك'), findsOneWidget);
      expect(find.text('انفتح ملفك 14 مرة في آخر 30 يوم'), findsOneWidget);
      expect(find.textContaining('وثّق'), findsNothing);
      expect(find.textContaining('شارك'), findsNothing);
      expect(find.textContaining('تجيها طلبات'), findsNothing);
      expect(find.textContaining('تنشاف'), findsNothing);

      await tester.tap(find.byKey(const Key('provider-first-logo')));
      expect(opened, [4]);
    });

    testWidgets('the first request turns it back into p13', (tester) async {
      await _pump(
        tester,
        ProfileApi(quotes: [quoteJson()]),
        () => ProviderHomeTab(onOpenTab: (_) {}),
      );
      expect(find.byKey(const Key('provider-home-first')), findsNothing);
      expect(find.text('ينتظرونك'), findsOneWidget);
    });
  });
}
