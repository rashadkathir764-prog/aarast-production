import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_performance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// The provider's own reach over the last 30 days (V1 checklist 4.19).

const _statsJson = {
  'windowDays': 30,
  'profileViews': 42,
  'quoteRequests': 6,
  'offersAccepted': 2,
  'offersDecided': 4,
  'acceptanceRate': 50,
  'upcomingBookings': 1,
  'completedBookings': 3,
};

void main() {
  test('the summary carries the stats, and an older server sends none', () {
    final summary = ProviderDashboardSummary.fromJson({
      'servicesCount': 1,
      'stats': _statsJson,
    });
    final stats = summary.stats!;
    expect(stats.profileViews, 42);
    expect(stats.quoteRequests, 6);
    expect(stats.acceptanceRate, 50);
    expect(stats.completedBookings, 3);

    expect(ProviderDashboardSummary.fromJson({'servicesCount': 1}).stats, isNull);
    expect(
      ProviderStats.fromJson({..._statsJson, 'acceptanceRate': null})
          .acceptanceRate,
      isNull,
    );
  });

  // p39 replaced the stats panel and its hint (D40).
  testWidgets('p39 shows views, requests, acceptance, reply time and '
      'bookings', (tester) async {
    final dashboard = ProviderDashboardProvider(_StatsApiFake());
    await dashboard.loadDashboard();

    await tester.pumpWidget(
      ChangeNotifierProvider<ProviderDashboardProvider>.value(
        value: dashboard,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: ProviderPerformanceScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('آخر 30 يوم'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('مشاهدة لملفك'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('قبلوا عرضك'), findsOneWidget);
    expect(find.text('50% من اللي قرروا'), findsOneWidget);
    expect(find.text('3 ساعات'), findsOneWidget);
    expect(find.text('عادة ترد خلالها'), findsOneWidget);
    expect(find.text('عندك حجز مؤكد جاي.'), findsOneWidget);
    expect(find.textContaining('%+'), findsNothing);
    expect(find.text('ليش ما اختاروك'), findsNothing);
  });
}

class _StatsApiFake extends ProviderDashboardApi {
  _StatsApiFake() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<ProviderDashboardProfile> getProfile() async =>
      const ProviderDashboardProfile(
        id: 'provider-1',
        businessName: 'الفنان علي',
        status: 'ACTIVE',
        ratingAverage: 0,
        ratingCount: 0,
      );

  @override
  Future<ProviderDashboardSummary> getSummary() async =>
      ProviderDashboardSummary.fromJson({
        'servicesCount': 1,
        'activeServicesCount': 1,
        'stats': _statsJson,
      });

  @override
  Future<List<MarketplaceService>> getServices() async => const [];

  @override
  Future<List<ProviderPackage>> getPackages() async => const [];

  @override
  Future<List<QuoteRequest>> getQuoteRequests() async => const [];

  @override
  Future<List<ProviderReview>> getReviews() async => const [];

  @override
  Future<List<MarketplaceBooking>> getBookings() async => const [];

  @override
  Future<List<DateTime>> getBlockedDates() async => const [];

  @override
  Future<ProviderResponsiveness?> getResponsiveness(String providerId) async =>
      const ProviderResponsiveness(
        sampleSize: 5,
        answeredPercent: 80,
        typicalResponseHours: 3,
      );
}
