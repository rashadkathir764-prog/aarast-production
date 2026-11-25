import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/plan_day.dart';
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

  /// Offers whose polite message arrived (RA-MO-257): the sheet opened
  /// again only records the decline, never a second message.
  final _declineMessageArrived = <String>{};

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
        'بندك ${fullMoneyParts(allocated, currencyCode: finance?.summary.currency ?? 'YER').plainText}',
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

  /// RA-MO-248: choosing an offer leads to a money item (Q-55: written with
  /// the booking request), so the server asks for the money right for both;
  /// Q-65 (أ), D127, for the booking request too. The buttons were offered
  /// to everyone who manages the providers, and the server then refused.
  bool get _mayChoose => _knownMoney?.canManageMoney ?? true;

  /// The server sends no amount to a reader who does not see the money.
  bool get _seesMoney => _knownMoney?.canViewMoney ?? true;

  /// «مدفوع 100,000 ر.ي · باقي 450,000 ر.ي»: what the chosen offer's
  /// agreement in the money stands at, from that agreement itself; null
  /// while the money is not read, not seen, or the agreement is not found.
  String? _paidLine(QuoteRequest quote) {
    final money = _knownMoney;
    if (money == null || !money.canViewMoney) return null;
    final costId = quote.costSuggestion?.costId?.trim();
    final cost = costId == null || costId.isEmpty
        ? null
        : money.costById(costId);
    final paid = num.tryParse(cost?.paidAmount ?? '');
    final left = num.tryParse(cost?.remainingAmount ?? '');
    if (paid == null || left == null) return null;
    final currency = money.summary.currency;
    String shown(num value) => money.shownAmount(
      fullMoneyParts(value, currencyCode: currency).plainText,
    );
    if (left <= 0) return 'مدفوع كله';
    return [
      paid > 0 ? 'مدفوع ${shown(paid)}' : 'ما اندفع شي بعد',
      'باقي ${shown(left)}',
    ].join(' · ');
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
                          'ما في طلبات لهذي الخدمة الحين.',
                          style: JourneyType.of(
                            JourneyType.body,
                            color: AarastV3Color.textMuted,
                          ),
                        ),
                      ),
                  if (offers.isNotEmpty) ...[
                    // True of every offer, so said once above them, not in
                    // each card.
                    Text(
                      'يتفقون على الدفع معك مباشرة',
                      key: const ValueKey('requests-pay-directly'),
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                    const SizedBox(height: AarastV3Space.x2),
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
                            'لما تختار، نطلب منهم حجز يوم عرسك، ولما تطلب الحجز يدخل السعر مالك.',
                            'لما تختارين، نطلب منهم حجز يوم عرسك، ولما تطلبين الحجز يدخل السعر مالك.',
                          ),
                          icon: LucideIcons.wallet,
                        )
                      else
                        const JourneyNote(
                          key: ValueKey('requests-choose-by-money'),
                          text:
                              'اختيار العرض وطلب الحجز يضيفون اتفاق في المال، فهم عند اللي يدير مال الخطة.',
                          icon: LucideIcons.lock,
                        ),
                    ],
                  ],
                  for (final quote in accepted) ...[
                    const SizedBox(height: AarastV3Space.x3),
                    _ChosenCard(
                      quote: quote,
                      paidLine: _paidLine(quote),
                      mayBook: _mayChoose,
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

  /// «اختر هذا», then f05 asks for the booking. Q-55 (أ), D127: choosing
  /// writes nothing in the money; the offer's agreement goes in when the
  /// booking is asked for. Choosing takes the choice from every other offer
  /// of the service, so it asks first and says exactly that.
  Future<void> _choose(QuoteRequest quote) async {
    if (!_ownQuote(quote)) return;
    if (!await _confirmChoice(quote) || !mounted) return;
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
    AarastToast.showSuccess(
      context,
      '${context.say('اخترت', 'اخترتِ')} ${quoteProviderName(quote)}.',
    );
    await _book(_fresh(quote));
  }

  /// What choosing does, said before it is done: the price enters the money
  /// when the booking is asked for (Q-55), and the service's other offers
  /// lose their «اختر هذا» (only one agreement per service); they are not
  /// declined.
  Future<bool> _confirmChoice(QuoteRequest quote) async {
    final name = quoteProviderName(quote);
    // A reader who does not see the money gets no amount from the server.
    final amount = offerAmountLabel(quote.pendingOffer);
    final question = amount == null
        ? context.say('تختار $name؟', 'تختارين $name؟')
        : context.say('تختار $name بـ$amount؟', 'تختارين $name بـ$amount؟');
    final confirmed = await showJourneySheet<bool>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title: question,
        subtitle: context.say(
          'السعر يدخل مالك لما تطلب الحجز، وما تقدر تختار عرض ثاني لهذي الخدمة.',
          'السعر يدخل مالك لما تطلبين الحجز، وما تقدرين تختارين عرض ثاني لهذي الخدمة.',
        ),
        children: [
          JourneyButton(
            key: const ValueKey('requests-choose-confirm'),
            label: context.say('اختر $name', 'اختاري $name'),
            background: context.accent.primary,
            expand: true,
            large: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyButton.quiet(
            key: const ValueKey('requests-choose-back'),
            label: 'رجوع',
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    );
    return confirmed == true;
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
      // Q-55: the request put the offer's agreement in the money.
      await context.read<FinanceProvider?>()?.loadMoney(widget.weddingPlanId);
      if (!mounted) return;
      AarastToast.showSuccess(context, 'وصلهم طلب الحجز. نخبرك لما يأكّدون.');
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
    final offerId = quote.pendingOffer?.id;
    if (offerId == null) return;
    final chat = context.read<ChatApi>();
    final marketplace = context.read<ProviderMarketplaceProvider>();
    final failedToSend = context.say(
      'ما وصلت رسالتك. جرّب مرة ثانية.',
      'ما وصلت رسالتك. جرّبي مرة ثانية.',
    );
    // Once the message arrived, a retry only records the decline, even
    // from the sheet opened again: the provider never gets the polite
    // message twice. A lost answer is sent again under the same key, and
    // the server answers it with the first message (RA-MO-257).
    final choice = await showJourneySheet<DeclineOfferChoice>(
      context: context,
      builder: (_) => DeclineOfferSheet(
        quote: quote,
        onSend: (choice) async {
          if (!_declineMessageArrived.contains(offerId)) {
            try {
              final conversation = await chat.conversationForQuote(quote.id);
              await chat.send(
                conversation.id,
                body: choice.message,
                clientRequestId:
                    'decline-$offerId-${choice.message.hashCode.abs()}',
              );
              _declineMessageArrived.add(offerId);
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
      lastDate: addPlanDays(today, 730),
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
        marketplace.errorMessage ??
            context.say(
              'ما وصل طلبك. جرّب مرة ثانية.',
              'ما وصل طلبك. جرّبي مرة ثانية.',
            ),
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
        context.say(
          'انسجّل إنك استلمت. ما يبقى إلا تقييمهم.',
          'انسجّل إنك استلمتِ. ما يبقى إلا تقييمهم.',
        ),
      );
    } else {
      AarastToast.showError(
        context,
        marketplace.errorMessage ??
            context.say(
              'ما قدرنا نسجّل. جرّب مرة ثانية.',
              'ما قدرنا نسجّل. جرّبي مرة ثانية.',
            ),
      );
    }
  }

  /// x11: the provider is told. Q-56 (أ), D127: the same sheet asks what
  /// happens to the offer's agreement in the money: taken out (only while
  /// nothing was paid on it, the record of a payment stays) or kept.
  Future<void> _cancelBooking(QuoteRequest quote) async {
    if (!_ownQuote(quote)) return;
    final finance = context.read<FinanceProvider?>();
    final money =
        finance != null &&
            finance.loadedPlanId == widget.weddingPlanId &&
            !finance.isLoading
        ? finance
        : null;
    final costId = quote.costSuggestion?.costId?.trim() ?? '';
    final cost = costId.isEmpty ? null : money?.costById(costId);
    final agreement = cost == null || cost.isCancelled ? null : cost;
    final choice = await showJourneySheet<_AgreementAfterCancel>(
      context: context,
      builder: (sheetContext) => _CancelBookingSheet(
        quote: quote,
        agreement: agreement != null
            ? (agreement.canDelete
                  ? _AgreementState.removable
                  : _AgreementState.paid)
            // There is one, though this reader cannot read it.
            : costId.isNotEmpty && cost == null
            ? _AgreementState.unread
            : _AgreementState.none,
        managesMoney: money?.canManageMoney ?? false,
      ),
    );
    if (choice == null || !mounted) return;
    final marketplace = context.read<ProviderMarketplaceProvider>();
    final ok = await marketplace.cancelBooking(quote);
    if (!mounted) return;
    if (!ok) {
      AarastToast.showError(
        context,
        marketplace.errorMessage ?? 'ما قدرنا نلغي الحجز.',
      );
      return;
    }
    if (choice == _AgreementAfterCancel.remove &&
        agreement != null &&
        money != null) {
      final removed = await money.deleteCost(agreement);
      if (!mounted) return;
      if (!removed) {
        AarastToast.showError(
          context,
          'انلغى الحجز، بس الاتفاق باقي في المال: ${money.errorMessage ?? 'ما قدرنا نشيله.'}',
        );
        return;
      }
      AarastToast.showSuccess(
        context,
        'انلغى الحجز ووصلهم الخبر، وانشال الاتفاق من المال.',
      );
      return;
    }
    AarastToast.showSuccess(context, 'انلغى الحجز ووصلهم الخبر.');
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
