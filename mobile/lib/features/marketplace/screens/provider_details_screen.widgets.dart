part of 'provider_details_screen.dart';

/// Why no request can be sent for the plan's wedding day, from the page's
/// own `dayStatus` (the server refuses it too, 409
/// PROVIDER_DAY_UNAVAILABLE); null when nothing stops it.
String? _dayBlock(
  ProviderMarketplaceProvider state,
  MarketplaceProvider provider,
) {
  final day = state.eventDate;
  if (day == null || planDayIsPast(day, appNow())) return null;
  // The day is full with the reader's own booking: nothing to refuse, the
  // footer says where that booking stands.
  if (state.providersBookedByReader.contains(provider.id)) return null;
  return providerFooterDayBlock(provider.dayStatus);
}

/// What the page reads for its view, beside the screen's own loading.
extension _ProviderPageReads on _ProviderDetailsScreenState {
  /// «المزيد من التقييمات». A page that did not come is said: the button
  /// went quiet for a moment and came back, with no reviews and no word.
  Future<void> _loadMoreReviews(
    ProviderMarketplaceProvider state,
    String providerId,
  ) async {
    await state.loadMoreReviews(providerId);
    if (!mounted) return;
    final error = state.reviewsErrorFor(providerId);
    if (error != null) AarastToast.showError(context, error);
  }

  /// «ضمن بندك»: the plan's item for his kind has an amount, and his lowest
  /// riyal price fits it.
  bool _withinBudget(
    MarketplaceProvider provider,
    List<MarketplaceService> services,
    String? planId,
  ) {
    final finance = context.read<FinanceProvider?>();
    if (planId == null || finance?.loadedPlanId != planId) return false;
    // G40: the item his offers land in, as the server lists it.
    final item = budgetItemForCategories(
      finance!.categories,
      (item) => finance.providerCategoryIdsFor(item.id),
      [
        provider.primaryCategory?.id ?? provider.primaryCategoryId,
        for (final service in services) service.category?.id,
      ],
    );
    final allocated = num.tryParse(item?.allocatedAmount ?? '') ?? 0;
    final span = providerOwnKindSpan(
      provider,
      services,
      context.read<ProviderMarketplaceProvider>().packagesFor(provider.id),
    );
    return span != null &&
        span.currency == defaultCurrencyCode &&
        priceFitsItem(span.min, allocated);
  }
}

/// The footer's reason for a closed or a full day; null otherwise.
String? providerFooterDayBlock(ProviderDayStatus? status) => switch (status) {
  ProviderDayStatus.closed => aarastText.providersDayClosedReason,
  ProviderDayStatus.full => aarastText.providersDayFullReason,
  null => null,
};

