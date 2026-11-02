import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_claim_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A provider the admin listed before its owner had an account, claimed by
// the account signed in with the same phone (V1 checklist 4.18) through the
// review team (B-12, D41).

void main() {
  test('the claimable listing loads, and a failure leaves none', () async {
    final api = _ClaimApiFake();
    final dashboard = ProviderDashboardProvider(api);
    await dashboard.loadClaimableListing();
    expect(dashboard.claimableListing?.businessName, 'الفنان علي');

    api.failLookup = true;
    await dashboard.loadClaimableListing();
    expect(dashboard.claimableListing, isNull);
  });

  test(
    'a claim waits for the review team; the account is no provider yet',
    () async {
      final api = _ClaimApiFake();
      final dashboard = ProviderDashboardProvider(api);
      await dashboard.loadClaimableListing();

      expect(await dashboard.claimListing(), isTrue);
      expect(api.claimed, ['provider-1']);
      expect(dashboard.claim?.isPending, isTrue);
      expect(dashboard.claim?.providerId, 'provider-1');
      expect(dashboard.hasProviderProfile, isFalse);
      expect(dashboard.profile, isNull);
    },
  );

  test(
    'a claim already waiting (sent from another phone) reads as waiting',
    () async {
      final api = _ClaimApiFake()..alreadyPending = true;
      final dashboard = ProviderDashboardProvider(api);
      await dashboard.loadClaimableListing();

      expect(await dashboard.claimListing(), isTrue);
      expect(dashboard.claim?.isPending, isTrue);
      expect(dashboard.errorMessage, isNull);
    },
  );

  // p02 replaced the claim card (D36); the full flow is in
  // provider_join_test.dart.
  testWidgets('p02 names the listing and offers to claim it', (tester) async {
    var claims = 0;
    var support = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ProviderClaimScreen(
          businessName: 'الفنان علي',
          submitting: false,
          onBack: () {},
          onClaim: () => claims += 1,
          onSupport: () => support += 1,
        ),
      ),
    );

    expect(find.text('لقينا ملف بنفس رقمك'), findsOneWidget);
    expect(find.text('الفنان علي'), findsOneWidget);
    expect(find.text('إيه، هذا ملفي'), findsOneWidget);
    expect(find.byKey(const Key('provider-claim-refusal')), findsNothing);
    await tester.tap(find.byKey(const Key('provider-claim-confirm')));
    await tester.tap(find.byKey(const Key('provider-claim-support')));
    expect(claims, 1);
    expect(support, 1);
  });

  testWidgets('after a refused claim p02 says why and offers it again', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ProviderClaimScreen(
          businessName: 'الفنان علي',
          submitting: false,
          refusal: 'اتصلنا بالرقم وما رد.',
          onBack: () {},
          onClaim: () {},
          onSupport: () {},
        ),
      ),
    );
    expect(
      find.text('ما قبلنا الاستلام: اتصلنا بالرقم وما رد.'),
      findsOneWidget,
    );
    expect(find.text('إيه، هذا ملفي'), findsOneWidget);
  });

  testWidgets('p08 for a claim: waiting for the team, no requests meanwhile', (
    tester,
  ) async {
    var backs = 0;
    var support = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ProviderClaimPendingScreen(
          businessName: 'الفنان علي',
          sentAt: DateTime.now(),
          onRefresh: () async {},
          onBack: () => backs += 1,
          onSupport: () => support += 1,
        ),
      ),
    );
    expect(find.text('طلب الاستلام قيد المراجعة'), findsOneWidget);
    expect(find.textContaining('نبلغك هنا.'), findsOneWidget);
    expect(find.text('الملف ما يستقبل طلبات لين نسلّمك إياه'), findsOneWidget);
    await tester.tap(find.byKey(const Key('provider-claim-pending-back')));
    await tester.tap(find.byKey(const Key('provider-claim-pending-support')));
    expect(backs, 1);
    expect(support, 1);
  });
}

class _ClaimApiFake extends ProviderDashboardApi {
  _ClaimApiFake() : super(ApiClient(tokenProvider: () async => null));

  bool failLookup = false;
  bool alreadyPending = false;
  final claimed = <String>[];

  static const _pending = ProviderClaim(
    id: 'claim-1',
    status: 'PENDING',
    providerId: 'provider-1',
    businessName: 'الفنان علي',
  );

  @override
  Future<ProviderClaimableListing?> getClaimableListing() async {
    if (failLookup) throw const ApiException('offline');
    return const ProviderClaimableListing(
      id: 'provider-1',
      businessName: 'الفنان علي',
    );
  }

  @override
  Future<ProviderClaim> claimListing(String providerId) async {
    claimed.add(providerId);
    if (alreadyPending) {
      throw const ApiException(
        'A claim of this listing is already waiting for review',
        statusCode: 409,
        serverCode: 'PROVIDER_CLAIM_PENDING',
      );
    }
    return _pending;
  }

  @override
  Future<ProviderClaim?> getClaim() async => _pending;
}
