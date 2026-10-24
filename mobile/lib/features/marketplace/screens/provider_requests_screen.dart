import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/utils/offer_ends.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../chat/chat_api.dart' show ChatApi;
import '../../finance/finance_api.dart' show FinanceProvider;
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummaryProvider;
import '../models/marketplace_models.dart';
import '../models/provider_board.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/quote_booking_area.dart' show showProviderReviewSheet;
import '../widgets/quote_decision_sheets.dart';

part 'provider_requests_screen.cards.dart';

/// f04 «قارن العروض» and everything else about one service of the wedding:
/// offers side by side to choose from (then f05 asks for the booking), a
/// polite «ما يناسبني» (x10), what is still waiting, an expired offer to ask
/// again (w31), and the booking once chosen.
class ProviderRequestsScreen extends StatefulWidget {
  const ProviderRequestsScreen({
    required this.weddingPlanId,
    this.itemKey,
    this.quoteId,
    this.pickDay,
    super.key,
  });

  final String weddingPlanId;

  /// The board row: a money item id, or `category:<name>`.
  final String? itemKey;

  /// Or the row holding this request (a notification's deep link).
  final String? quoteId;

  /// Tests replace the platform date picker.
  final Future<DateTime?> Function(BuildContext context, DateTime? initial)?
  pickDay;

  @override
  State<ProviderRequestsScreen> createState() => _ProviderRequestsScreenState();
}

