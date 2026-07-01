import '../../../core/config/app_feature_flags.dart';
import '../../wedding_plans/models/plan_summary_readiness.dart';
import 'marketplace_models.dart';

enum ProviderQuoteReadinessState {
  featureDisabled,
  missingCurrentPlan,
  waitingForSources,
  ready,
  offlinePendingSync,
  loading,
  blockedByError,
}

class ProviderQuoteReadiness {
  const ProviderQuoteReadiness({
    this.currentPlanId,
    this.providerQuotesEnabled = false,
    this.sourceProviderCount,
    this.sourceServiceCount,
    this.sourceQuoteRequestCount,
    this.sourceNewQuoteRequestCount,
    this.pendingSyncCount,
    this.isLoading = false,
    this.errorMessage,
  });

  const factory ProviderQuoteReadiness.empty() = ProviderQuoteReadiness;

  factory ProviderQuoteReadiness.fromSources({
    AppFeatureFlags featureFlags = AppFeatureFlags.defaults,
    PlanSummaryReadiness planSummary = const PlanSummaryReadiness.empty(),
    List<MarketplaceProvider>? providers,
    List<MarketplaceService>? services,
    List<QuoteRequest>? quoteRequests,
    bool isLoading = false,
    String? errorMessage,
  }) {
    return ProviderQuoteReadiness(
      currentPlanId: planSummary.currentPlanId,
      providerQuotesEnabled: featureFlags.enableProviderQuotes,
      sourceProviderCount: providers?.length,
      sourceServiceCount: services?.length,
      sourceQuoteRequestCount: quoteRequests?.length,
      sourceNewQuoteRequestCount: quoteRequests
          ?.where((quote) => quote.status == 'SENT' || quote.status == 'NEW')
          .length,
      pendingSyncCount: planSummary.pendingSyncCount,
      isLoading: isLoading || planSummary.isLoading,
      errorMessage: errorMessage ?? planSummary.errorMessage,
    );
  }

  final String? currentPlanId;
  final bool providerQuotesEnabled;
  final int? sourceProviderCount;
  final int? sourceServiceCount;
  final int? sourceQuoteRequestCount;
  final int? sourceNewQuoteRequestCount;
  final int? pendingSyncCount;
  final bool isLoading;
  final String? errorMessage;

  int? get providerCount => providerQuotesEnabled ? sourceProviderCount : null;

  int? get serviceCount => providerQuotesEnabled ? sourceServiceCount : null;

  int? get quoteRequestCount =>
      providerQuotesEnabled ? sourceQuoteRequestCount : null;

  int? get newQuoteRequestCount =>
      providerQuotesEnabled ? sourceNewQuoteRequestCount : null;

  bool get hasCurrentPlan =>
      currentPlanId != null && currentPlanId!.trim().isNotEmpty;

  bool get hasPendingSync => (pendingSyncCount ?? 0) > 0;

  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;

  bool get hasVisibleProviderQuoteSource =>
      providerCount != null ||
      serviceCount != null ||
      quoteRequestCount != null;

  bool get hasBookingSignals => false;

  ProviderQuoteReadinessState get state {
    if (!providerQuotesEnabled) {
      return ProviderQuoteReadinessState.featureDisabled;
    }
    if (isLoading) {
      return ProviderQuoteReadinessState.loading;
    }
    if (hasError) {
      return ProviderQuoteReadinessState.blockedByError;
    }
    if (!hasCurrentPlan) {
      return ProviderQuoteReadinessState.missingCurrentPlan;
    }
    if (!hasVisibleProviderQuoteSource) {
      return ProviderQuoteReadinessState.waitingForSources;
    }
    if (hasPendingSync) {
      return ProviderQuoteReadinessState.offlinePendingSync;
    }
    return ProviderQuoteReadinessState.ready;
  }
}
