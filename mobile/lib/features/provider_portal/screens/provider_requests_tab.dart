import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../marketplace/marketplace_api.dart'
    show
        QuoteRequest,
        QuoteStatusChip;
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_bookings.dart' show ProviderBookingPanel;
import 'provider_offer_dialog.dart';

export 'provider_offer_dialog.dart' show validateProviderOfferAmount;

class ProviderRequestsTab extends StatefulWidget {
  const ProviderRequestsTab({super.key});

  @override
  State<ProviderRequestsTab> createState() => _ProviderRequestsTabState();
}

class _ProviderRequestsTabState extends State<ProviderRequestsTab> {
  String _filter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final quotes = dashboard.quoteRequests.where(_matches).toList();
    return RefreshIndicator(
      color: AppTheme.brand,
      onRefresh: dashboard.loadDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 128),
        children: [
          const AarastSectionHeader(
            title: 'طلبات الأسعار',
            subtitle: 'راجع الطلب، أرسل عرضك، ثم ناقش التفاصيل داخل اعّرست.',
            icon: LucideIcons.mailQuestion,
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            style: const ButtonStyle(
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 4),
              ),
              textStyle: WidgetStatePropertyAll(
                TextStyle(fontWeight: FontWeight.w800),
              ),
              visualDensity: VisualDensity.compact,
            ),
            segments: const [
              ButtonSegment(
                value: 'ALL',
                label: Text('الكل', maxLines: 1, softWrap: false),
              ),
              ButtonSegment(
                value: 'NEW',
                label: Text('جديد', maxLines: 1, softWrap: false),
              ),
              ButtonSegment(
                value: 'OFFERED',
                label: Text('تم العرض', maxLines: 1, softWrap: false),
              ),
              ButtonSegment(
                value: 'CLOSED',
                label: Text('مغلق', maxLines: 1, softWrap: false),
              ),
            ],
            selected: {_filter},
            onSelectionChanged: (value) =>
                setState(() => _filter = value.first),
          ),
          const SizedBox(height: 16),
          if (dashboard.isLoading && dashboard.quoteRequests.isEmpty)
            const AarastScreenLoading(label: 'جارٍ تحميل الطلبات...')
          else if (quotes.isEmpty)
            const AarastEmptyState(
              icon: LucideIcons.inbox,
              title: 'لا توجد طلبات في هذا القسم',
              message: 'ستظهر الطلبات الجديدة هنا فور وصولها.',
            )
          else
            for (final quote in quotes) ...[
              _ProviderRequestCard(
                quote: quote,
                onChat: () {
                  // Opening a new request is what the customer reads as
                  // «شاف طلبك».
                  dashboard.markQuoteViewed(quote.id);
                  context.push(AppRouter.quoteConversation(quote.id));
                },
                onOffer: _offerModeOf(quote) == null
                    ? null
                    : () {
                        dashboard.markQuoteViewed(quote.id);
                        showProviderOfferDialog(context, quote);
                      },
                offerMode: _offerModeOf(quote),
                onDecline: _canDecline(quote)
                    ? () => _confirmDecline(context, quote)
                    : null,
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  bool _matches(QuoteRequest quote) {
    if (_filter == 'ALL') return true;
    if (_filter == 'NEW') {
      return quote.lifecycleStatus == 'PENDING_PROVIDER';
    }
    if (_filter == 'OFFERED') {
      return quote.lifecycleStatus == 'RECEIVED';
    }
    return const {
      'ACCEPTED',
      'REJECTED',
      'CANCELLED',
    }.contains(quote.lifecycleStatus);
  }
}

/// What the offer button does on a request: send the first offer, edit the
/// open one, or renew one whose time ran out (the server lets a provider
/// change a pending offer, expired or not, while the request awaits a reply).
enum _OfferMode { send, edit, renew }

_OfferMode? _offerModeOf(QuoteRequest quote) {
  if (quote.pendingOffer != null) return _OfferMode.edit;
  if (quote.expiredOffer != null) return _OfferMode.renew;
  if (quote.lifecycleStatus == 'PENDING_PROVIDER') return _OfferMode.send;
  return null;
}

/// The server lets the provider decline a request until he sends an offer.
bool _canDecline(QuoteRequest quote) =>
    quote.status == 'SENT' || quote.status == 'VIEWED';

Future<void> _confirmDecline(BuildContext context, QuoteRequest quote) async {
  final dashboard = context.read<ProviderDashboardProvider>();
  final confirmed = await showJourneySheet<bool>(
    context: context,
    builder: (sheetContext) => JourneySheetBody(
      title: 'تعتذر عن الطلب؟',
      subtitle:
          'بيوصل العميل إنك اعتذرت، وما تقدر ترسل له عرض على هذا الطلب بعدها.',
      children: [
        JourneyButton(
          key: const Key('provider-quote-decline-confirm'),
          label: 'اعتذر عن الطلب',
          background: AarastV3Color.danger,
          expand: true,
          large: true,
          onPressed: () => Navigator.of(sheetContext).pop(true),
        ),
        const SizedBox(height: 8),
        JourneyButton.quiet(
          label: 'رجوع',
          expand: true,
          onPressed: () => Navigator.of(sheetContext).pop(false),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final ok = await dashboard.updateQuoteStatus(
    quoteRequestId: quote.id,
    status: 'REJECTED',
  );
  if (!context.mounted) return;
  if (ok) {
    AarastToast.showSuccess(context, 'اعتذرت عن الطلب، ووصل العميل خبر.');
  } else {
    AarastToast.showError(
      context,
      dashboard.errorMessage ?? 'تعذر الاعتذار عن الطلب. حاول مرة ثانية.',
    );
  }
}

class _ProviderRequestCard extends StatelessWidget {
  const _ProviderRequestCard({
    required this.quote,
    required this.onChat,
    this.onOffer,
    this.offerMode,
    this.onDecline,
  });

  final QuoteRequest quote;
  final VoidCallback onChat;
  final VoidCallback? onOffer;
  final _OfferMode? offerMode;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  quote.service?.title ?? 'طلب عرض سعر',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              QuoteStatusChip(
                status: quote.lifecycleStatus,
                compact: true,
                forProvider: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProviderQuoteFacts(quote: quote),
          if (quote.message?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              quote.message!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChat,
                  icon: const Icon(LucideIcons.messageCircle),
                  label: const Text('محادثة'),
                ),
              ),
              if (onOffer != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    key: Key('provider-offer-open-${quote.id}'),
                    onPressed: onOffer,
                    icon: Icon(switch (offerMode) {
                      _OfferMode.edit => LucideIcons.fileEdit,
                      _OfferMode.renew => LucideIcons.refreshCw,
                      _ => LucideIcons.send,
                    }),
                    label: Text(switch (offerMode) {
                      _OfferMode.edit => 'تعديل العرض',
                      _OfferMode.renew => 'جدّد العرض',
                      _ => 'إرسال عرض',
                    }),
                  ),
                ),
              ],
            ],
          ),
          if (onDecline != null)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: JourneyTextAction(
                key: Key('provider-quote-decline-${quote.id}'),
                label: 'اعتذار',
                icon: LucideIcons.x,
                color: AarastV3Color.danger,
                onPressed: onDecline,
              ),
            ),
          if (quote.booking case final booking?) ...[
            const SizedBox(height: 12),
            ProviderBookingPanel(booking: booking),
          ],
        ],
      ),
    );
  }
}

/// What a provider needs to price a request at a glance: who is asking, for
/// which day, where and for how many guests (field test Q12).
class ProviderQuoteFacts extends StatelessWidget {
  const ProviderQuoteFacts({required this.quote, super.key});

  final QuoteRequest quote;

  @override
  Widget build(BuildContext context) {
    final name = (quote.contactName ?? quote.userName)?.trim();
    final place = quote.location?.displayLabel.trim();
    final eventDate = quote.eventDate;
    final guests = quote.guestCount;
    final facts = <(IconData, String)>[
      if (name != null && name.isNotEmpty) (LucideIcons.user, name),
      if (eventDate != null)
        (LucideIcons.calendar, formatArabicCompactDate(eventDate)),
      if (place != null && place.isNotEmpty) (LucideIcons.mapPin, place),
      if (guests != null && guests > 0) (LucideIcons.users, 'الضيوف: $guests'),
    ];
    if (facts.isEmpty) return const SizedBox.shrink();
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppTheme.textSecondary,
      fontWeight: FontWeight.w700,
    );
    return Wrap(
      key: const ValueKey('provider-quote-facts'),
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (icon, label) in facts)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
