import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/utils/offer_changes.dart';
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// A notification can open this page first, so it reads the plan's
  /// requests and money itself. The route's gate has already checked that
  /// this account manages the plan's providers.
  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final finance = context.read<FinanceProvider?>();
    final marketplace = context.read<ProviderMarketplaceProvider>();
    marketplace.configureAccountScope(
      includeAccountData: true,
      weddingPlanId: widget.weddingPlanId,
    );
    await Future.wait([
      marketplace.loadScopedQuoteRequests(),
      if (finance != null &&
          finance.loadedPlanId != widget.weddingPlanId &&
          !finance.isLoading)
        finance.loadMoney(widget.weddingPlanId),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  ProviderBoardRow? _row(ProviderMarketplaceProvider marketplace) {
    final finance = context.watch<FinanceProvider?>();
    final money = finance?.loadedPlanId == widget.weddingPlanId
        ? finance
        : null;
    final costs = money?.costs ?? const [];
    final rows = buildProviderBoard(
      items: [
        // The mahr is no provider's service (C1, D55).
        for (final category in money?.categories ?? const [])
          if (!category.isMahr)
            (
              id: category.id,
              name: category.name,
              providerCategoryIds: money!.providerCategoryIdsFor(category.id),
            ),
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
      reader: context.journeyProfile,
      // D60: booked as the server counts it (the home's «محجوز»).
      booked: switch (context.watch<DashboardSummaryProvider?>()?.summary) {
        final summary? when summary.planId == widget.weddingPlanId => (
          items: summary.bookedServices.itemIds.toSet(),
          quotes: summary.bookedServices.quoteRequestIds.toSet(),
        ),
        _ => null,
      },
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

  /// The reader's money rights, once the money of this plan has been read;
  /// null while they are not known.
  FinanceProvider? get _knownMoney {
    final finance = context.watch<FinanceProvider?>();
    return finance != null &&
            finance.loadedPlanId == widget.weddingPlanId &&
            !finance.isLoading
        ? finance
        : null;
  }

  /// RA-MO-248: choosing an offer makes a money item, so the server asks
  /// for the money right too. The button was offered to everyone who
  /// manages the providers, and the server then refused.
  bool get _mayChoose => _knownMoney?.canManageMoney ?? true;

  /// The server sends no amount to a reader who does not see the money.
  bool get _seesMoney => _knownMoney?.canViewMoney ?? true;

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
              quote.lifecycleStatus == 'CANCELLED' ||
              quote.lifecycleStatus == 'EXPIRED',
        )
        .toList();
    final title = row == null
        ? 'المزودين'
        : offers.length >= 2
        ? '${context.say('قارن', 'قارني')} عروض ${row.title}'
        : row.title;

    return AarastScreenFrame(
      maxWidth: 640,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AarastV3Space.x4,
              AarastV3Space.x2,
              AarastV3Space.x2,
              0,
            ),
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
              color: context.accent.primary,
              onRefresh: marketplace.loadScopedQuoteRequests,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AarastV3Density.pageInsets,
                children: [
                  // D87 (RA-MO-260): the offers compared here may be an
                  // old copy; the person is told before choosing.
                  if (quotes.isNotEmpty && marketplace.quoteRequestsStale) ...[
                    JourneyListNotice(offline: true, onRetry: _load),
                    const SizedBox(height: AarastV3Space.x2),
                  ],
                  if (row == null || quotes.isEmpty)
                    if (_loading)
                      const JourneyListState(
                        phase: JourneyListPhase.loading,
                        section: JourneySection.providers,
                      )
                    else if (marketplace.quoteRequestsErrorMessage != null ||
                        context.watch<FinanceProvider?>()?.loadErrorMessage !=
                            null)
                      JourneyListState(
                        phase: JourneyListPhase.error,
                        section: JourneySection.providers,
                        onRetry: _load,
                      )
                    else
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
                      onChoose: accepted.isEmpty && _mayChoose ? _choose : null,
                      amountHidden: !_seesMoney,
                      onDecline: _decline,
                      onChat: _openChat,
                    ),
                    if (accepted.isEmpty) ...[
                      const SizedBox(height: AarastV3Space.x3),
                      if (_mayChoose)
                        JourneyNote(
                          key: const ValueKey('requests-choose-note'),
                          text: context.say(
                            'لما تختار، يصير بند في المال، ونطلب منهم حجز يوم عرسك.',
                            'لما تختارين، يصير بند في المال، ونطلب منهم حجز يوم عرسك.',
                          ),
                          icon: LucideIcons.wallet,
                        )
                      else
                        const JourneyNote(
                          key: ValueKey('requests-choose-by-money'),
                          text:
                              'اختيار العرض يصير بند في المال، فهو عند اللي يدير مال الخطة.',
                          icon: LucideIcons.lock,
                        ),
                    ],
                  ],
                  for (final quote in accepted) ...[
                    const SizedBox(height: AarastV3Space.x3),
                    _ChosenCard(
                      quote: quote,
                      busy: marketplace.isSubmitting,
                      onBook: () => _book(quote),
                      onCancelBooking: () => _cancelBooking(quote),
                      onChangeDay: () => _changeDay(quote),
                      onConfirmDelivery: () => _confirmDelivery(quote),
                      onViewCost: () => _viewCost(quote),
                      onRate: () => context.push(
                        AppRouter.planReviews(
                          widget.weddingPlanId,
                          providerId: quote.providerId,
                        ),
                      ),
                      onChat: () => _openChat(quote),
                    ),
                  ],
                  for (final quote in expired) ...[
                    const SizedBox(height: AarastV3Space.x3),
                    _ExpiredCard(
                      quote: quote,
                      onAskAgain: () => context.push(
                        AppRouter.providerQuote(quote.providerId),
                      ),
                    ),
                  ],
                  if (waiting.isNotEmpty) ...[
                    const SizedBox(height: AarastV3Space.x1),
                    const JourneySectionTitle('ينتظرون ردهم'),
                    JourneyBox(
                      padding: EdgeInsets.zero,
                      child: JourneyList(
                        children: [
                          for (final quote in waiting)
                            JourneyListRow(
                              key: ValueKey('requests-waiting-${quote.id}'),
                              icon: LucideIcons.hourglass,
                              color: context.accent.primary,
                              soft: context.accent.primarySoft,
                              title: quoteProviderName(quote),
                              subtitle: quote.createdAt == null
                                  ? 'ينتظر الرد'
                                  : '${context.say('طلبت', 'طلبتِ')} ${formatArabicDayMonth(quote.createdAt!)} · ينتظر الرد',
                              onTap: () => _openChat(quote),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (earlier.isNotEmpty) ...[
                    const SizedBox(height: AarastV3Space.x1),
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
                              subtitle: switch (quote.lifecycleStatus) {
                                // Who said no: an offer he rejected, or
                                // their apology (as the chat says it).
                                'REJECTED' when quote.rejectedByCustomer =>
                                  context.say(
                                    'اعتذرت عن عرضهم',
                                    'اعتذرتِ عن عرضهم',
                                  ),
                                'REJECTED' => 'اعتذروا عن الطلب',
                                // B-04.
                                'EXPIRED' => 'ما ردوا خلال 7 أيام',
                                _ => 'انلغى الطلب',
                              },
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
    AarastToast.showSuccess(
      context,
      '${context.say('اخترت', 'اخترتِ')} ${quoteProviderName(quote)}، وصار بند في المال.',
    );
    await _book(_fresh(quote));
  }

  Future<void> _book(QuoteRequest quote) async {
    if (!_ownQuote(quote)) return;
    final summary = context.read<DashboardSummaryProvider?>()?.summary;
    final mine = summary?.planId == widget.weddingPlanId ? summary : null;
    final place =
        mine?.location?['fullLabel']?.toString().trim() ?? mine?.city?.trim();
    final day = await showJourneySheet<DateTime>(
      context: context,
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
        marketplace.errorMessage ??
            context.say(
              'ما وصل طلب الحجز. جرّب مرة ثانية.',
              'ما وصل طلب الحجز. جرّبي مرة ثانية.',
            ),
      );
    }
  }

  /// x10: the polite message goes first; the offer is declined only once it
  /// arrived, so the provider never sees a silent «رفض».
  Future<void> _decline(QuoteRequest quote) async {
    if (!_ownQuote(quote)) return;
    final chat = context.read<ChatApi>();
    final marketplace = context.read<ProviderMarketplaceProvider>();
    final failedToSend = context.say(
      'ما وصلت رسالتك. جرّب مرة ثانية.',
      'ما وصلت رسالتك. جرّبي مرة ثانية.',
    );
    // Once the message arrived, a retry only records the decline: the
    // provider never gets the polite message twice.
    var messageArrived = false;
    final choice = await showJourneySheet<DeclineOfferChoice>(
      context: context,
      builder: (_) => DeclineOfferSheet(
        quote: quote,
        onSend: (choice) async {
          if (!messageArrived) {
            try {
              final conversation = await chat.conversationForQuote(quote.id);
              await chat.send(conversation.id, body: choice.message);
              messageArrived = true;
            } catch (_) {
              return failedToSend;
            }
          }
          final ok = await marketplace.rejectQuote(
            quote,
            reason: choice.reason,
          );
          return ok
              ? null
              : (marketplace.errorMessage ??
                    'وصلت رسالتك، بس ما قدرنا نسجّل الاعتذار.');
        },
      ),
    );
    if (choice == null || !mounted) return;
    AarastToast.showSuccess(
      context,
      context.say(
        'وصلتهم رسالتك واعتذرت عن العرض.',
        'وصلتهم رسالتك واعتذرتِ عن العرض.',
      ),
    );
  }

  /// B-24: asks the provider to move the booking; it keeps its day until
  /// they take the new one.
  Future<void> _changeDay(QuoteRequest quote) async {
    if (!_ownQuote(quote)) return;
    final booking = quote.booking;
    if (booking == null) return;
    final today = DateUtils.dateOnly(appNow());
    final day = await showDatePicker(
      context: context,
      initialDate: booking.eventDate.isBefore(today)
          ? today
          : booking.eventDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 730)),
    );
    if (day == null || !mounted) return;
    final marketplace = context.read<ProviderMarketplaceProvider>();
    final ok = await marketplace.requestBookingChange(quote, day);
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(
        context,
        'وصلهم طلبك يوم ${formatArabicDayMonth(day)}. الحجز باقي لين يردون.',
      );
    } else {
      AarastToast.showError(
        context,
        marketplace.errorMessage ?? 'ما وصل طلبك. جرّب مرة ثانية.',
      );
    }
  }

  /// B-23: the customer confirms the provider's delivery.
  Future<void> _confirmDelivery(QuoteRequest quote) async {
    if (!_ownQuote(quote)) return;
    final marketplace = context.read<ProviderMarketplaceProvider>();
    final ok = await marketplace.confirmBookingDelivery(quote);
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(
        context,
        'انسجّل إنك استلمت. ما يبقى إلا تقييمهم.',
      );
    } else {
      AarastToast.showError(
        context,
        marketplace.errorMessage ?? 'ما قدرنا نسجّل. جرّب مرة ثانية.',
      );
    }
  }

  /// x11: the provider is told; the cost stays in the money tab for the
  /// groom to settle with them.
  Future<void> _cancelBooking(QuoteRequest quote) async {
    if (!_ownQuote(quote)) return;
    final confirmed = await showJourneySheet<bool>(
      context: context,
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
