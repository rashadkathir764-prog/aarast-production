import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/widgets/provider_claim_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A provider the admin listed before its owner had an account, claimed by
// the account signed in with the same phone (V1 checklist 4.18).

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

  test('claiming makes the account the provider', () async {
    final api = _ClaimApiFake();
    final dashboard = ProviderDashboardProvider(api);
    await dashboard.loadClaimableListing();

    expect(await dashboard.claimListing(), isTrue);
    expect(api.claimed, ['provider-1']);
    expect(dashboard.hasProviderProfile, isTrue);
    expect(dashboard.profile?.status, 'ACTIVE');
    expect(dashboard.claimableListing, isNull);
  });

  testWidgets('the card names the listing and offers to claim it', (
    tester,
  ) async {
    final dashboard = ProviderDashboardProvider(_ClaimApiFake());
    await dashboard.loadClaimableListing();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ProviderClaimCard(dashboard: dashboard)),
      ),
    );

    expect(find.text('ملفك موجود في اعّرست'), findsOneWidget);
    expect(find.textContaining('«الفنان علي»'), findsOneWidget);
    expect(find.text('استلم ملفي'), findsOneWidget);
  });
}

class _ClaimApiFake extends ProviderDashboardApi {
  _ClaimApiFake() : super(ApiClient(tokenProvider: () async => null));

  bool failLookup = false;
  final claimed = <String>[];

  @override
  Future<ProviderClaimableListing?> getClaimableListing() async {
    if (failLookup) throw const ApiException('offline');
    return const ProviderClaimableListing(
      id: 'provider-1',
      businessName: 'الفنان علي',
    );
  }

  @override
  Future<ProviderDashboardProfile> claimListing(String providerId) async {
    claimed.add(providerId);
    return const ProviderDashboardProfile(
      id: 'provider-1',
      businessName: 'الفنان علي',
      status: 'ACTIVE',
      ratingAverage: 0,
      ratingCount: 0,
    );
  }
}
