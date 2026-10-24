import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/provider_portal/data/provider_approval_ledger.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_apply_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account_contexts/account_context_test_data.dart';

// The joining after the account: p02 claims a listing under this phone;
// otherwise p03 «نشاطك», p04 «وين تشتغل؟» and p07 «كذا بيشوفك العرسان» are
// kept on the phone and sent together (apply creates PENDING at once, F1).

const _sanaa = MarketplaceCity(id: 'city-sanaa', nameAr: 'صنعاء');
const _photo = ProviderCategory(id: 'cat-photo', nameAr: 'التصوير');

void main() {
  testWidgets('p03 asks the name and the category, nothing the server lacks', (
    tester,
  ) async {
    final harness = await _Harness.pump(tester);

    expect(find.text('طلب الانضمام'), findsOneWidget);
    expect(find.text('نشاطك'), findsNWidgets(2)); // the step and the title
    expect(find.text('اسم النشاط كما يعرفه الناس'), findsOneWidget);
    expect(find.text('القسم'), findsOneWidget);
    // Dropped until the server has them (B-10, B-14).
    expect(find.text('يخدم مين؟'), findsNothing);
    expect(find.text('شغلك'), findsNothing);
    expect(find.text('طريقتك'), findsNothing);
    expect(find.text('خدماتك'), findsNothing);
    expect(harness.api.applications, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('p03 holds the next step until both are given', (tester) async {
    await _Harness.pump(tester);

    await tester.tap(find.byKey(const ValueKey('provider-apply-next')));
    await tester.pumpAndSettle();
    expect(find.text('اكتب اسم نشاطك'), findsOneWidget);
    expect(find.text('اختر قسمك'), findsOneWidget);
    expect(find.text('وين تشتغل؟'), findsNothing);
  });

  testWidgets('the steps are sent together from p07 as one application', (
    tester,
  ) async {
    final harness = await _Harness.pump(tester);

    await _business(tester);
    expect(find.text('وين تشتغل؟'), findsOneWidget);
    // p04 keeps the city and the shop; districts and travel are dropped.
    expect(find.text('المناطق اللي تغطيها'), findsNothing);
    expect(find.text('تسافر لمحافظة ثانية؟'), findsNothing);
    await _where(tester, address: 'شارع الزبيري، جنب جولة كنتاكي');

    expect(find.text('كذا بيشوفك العرسان'), findsOneWidget);
    expect(find.text('استوديو ضوء صنعاء'), findsOneWidget);
    expect(find.text('التصوير · صنعاء'), findsOneWidget);
    expect(find.text('نشاطك ومدينتك'), findsOneWidget);
    expect(find.text('مكان المحل'), findsOneWidget);
    expect(
      find.text('الصور والخدمات والأسعار تضيفها بعد الموافقة'),
      findsOneWidget,
    );
    expect(find.text('نراجع طلبك ونبلغك هنا.'), findsOneWidget);
    // No promise or figure the server does not keep.
    expect(find.textContaining('يومين'), findsNothing);
    expect(find.textContaining('6 صور'), findsNothing);
    expect(find.textContaining('فرق'), findsNothing);
    expect(find.textContaining('ر.ي'), findsNothing);
    expect(find.textContaining('يرفع ظهورك'), findsNothing);
    expect(harness.api.applications, isEmpty);

    await tester.tap(find.byKey(const ValueKey('provider-apply-send')));
    await tester.pumpAndSettle();

    expect(harness.api.applications, [
      ('استوديو ضوء صنعاء', '+967773210455', 'city-sanaa', 'cat-photo'),
    ]);
    expect(harness.api.addresses, ['شارع الزبيري، جنب جولة كنتاكي']);
    expect(harness.auth.refreshes, 1);
    expect(harness.contexts.selectedContext?.isProvider, isTrue);
    expect(find.text('بوابة المزود'), findsOneWidget);
  });

  testWidgets('without a shop place only the application is sent', (
    tester,
  ) async {
    final harness = await _Harness.pump(tester);

    await _business(tester);
    await _where(tester);
    expect(find.text('مكان المحل'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('provider-apply-send')));
    await tester.pumpAndSettle();

    expect(harness.api.applications, hasLength(1));
    expect(harness.api.addresses, isEmpty);
  });

  testWidgets('a refused application stays on p07 and says why', (
    tester,
  ) async {
    final harness = await _Harness.pump(tester, failApply: true);

    await _business(tester);
    await _where(tester);
    await tester.tap(find.byKey(const ValueKey('provider-apply-send')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('provider-apply-error')), findsOneWidget);
    expect(find.text('كذا بيشوفك العرسان'), findsOneWidget);
    expect(harness.contexts.selectedContext, isNull);
  });

  testWidgets('back goes one step at a time and keeps what was typed', (
    tester,
  ) async {
    await _Harness.pump(tester);

    await _business(tester);
    await tester.tap(find.byTooltip('رجوع'));
    await tester.pumpAndSettle();
    expect(find.text('اسم النشاط كما يعرفه الناس'), findsOneWidget);
    expect(find.text('استوديو ضوء صنعاء'), findsOneWidget);
    expect(find.text('التصوير'), findsOneWidget);
  });

  testWidgets('the cities that did not load can be asked again', (
    tester,
  ) async {
    final harness = await _Harness.pump(tester, referenceFails: true);

    expect(
      find.text('ما قدرنا نجيب المدن والأقسام. تأكد من النت.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('provider-apply-retry')));
    await tester.pumpAndSettle();
    expect(harness.market.loads, 2);
    expect(
      find.text('ما قدرنا نجيب المدن والأقسام. تأكد من النت.'),
      findsNothing,
    );
  });

  testWidgets('p02 opens when a listing waits under this phone', (
    tester,
  ) async {
    final harness = await _Harness.pump(tester, claimable: true);

    expect(find.text('لقينا ملف بنفس رقمك'), findsOneWidget);
    expect(
      find.text('فريق اعّرست أضافه من الدليل. استلمه وكمّله.'),
      findsOneWidget,
    );
    expect(find.text('الفنان علي'), findsOneWidget);
    expect(find.text('بعد ما تستلمه تعدّل كل شيء فيه'), findsOneWidget);
    // The lookup gives the name only: no requests, views or new profile.
    expect(find.textContaining('طلبين'), findsNothing);
    expect(find.textContaining('شافوا ملفك'), findsNothing);
    expect(find.text('مو أنا، أشتي ملف جديد'), findsNothing);

    await tester.tap(find.byKey(const Key('provider-claim-support')));
    await tester.pumpAndSettle();
    expect(find.text('صفحة الدعم'), findsOneWidget);
    expect(harness.api.claims, isEmpty);
  });

  testWidgets('claiming opens the portal and welcomes the listing once', (
    tester,
  ) async {
    final harness = await _Harness.pump(tester, claimable: true);

    await tester.tap(find.byKey(const Key('provider-claim-confirm')));
    await tester.pumpAndSettle();

    expect(harness.api.claims, ['listing-1']);
    expect(harness.contexts.selectedContext?.isProvider, isTrue);
    expect(find.text('بوابة المزود'), findsOneWidget);
    final ledger = ProviderApprovalLedger(
      await SharedPreferences.getInstance(),
    );
    expect(await ledger.welcomeDue('listing-1', 'ACTIVE'), isTrue);
  });

  testWidgets('a failed claim stays on p02 and says why', (tester) async {
    final harness = await _Harness.pump(
      tester,
      claimable: true,
      failClaim: true,
    );

    await tester.tap(find.byKey(const Key('provider-claim-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('provider-claim-error')), findsOneWidget);
    expect(harness.contexts.selectedContext, isNull);
  });

  testWidgets('a phone whose listing appears while applying is sent to p02', (
    tester,
  ) async {
    final harness = await _Harness.pump(tester, listingOnApply: true);

    await _business(tester);
    await _where(tester);
    await tester.tap(find.byKey(const ValueKey('provider-apply-send')));
    await tester.pumpAndSettle();

    expect(harness.api.applications, isEmpty);
    expect(find.text('لقينا ملف بنفس رقمك'), findsOneWidget);
  });

  testWidgets('an account that already applied is sent to its portal', (
    tester,
  ) async {
    await _Harness.pump(tester, existingStatus: 'PENDING');
    expect(find.text('بوابة المزود'), findsOneWidget);
  });

  testWidgets('the joining fits 320 points with the largest text', (
    tester,
  ) async {
    await _Harness.pump(tester, width: 320, textScale: 1.3);
    await _business(tester);
    await _where(tester, address: 'شارع الزبيري');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _business(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('provider-apply-name')).first,
    'استوديو ضوء صنعاء',
  );
  await tester.tap(find.byKey(const Key('provider-apply-category')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('provider-apply-option-cat-photo')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('provider-apply-next')));
  await tester.pumpAndSettle();
}

Future<void> _where(WidgetTester tester, {String? address}) async {
  await tester.tap(find.byKey(const Key('provider-apply-city')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('provider-apply-option-city-sanaa')),
  );
  await tester.pumpAndSettle();
  if (address != null) {
    await tester.enterText(
      find.byKey(const Key('provider-apply-address')).first,
      address,
    );
  }
  await tester.tap(find.byKey(const ValueKey('provider-apply-next')));
  await tester.pumpAndSettle();
}

class _Harness {
  _Harness(this.api, this.auth, this.contexts, this.market);

  final _JoinApi api;
  final _SignedIn auth;
  final AccountContextController contexts;
  final _Market market;

  static Future<_Harness> pump(
    WidgetTester tester, {
    bool claimable = false,
    bool failApply = false,
    bool failClaim = false,
    bool listingOnApply = false,
    bool referenceFails = false,
    String? existingStatus,
    double width = 390,
    double textScale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final storage = AuthStorage(await SharedPreferences.getInstance());
    await storage.saveSession(accessToken: 'token', user: _user);
    final api = _JoinApi(
      claimable: claimable,
      failApply: failApply,
      failClaim: failClaim,
      listingOnApply: listingOnApply,
      existingStatus: existingStatus,
    );
    final repository = AuthRepository(
      ApiClient(tokenProvider: storage.readAccessToken),
      storage,
    );
    final auth = _SignedIn(repository);
    final gateway = _Contexts(api);
    final contexts = AccountContextController(
      contextsApi: gateway,
      authStorage: storage,
      setActiveWeddingPlan: (_) async {},
    );
    final market = _Market(fails: referenceFails);
    final dashboard = ProviderDashboardProvider(api);
    final router = GoRouter(
      initialLocation: '/provider/apply',
      routes: [
        GoRoute(
          path: '/provider/apply',
          builder: (_, _) => const ProviderApplyScreen(),
        ),
        GoRoute(
          path: '/provider/dashboard',
          builder: (_, _) => const Scaffold(body: Text('بوابة المزود')),
        ),
        GoRoute(
          path: '/support',
          builder: (_, _) => const Scaffold(body: Text('صفحة الدعم')),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('الرئيسية')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>.value(value: storage),
          ChangeNotifierProvider<AuthController>.value(value: auth),
          ChangeNotifierProvider<AccountContextController>.value(
            value: contexts,
          ),
          ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
            value: market,
          ),
          ChangeNotifierProvider<ProviderDashboardProvider>.value(
            value: dashboard,
          ),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return _Harness(api, auth, contexts, market);
  }
}

const _user = SafeUser(
  id: 'user-1',
  name: 'علي الشامي',
  role: 'USER',
  status: 'ACTIVE',
  phone: '+967773210455',
);

class _SignedIn extends AuthController {
  _SignedIn(super.authRepository);

  int refreshes = 0;

  @override
  AuthStatus get status => AuthStatus.authenticated;

  @override
  SafeUser? get user => _user;

  @override
  Future<void> refreshCurrentUser() async => refreshes += 1;
}

class _Contexts implements AccountContextsGateway {
  _Contexts(this.api);

  final _JoinApi api;

  AccountContext get _provider => accountContext(
    role: AccountContextRole.provider,
    providerId: api.providerId,
    lifecycle: api.status,
    accessMode: api.status == 'ACTIVE'
        ? AccountContextAccessMode.full
        : AccountContextAccessMode.limited,
  );

  @override
  Future<List<AccountContext>> listContexts() async =>
      api.status == null ? const [] : [_provider];

  @override
  Future<AccountContext> validateContext(String contextKey) async => _provider;
}

class _Market extends ProviderMarketplaceProvider {
  _Market({required this.fails})
    : super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  bool fails;
  int loads = 0;

  @override
  List<MarketplaceCity> get cities => fails ? const [] : const [_sanaa];

  @override
  List<ProviderCategory> get categories => fails ? const [] : const [_photo];

  @override
  bool get isReferenceDataLoading => false;

  @override
  String? get referenceDataErrorMessage =>
      fails ? providerReferenceDataErrorMessage : null;

  @override
  Future<void> loadReferenceData() async {
    loads += 1;
    if (loads > 1) fails = false;
    notifyListeners();
  }
}

class _JoinApi extends ProviderDashboardApi {
  _JoinApi({
    required this.claimable,
    required this.failApply,
    required this.failClaim,
    required this.listingOnApply,
    this.existingStatus,
  }) : status = existingStatus,
       super(ApiClient(tokenProvider: () async => null));

  bool claimable;
  final bool failApply;
  final bool failClaim;
  final bool listingOnApply;
  final String? existingStatus;
  String? status;
  String providerId = 'provider-1';
  final applications = <(String, String, String, String)>[];
  final addresses = <String>[];
  final claims = <String>[];

  ProviderDashboardProfile _profile() => ProviderDashboardProfile(
    id: providerId,
    businessName: 'استوديو ضوء صنعاء',
    status: status ?? 'PENDING',
    ratingAverage: 0,
    ratingCount: 0,
  );

  @override
  Future<ProviderDashboardProfile> getProfile() async {
    if (status == null) {
      throw const ApiException('Provider profile not found', statusCode: 404);
    }
    return _profile();
  }

  @override
  Future<ProviderClaimableListing?> getClaimableListing() async => claimable
      ? const ProviderClaimableListing(
          id: 'listing-1',
          businessName: 'الفنان علي',
        )
      : null;

  @override
  Future<ProviderDashboardProfile> claimListing(String providerId) async {
    if (failClaim) throw const ApiException('ما قدرنا نستلم الملف.');
    claims.add(providerId);
    this.providerId = providerId;
    claimable = false;
    status = 'ACTIVE';
    return _profile();
  }

  @override
  Future<ProviderDashboardProfile> applyProvider({
    required String businessName,
    required String phone,
    required String cityId,
    List<String> categoryIds = const [],
    String? description,
  }) async {
    if (listingOnApply) {
      claimable = true;
      throw const ApiException(
        'A provider listing already exists for this phone; claim it',
        statusCode: 409,
        serverCode: 'PROVIDER_LISTING_CLAIMABLE',
      );
    }
    if (failApply) throw const ApiException('المدينة غير متاحة الآن.');
    applications.add((businessName, phone, cityId, categoryIds.join(',')));
    status = 'PENDING';
    return _profile();
  }

  @override
  Future<ProviderDashboardProfile> updateProfileAddress(String address) async {
    addresses.add(address);
    return _profile();
  }
}
