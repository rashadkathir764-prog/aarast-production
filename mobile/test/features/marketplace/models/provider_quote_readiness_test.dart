import 'package:aarast_mobile/core/config/app_feature_flags.dart';
import 'package:aarast_mobile/core/offline/sync_status.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_quote_readiness.dart';
import 'package:aarast_mobile/features/wedding_plans/models/plan_summary_readiness.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProviderQuoteReadiness', () {
    test('defaults to feature disabled without exposing source counts', () {
      const readiness = ProviderQuoteReadiness.empty();

      expect(readiness.state, ProviderQuoteReadinessState.featureDisabled);
      expect(readiness.providerCount, isNull);
      expect(readiness.quoteRequestCount, isNull);
      expect(readiness.newQuoteRequestCount, isNull);
    });

    test(
      'hides provider and quote counts while provider quotes flag is disabled',
      () {
        final readiness = ProviderQuoteReadiness.fromSources(
          featureFlags: AppFeatureFlags.defaults,
          providers: [_provider()],
          quoteRequests: [_quote(status: 'SENT')],
        );

        expect(readiness.state, ProviderQuoteReadinessState.featureDisabled);
        expect(readiness.providerCount, isNull);
        expect(readiness.quoteRequestCount, isNull);
      },
    );

    test('requires a real current plan when quotes flag is enabled', () {
      final readiness = ProviderQuoteReadiness.fromSources(
        featureFlags: _providerQuotesEnabled,
      );

      expect(readiness.state, ProviderQuoteReadinessState.missingCurrentPlan);
      expect(readiness.currentPlanId, isNull);
    });

    test('becomes ready from source-backed providers and quote requests', () {
      final readiness = ProviderQuoteReadiness.fromSources(
        featureFlags: _providerQuotesEnabled,
        planSummary: PlanSummaryReadiness.fromSources(plan: _plan()),
        providers: [_provider()],
        services: [_service()],
        quoteRequests: [
          _quote(status: 'SENT'),
          _quote(status: 'RESPONDED'),
        ],
      );

      expect(readiness.state, ProviderQuoteReadinessState.ready);
      expect(readiness.currentPlanId, 'plan-1');
      expect(readiness.providerCount, 1);
      expect(readiness.serviceCount, 1);
      expect(readiness.quoteRequestCount, 2);
      expect(readiness.newQuoteRequestCount, 1);
    });

    test('preserves pending sync without implying confirmed bookings', () {
      final readiness = ProviderQuoteReadiness.fromSources(
        featureFlags: _providerQuotesEnabled,
        planSummary: PlanSummaryReadiness.fromSources(
          plan: _plan(),
          syncStatus: const SyncStatusSnapshot(
            state: SyncState.hasPendingChanges,
            pendingCount: 2,
          ),
        ),
        quoteRequests: [_quote(status: 'SENT')],
      );

      expect(readiness.state, ProviderQuoteReadinessState.offlinePendingSync);
      expect(readiness.pendingSyncCount, 2);
      expect(readiness.hasBookingSignals, isFalse);
    });
  });
}

const _providerQuotesEnabled = AppFeatureFlags(
  enableGuestFirstOnboarding: false,
  enableProviderMode: false,
  enableProviderQuotes: true,
  enableGuestContacts: false,
  enableOfflineSync: true,
  enableAIHelper: false,
  enablePushNotifications: false,
  enableSubscriptions: false,
  enableMaps: false,
  enableAnalytics: false,
  enableNewUserBottomNavigation: false,
  enableProviderShell: false,
  enableSingleDashboardSummary: false,
);

WeddingPlan _plan() {
  return WeddingPlan(
    id: 'plan-1',
    ownerUserId: 'user-1',
    title: 'خطة الزفاف',
    currency: 'YER',
    status: 'PLANNING',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
  );
}

MarketplaceProvider _provider() {
  return const MarketplaceProvider(
    id: 'provider-1',
    businessName: 'مزود',
    ownerName: 'مالك',
    ratingAverage: 4.5,
    ratingCount: 3,
    isFeatured: false,
  );
}

MarketplaceService _service() {
  return const MarketplaceService(
    id: 'service-1',
    providerId: 'provider-1',
    title: 'خدمة',
    isFeatured: false,
    isActive: true,
  );
}

QuoteRequest _quote({required String status}) {
  return QuoteRequest(
    id: 'quote-$status',
    providerId: 'provider-1',
    status: status,
  );
}
