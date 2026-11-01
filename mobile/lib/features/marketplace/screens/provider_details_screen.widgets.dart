part of 'provider_details_screen.dart';

/// f03's footer: «اطلب عرض سعر» (or where the latest request stands) and
/// «واتساب». An unclaimed listing (w33) cannot take requests, so it says so
/// and keeps WhatsApp only.
extension _ProviderQuoteFooter on _ProviderDetailsScreenState {
  Widget _quoteFooter(String? selectedPlanId) {
    return Consumer<ProviderMarketplaceProvider>(
      builder: (context, marketplace, _) {
        final provider = marketplace.providerDetails(widget.providerId);
        final claimed = provider?.isClaimed != false;
        final quotes = marketplace.quotesForProviderInScope(
          widget.providerId,
          weddingPlanId: selectedPlanId,
        );
        final latest = quotes.isEmpty ? null : quotes.first;
        final loadingQuote =
            !_quoteContextReady ||
            marketplace.isProviderQuoteContextLoading(widget.providerId);
        final onWhatsApp = provider == null
            ? null
            : _externalLinkAction(
                context,
                providerWhatsAppUri(provider.whatsapp),
                'ما قدرنا نفتح واتساب على هذا الجوال.',
              );
        if (!claimed && onWhatsApp == null) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: _UnclaimedLine(),
            ),
          );
        }
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!claimed) ...[_UnclaimedLine(), const SizedBox(height: 8)],
                Row(
                  children: [
                    if (claimed)
                      Expanded(
                        child: JourneyButton(
                          key: const Key('provider-details-quote'),
                          label: _primaryQuoteActionLabel(
                            latest,
                            context.journeyProfile,
                          ),
                          background: context.accent.primary,
                          large: true,
                          expand: true,
                          loading: loadingQuote,
                          onPressed: loadingQuote
                              ? null
                              : () => _openPrimaryQuoteAction(context, latest),
                        ),
                      ),
                    if (onWhatsApp != null) ...[
                      if (claimed) const SizedBox(width: 10),
                      Expanded(
                        flex: claimed ? 0 : 1,
                        child: JourneyButton(
                          key: const Key('provider-whatsapp-action'),
                          label: 'واتساب',
                          icon: LucideIcons.messageCircle,
                          background: AarastV3Color.mintSoft,
                          foreground: AarastV3Color.mint,
                          large: true,
                          expand: !claimed,
                          onPressed: onWhatsApp,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Opens [uri] outside the app; null (no link) hides the action. A device
/// that cannot open it gets [failure] instead of a silent no-op.
VoidCallback? _externalLinkAction(
  BuildContext context,
  Uri? uri,
  String failure,
) {
  if (uri == null) return null;
  return () async {
    bool opened;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      opened = false;
    } on MissingPluginException {
      opened = false;
    }
    if (!opened && context.mounted) AarastToast.showError(context, failure);
  };
}

/// Where the latest request to this provider stands, as the footer's action.
String _primaryQuoteActionLabel(QuoteRequest? quote, JourneyProfile profile) {
  final say = profile.say;
  if (quote == null) return say('اطلب عرض سعر', 'اطلبي عرض سعر');
  if (quote.status == 'SENT' || quote.status == 'VIEWED') {
    return say('تابع طلبك', 'تابعي طلبك');
  }
  if (quote.status == 'RESPONDED') {
    return quote.hasExpiredOffer
        ? say('اطلب عرض جديد', 'اطلبي عرض جديد')
        : say('شوف العرض', 'شوفي العرض');
  }
  if (quote.status == 'ACCEPTED') {
    return say('شوفه في طلباتي', 'شوفيه في طلباتي');
  }
  return say('اطلب عرض جديد', 'اطلبي عرض جديد');
}

/// w33: an unclaimed listing takes no requests until its owner claims it.
const unclaimedProviderMessage = 'ما يستقبل طلبات لين يستلم صاحبه ملفه';

class _UnclaimedLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      unclaimedProviderMessage,
      key: const Key('provider-details-unclaimed'),
      textAlign: TextAlign.center,
      style: JourneyType.of(JourneyType.small, color: AarastV3Color.textMuted),
    );
  }
}

/// A page with no provider to show: the way back above [child].
class _DetailsFrame extends StatelessWidget {
  const _DetailsFrame({required this.onBack, required this.child});

  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: JourneyRoundButton(
            key: const ValueKey('provider-details-back'),
            icon: LucideIcons.arrowRight,
            tooltip: 'رجوع',
            onPressed: onBack,
          ),
        ),
        const SizedBox(height: 24),
        child,
      ],
    );
  }
}