/// f03's footer, one filled button (REFINEMENT_SPEC 2.6). A claimed
/// listing: «اطلب عرض سعر» (or where the latest request stands) and
/// «واتساب»; on a closed or full wedding day the request waits, disabled,
/// with the reason over it. An unclaimed listing takes no request (w33):
/// «اتصل» and «واتساب», with why.
extension _ProviderQuoteFooter on _ProviderDetailsScreenState {
  Widget _quoteFooter(String? selectedPlanId) {
    return Consumer<ProviderMarketplaceProvider>(
      builder: (context, marketplace, _) {
        final provider = marketplace.providerDetails(widget.providerId);
        if (provider == null) return const SizedBox.shrink();
        final gender = context.gender;
        final onWhatsApp = _externalLinkAction(
          context,
          providerWhatsAppUri(provider.whatsapp),
          aarastText.providersWhatsAppFailed,
        );
        final String? reason;
        final Widget main;
        if (!provider.isClaimed) {
          reason = aarastText.providersUnclaimedFooter(gender);
          main = JourneyButton(
            key: const Key('provider-details-call'),
            label: aarastText.providersCall(gender),
            icon: LucideIcons.phone,
            large: true,
            expand: true,
            onPressed: _externalLinkAction(
              context,
              phoneCallUri(provider.phone),
              aarastText.providersCallFailed,
            ),
          );
        } else {
          final quotes = marketplace.quotesForProviderInScope(
            widget.providerId,
            weddingPlanId: selectedPlanId,
          );
          final latest = quotes.isEmpty ? null : quotes.first;
          final loading =
              !_quoteContextReady ||
              marketplace.isProviderQuoteContextLoading(widget.providerId);
          final asksNew = providerFooterAsksForNewQuote(latest);
          // A day he cannot take stops a new request only; a request under
          // way stays open to follow.
          reason = asksNew ? _dayBlock(marketplace, provider) : null;
          main = JourneyButton(
            key: const Key('provider-details-quote'),
            label: _primaryQuoteActionLabel(latest, gender),
            large: true,
            expand: true,
            loading: loading,
            onPressed: loading || reason != null
                ? null
                : () => _openPrimaryQuoteAction(context, latest),
          );
        }
        return SafeArea(
          top: false,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AarastV3Color.paper,
              border: Border(top: BorderSide(color: AarastV3Color.line)),
            ),
            child: Padding(
              padding: AarastV3Density.actionInsets,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (reason != null) ...[
                    Text(
                      reason,
                      key: const Key('provider-details-footer-reason'),
                      textAlign: TextAlign.center,
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                    const SizedBox(height: AarastV3Space.x2),
                  ],
                  // «واتساب» takes its own width and the main action the
                  // rest: a word may go to a second line, never a letter
                  // (at 320 and 1.3 a shared split broke «واتساب» in two).
                  LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        Expanded(child: main),
                        if (onWhatsApp != null) ...[
                          const SizedBox(width: AarastV3Space.x2),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                                  constraints.maxWidth *
                                  JourneyEndRow.amountShare,
                            ),
                            child: JourneyButton.outline(
                              key: const Key('provider-whatsapp-action'),
                              label: aarastText.providersWhatsApp,
                              icon: LucideIcons.messageCircle,
                              large: true,
                              onPressed: onWhatsApp,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Opens [uri] outside the app; null (no link) hides or disables the
/// action. A phone that cannot open it says so instead of doing nothing.
VoidCallback? _externalLinkAction(
  BuildContext context,
  Uri? uri,
  String failure,
) {
  if (uri == null) return null;
  // The page's one way out of the app (`openOutsideApp`).
  return () => openOutsideApp(context, uri, failure);
}

/// The footer asks for a new request: there is none, or the latest is over
/// (cancelled, declined, past its days, its offer expired). The label and
/// the tap read this one rule (RA-MO-251).
bool providerFooterAsksForNewQuote(QuoteRequest? quote) {
  if (quote == null) return true;
  return switch (quote.status) {
    'SENT' || 'VIEWED' || 'ACCEPTED' => false,
    'RESPONDED' => quote.hasExpiredOffer,
    _ => true,
  };
}

/// Where the latest request to him stands, as the footer's action.
String _primaryQuoteActionLabel(QuoteRequest? quote, String gender) {
  if (quote == null) return aarastText.providersRequestQuote(gender);
  if (providerFooterAsksForNewQuote(quote)) {
    return aarastText.providersRequestAgain(gender);
  }
  if (quote.status == 'SENT' || quote.status == 'VIEWED') {
    return aarastText.providersFollowRequest(gender);
  }
  if (quote.status == 'RESPONDED') return aarastText.providersOpenOffer(gender);
  return aarastText.providersOpenInRequests(gender);
}

/// A page with no provider to show yet, or none at all: the way back above
/// the state.
class _DetailsFrame extends StatelessWidget {
  const _DetailsFrame({
    required this.onBack,
    required this.phase,
    required this.onRetry,
  });

  final VoidCallback onBack;
  final JourneyListPhase phase;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (title, body, action) = switch (phase) {
      JourneyListPhase.error => (
        aarastText.providersDetailsErrorTitle,
        aarastText.providersLoadErrorBody(context.gender),
        aarastText.providersRetry(context.gender),
      ),
      _ => (
        aarastText.providersDetailsMissingTitle,
        aarastText.providersDetailsMissingBody,
        null,
      ),
    };
    return ListView(
      padding: AarastV3Density.pageInsets,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: JourneyRoundButton(
            key: const ValueKey('provider-details-back'),
            icon: LucideIcons.arrowRight,
            tooltip: aarastText.providersBack,
            onPressed: onBack,
          ),
        ),
        const SizedBox(height: AarastV3Space.x5),
        if (phase == JourneyListPhase.loading)
          const JourneyListState(
            phase: JourneyListPhase.loading,
            section: JourneySection.providers,
          )
        else
          Column(
            key: ValueKey('provider-details-${phase.name}'),
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: JourneyType.of(
                  JourneyType.lead,
                  weight: JourneyType.bold,
                ),
              ),
              const SizedBox(height: AarastV3Space.x1),
              Text(
                body,
                textAlign: TextAlign.center,
                style: JourneyType.of(
                  JourneyType.body,
                  color: AarastV3Color.textMuted,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: AarastV3Space.x3),
                JourneyButton(label: action, onPressed: onRetry),
              ],
            ],
          ),
      ],
    );
  }
}