class _ProviderRequestsScreenState extends State<ProviderRequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final finance = context.read<FinanceProvider?>();
      if (finance != null &&
          finance.loadedPlanId != widget.weddingPlanId &&
          !finance.isLoading) {
        finance.loadMoney(widget.weddingPlanId);
      }
    });
  }

  ProviderBoardRow? _row(ProviderMarketplaceProvider marketplace) {
    final finance = context.watch<FinanceProvider?>();
    final money = finance?.loadedPlanId == widget.weddingPlanId
        ? finance
        : null;
    final costs = money?.costs ?? const [];
    final rows = buildProviderBoard(
      items: [
        for (final category in money?.categories ?? const [])
          (id: category.id, name: category.name),
      ],
      costs: [
        for (final cost in costs)
          (
            budgetCategoryId: cost.budgetCategoryId,
            providerId: cost.providerId,
            partyName: cost.partyName,
          ),
      ],
      costItemById: {for (final cost in costs) cost.id: cost.budgetCategoryId},
      // Never another plan's request, even if one leaks into the provider.
      quotes: marketplace
          .quotesForPlan(widget.weddingPlanId)
          .where((quote) => quote.weddingPlanId == widget.weddingPlanId)
          .toList(),
    );
    return rows.where((row) => row.key == widget.itemKey).firstOrNull ??
        rows
            .where(
              (row) => row.quotes.any((quote) => quote.id == widget.quoteId),
            )
            .firstOrNull;
  }

  /// «بندك 600 ألف · 21 يناير».
  String? _subtitle(ProviderBoardRow row) {
    final finance = context.watch<FinanceProvider?>();
    final item = finance?.categories
        .where((category) => category.id == row.budgetCategoryId)
        .firstOrNull;
    final allocated = num.tryParse(item?.allocatedAmount ?? '');
    final summary = context.watch<DashboardSummaryProvider?>()?.summary;
    final day = summary?.planId == widget.weddingPlanId
        ? summary?.weddingDate
        : null;
    final parts = [
      if (allocated != null && allocated > 0 && finance?.amountsHidden != true)
        'بندك ${formatCompactMoney(allocated, currencyCode: finance?.summary.currency ?? 'YER')}',
      if (day != null) formatArabicDayMonth(day),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final marketplace = context.watch<ProviderMarketplaceProvider>();
    final row = _row(marketplace);
    final quotes = row?.quotes ?? const <QuoteRequest>[];
    final offers = quotes.where((quote) => quote.canAcceptOrReject).toList();
    final accepted = quotes
        .where((quote) => quote.lifecycleStatus == 'ACCEPTED')
        .toList();
    final waiting = quotes
        .where(
          (quote) =>
              quote.lifecycleStatus == 'PENDING_PROVIDER' ||
              quote.lifecycleStatus == 'READY_TO_SEND',
        )
        .toList();
    final expired = quotes
        .where(
          (quote) =>
              quote.lifecycleStatus == 'RECEIVED' &&
              quote.pendingOffer == null &&
              quote.hasExpiredOffer,
        )
        .toList();
    final earlier = quotes
        .where(
          (quote) =>
              quote.lifecycleStatus == 'REJECTED' ||
              quote.lifecycleStatus == 'CANCELLED',
        )
        .toList();
    final title = row == null
        ? 'المزودين'
        : offers.length >= 2
        ? 'قارن عروض ${row.title}'
        : row.title;

    return AarastScreenFrame(
      maxWidth: 640,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: JourneySubHeader(
              title: title,
              subtitle: row == null ? null : _subtitle(row),
              onBack: () => context.popOrGo(
                AppRouter.planProviders(widget.weddingPlanId),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AarastV3Color.cobalt,
              onRefresh: marketplace.loadScopedQuoteRequests,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  if (row == null || quotes.isEmpty)
                    JourneyBox(
                      key: const ValueKey('requests-empty'),
                      child: Text(
                        'ما في طلبات لهذي الخدمة الآن.',
                        style: JourneyType.of(
                          JourneyType.body,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                    ),
                  if (offers.isNotEmpty) ...[
                    _OffersRow(
                      offers: offers,
                      busy: marketplace.isSubmitting,
                      onChoose: _choose,
                      onDecline: _decline,
                      onChat: _openChat,
                    ),
                    const SizedBox(height: 12),
                    const JourneyNote(
                      key: ValueKey('requests-choose-note'),
                      text: 'لما تختار، يصير بند في المال، ونطلب منهم حجز يوم عرسك.',
                      icon: LucideIcons.wallet,
                      color: AarastV3Color.primary,
                      soft: AarastV3Color.primarySoft,
                    ),
                  ],
                  for (final quote in accepted) ...[
                    const SizedBox(height: 12),
                    _ChosenCard(
                      quote: quote,
                      busy: marketplace.isSubmitting,
                      onBook: () => _book(quote),
                      onCancelBooking: () => _cancelBooking(quote),
                      onViewCost: () => _viewCost(quote),
                      onRate: () => showProviderReviewSheet(
                        context,
                        providerId: quote.providerId,
                        providerName: quote.provider?.businessName,
                      ),
                      onChat: () => _openChat(quote),
                    ),
                  ],
                  for (final quote in expired) ...[
                    const SizedBox(height: 12),
                    _ExpiredCard(
                      quote: quote,
                      onAskAgain: () =>
                          context.push(AppRouter.providerQuote(quote.providerId)),
                    ),
                  ],
                  if (waiting.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    const JourneySectionTitle('ينتظرون ردهم'),
                    JourneyBox(
                      padding: EdgeInsets.zero,
                      child: JourneyList(
                        children: [
                          for (final quote in waiting)
                            JourneyListRow(
                              key: ValueKey('requests-waiting-${quote.id}'),
                              icon: LucideIcons.hourglass,
                              color: AarastV3Color.cobalt,
                              soft: AarastV3Color.cobaltSoft,
                              title: quoteProviderName(quote),
                              subtitle: quote.createdAt == null
                                  ? 'ينتظر الرد'
                                  : 'طلبت ${formatArabicDayMonth(quote.createdAt!)} · ينتظر الرد',
                              onTap: () => _openChat(quote),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (earlier.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    const JourneySectionTitle('السابقة'),
                    JourneyBox(
                      padding: EdgeInsets.zero,
                      child: JourneyList(
                        children: [
                          for (final quote in earlier)
                            JourneyListRow(
                              key: ValueKey('requests-earlier-${quote.id}'),
                              icon: LucideIcons.archive,
                              color: AarastV3Color.textMuted,
                              soft: AarastV3Color.canvas,
                              title: quoteProviderName(quote),
                              subtitle: quote.lifecycleStatus == 'REJECTED'
                                  ? 'اعتذرت عن عرضهم'
                                  : 'انلغى الطلب',
                              onTap: () => _openChat(quote),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Acting on another plan's request is refused, whatever the UI shows.
  bool _ownQuote(QuoteRequest quote) {
    if (quote.weddingPlanId == widget.weddingPlanId) return true;
    AarastToast.showError(context, 'هذا الطلب مش من خطتك الحالية.');
    return false;
  }

  QuoteRequest _fresh(QuoteRequest quote) {
    final marketplace = context.read<ProviderMarketplaceProvider>();
    return marketplace.quoteRequests
            .where((item) => item.id == quote.id)
            .firstOrNull ??
        quote;
  }

  /// «اختر هذا»: the offer becomes a cost in the money tab, then f05 asks
  /// for the booking.
  Future<void> _choose(QuoteRequest quote) async {
    if (!_ownQuote(quote)) return;
    final marketplace = context.read<ProviderMarketplaceProvider>();
    final ok = await marketplace.acceptQuote(quote);
    if (!mounted) return;
    if (!ok) {
      AarastToast.showError(
        context,
        marketplace.errorMessage ?? 'ما قدرنا نختار العرض.',
      );
      return;
    }
    await context.read<FinanceProvider?>()?.loadMoney(widget.weddingPlanId);
    if (!mounted) return;
    AarastToast.showSuccess(context, 'اخترت ${quoteProviderName(quote)}، وصار بند في المال.');
    await _book(_fresh(quote));
  }

  Future<void> _book(QuoteRequest quote) async {
    if (!_ownQuote(quote)) return;
    final summary = context.read<DashboardSummaryProvider?>()?.summary;
    final mine = summary?.planId == widget.weddingPlanId ? summary : null;
    final place =
        mine?.location?['fullLabel']?.toString().trim() ??
        mine?.city?.trim();
    final day = await showAarastBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BookingRequestSheet(
        quote: quote,
        day: quote.eventDate ?? mine?.weddingDate,
        place: place,
        pickDay: widget.pickDay,
      ),
    );
    if (day == null || !mounted) return;
    final marketplace = context.read<ProviderMarketplaceProvider>();
    final ok = await marketplace.requestBooking(quote, eventDate: day);
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(context, 'وصلهم طلب الحجز. نخبرك لما يأكدون.');
    } else {
      AarastToast.showError(
        context,
        marketplace.errorMessage ?? 'ما وصل طلب الحجز. جرّب مرة ثانية.',
      );
    }
  }

  /// x10: the polite message goes first; the offer is declined only once it
  /// arrived, so the provider never sees a silent «رفض».
  Future<void> _decline(QuoteRequest quote) async {
    if (!_ownQuote(quote)) return;
    final message = await showAarastBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DeclineOfferSheet(quote: quote),
    );
    if (message == null || !mounted) return;
    final chat = context.read<ChatApi>();
    final marketplace = context.read<ProviderMarketplaceProvider>();
    try {
      final conversation = await chat.conversationForQuote(quote.id);
      await chat.send(conversation.id, body: message);
    } catch (_) {
      if (mounted) {
        AarastToast.showError(context, 'ما وصلت رسالتك. جرّب مرة ثانية.');
      }
      return;
    }
    final ok = await marketplace.rejectQuote(quote);
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(context, 'وصلتهم رسالتك واعتذرت عن العرض.');
    } else {
      AarastToast.showError(
        context,
        marketplace.errorMessage ?? 'وصلت رسالتك، بس ما قدرنا نسجّل الاعتذار.',
      );
    }
  }

  /// x11: the provider is told; the cost stays in the money tab for the
  /// groom to settle with them.
  Future<void> _cancelBooking(QuoteRequest quote) async {
    if (!_ownQuote(quote)) return;
    final confirmed = await showAarastBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _CancelBookingSheet(quote: quote),
    );
    if (confirmed != true || !mounted) return;
    final marketplace = context.read<ProviderMarketplaceProvider>();
    final ok = await marketplace.cancelBooking(quote);
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(context, 'انلغى الحجز ووصلهم الخبر.');
    } else {
      AarastToast.showError(
        context,
        marketplace.errorMessage ?? 'ما قدرنا نلغي الحجز.',
      );
    }
  }

  void _viewCost(QuoteRequest quote) {
    final costId = quote.costSuggestion?.costId?.trim();
    if (costId == null || costId.isEmpty) {
      AarastToast.showError(context, 'ما لقينا البند في المال.');
      return;
    }
    context.push(AppRouter.moneyCostDetails(widget.weddingPlanId, costId));
  }

  void _openChat(QuoteRequest quote) {
    context.push(AppRouter.quoteConversation(quote.id));
  }
}
