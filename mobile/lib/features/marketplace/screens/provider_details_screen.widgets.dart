part of 'provider_details_screen.dart';

extension _ProviderQuoteFooter on _ProviderDetailsScreenState {
  /// The quote footer: the latest quote's status and the primary quote action.
  Widget _quoteFooter(String? selectedPlanId) {
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceRaised,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Consumer<ProviderMarketplaceProvider>(
            builder: (context, marketplace, _) {
              final quotes = marketplace.quotesForProviderInScope(
                widget.providerId,
                weddingPlanId: selectedPlanId,
              );
              final latest = quotes.isEmpty ? null : quotes.first;
              final loadingQuote =
                  !_quoteContextReady ||
                  marketplace.isProviderQuoteContextLoading(widget.providerId);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (latest != null) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(6, 2, 6, 7),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'آخر طلب لهذا المورد',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            QuoteStatusChip(
                              status: latest.lifecycleStatus,
                              compact: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        if (latest != null) ...[
                          _ContactIconButton(
                            key: const Key('provider-details-conversation'),
                            onTap: () => _openQuoteConversation(latest.id),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: AarastButton(
                            label: _primaryQuoteActionLabel(latest),
                            icon: LucideIcons.filePlus2,
                            isLoading: loadingQuote,
                            onPressed: loadingQuote
                                ? null
                                : () =>
                                      _openPrimaryQuoteAction(context, latest),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

Future<void> _shareProvider(
  BuildContext context,
  MarketplaceProvider provider,
) async {
  final city = provider.city?.nameAr.trim();
  final snippet = city == null || city.isEmpty
      ? provider.businessName
      : '${provider.businessName} — $city';
  await Clipboard.setData(ClipboardData(text: snippet));
  if (!context.mounted) return;
  AarastToast.showSuccess(context, 'تم نسخ بيانات المورد للمشاركة');
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

String _primaryQuoteActionLabel(QuoteRequest? quote) {
  if (quote == null) return 'طلب عرض سعر';
  if (quote.status == 'SENT' || quote.status == 'VIEWED') {
    return 'متابعة الطلب الحالي';
  }
  if (quote.status == 'RESPONDED') {
    return quote.hasExpiredOffer ? 'طلب عرض جديد' : 'مراجعة العرض';
  }
  if (quote.status == 'ACCEPTED') return 'عرض المورد في الخطة';
  return 'طلب عرض جديد';
}

class _ContactIconButton extends StatelessWidget {
  const _ContactIconButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'المحادثات',
      child: SizedBox(
        width: 54,
        height: 54,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: AppTheme.brand,
            backgroundColor: AppTheme.surfaceRaised,
            side: const BorderSide(color: AppTheme.border),
            shape: const CircleBorder(),
          ),
          child: const Icon(LucideIcons.messageCircle, size: 22),
        ),
      ),
    );
  }
}

class _DetailsFrame extends StatelessWidget {
  const _DetailsFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: IconButton(
            tooltip: 'رجوع',
            onPressed: () {
              if (context.canPop()) context.pop();
            },
            icon: const Icon(LucideIcons.chevronRight),
          ),
        ),
        const SizedBox(height: 80),
        child,
      ],
    );
  }
}
