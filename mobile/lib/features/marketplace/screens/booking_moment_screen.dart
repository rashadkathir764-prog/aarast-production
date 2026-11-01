import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../finance/finance_api.dart' show FinanceProvider;
import '../providers/marketplace_provider.dart';
import '../widgets/provider_board_view.dart' show providerServiceIcon;
import '../widgets/provider_details_view.dart' show providerMoneyLabel;

/// y09: the provider confirmed the booking. Shown once per phone when the
/// providers tab first sees the confirmation. «صار محجوز 4 من 6» is left
/// out: the plan keeps no list of the providers it needs (C25).
class BookingMomentScreen extends StatefulWidget {
  const BookingMomentScreen({
    required this.weddingPlanId,
    required this.quoteId,
    super.key,
  });

  final String weddingPlanId;
  final String quoteId;

  @override
  State<BookingMomentScreen> createState() => _BookingMomentScreenState();
}

class _BookingMomentScreenState extends State<BookingMomentScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// A notification can open this first, so it reads the plan itself; the
  /// route's gate has checked this account.
  Future<void> _load() async {
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final quote = context
        .watch<ProviderMarketplaceProvider>()
        .quotesForPlan(widget.weddingPlanId)
        .where((quote) => quote.id == widget.quoteId)
        .firstOrNull;
    final booking = quote?.booking;
    if (quote == null || booking == null) {
      if (_loading) {
        return _framed(
          const JourneyListState(
            phase: JourneyListPhase.loading,
            section: JourneySection.providers,
          ),
        );
      }
      return _framed(
        JourneyMoment(
          color: context.accent.primary,
          eyebrow: 'طلب الحجز انقبل',
          title: 'ليلتك محجوزة',
          subtitle: '',
          body: const SizedBox.shrink(),
          action: 'تمام',
          onAction: _close,
        ),
      );
    }

    final finance = context.watch<FinanceProvider?>();
    final money = finance?.loadedPlanId == widget.weddingPlanId
        ? finance
        : null;
    final offerId = booking.quoteOfferId ?? quote.acceptedOffer?.id;
    final cost = money?.costs
        .where((cost) => offerId != null && cost.quoteOfferId == offerId)
        .firstOrNull;
    final schedule = cost == null
        ? null
        : (money!.dueSchedules
                  .where((item) => item.costId == cost.id && item.isPending)
                  .toList()
                ..sort((a, b) => a.dueDate.compareTo(b.dueDate)))
              .firstOrNull;

    final service = quote.service?.category?.nameAr ?? quote.service?.title;
    final offer = quote.acceptedOffer;
    String? shown(String? amount) {
      final label = providerMoneyLabel(amount, offer?.currency);
      if (label == null) return null;
      return finance?.shownAmount(label) ?? label;
    }

    final price = shown(offer?.amount);
    final scheduleAmount = schedule == null ? null : shown(schedule.amount);
    final scheduleName = schedule?.note?.trim().isNotEmpty == true
        ? schedule!.note!.trim()
        : 'العربون';
    final name = quote.provider?.businessName ?? service ?? '';

    final (String action, VoidCallback onAction) = schedule != null
        ? (
            '${context.say('سجّل', 'سجّلي')} $scheduleName',
            () => _go(
              AppRouter.moneySchedulePay(
                widget.weddingPlanId,
                cost!.id,
                schedule.id,
              ),
            ),
          )
        : cost != null
        ? (
            context.say('سجّل العربون', 'سجّلي العربون'),
            () => _go(
              AppRouter.moneyPaymentCreate(widget.weddingPlanId, cost.id),
            ),
          )
        : ('تمام', _close);

    return _framed(
      JourneyMoment(
        color: context.accent.primary,
        eyebrow: 'طلب الحجز انقبل',
        title: 'ليلتك محجوزة\nعند $name',
        subtitle: [
          formatArabicWeekdayDayMonth(booking.eventDate),
          ?_period(quote.message),
        ].join(' · '),
        body: JourneyGlassRows(
          rows: [
            if (service != null && price != null)
              (providerServiceIcon(service), service, price),
            if (schedule != null && scheduleAmount != null)
              (
                LucideIcons.calendarClock,
                scheduleName,
                '$scheduleAmount · ${formatArabicDayMonth(schedule.dueDate)}',
              ),
          ],
        ),
        action: action,
        onAction: onAction,
      ),
    );
  }

  Widget _framed(Widget moment) => AarastScreenFrame(
    maxWidth: 520,
    backgroundColor: context.accent.primary,
    child: moment,
  );

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouter.planProviders(widget.weddingPlanId));
    }
  }

  void _go(String location) => context.pushReplacement(location);
}

/// «بعد المغرب» from the request's «الفترة: الليل · بعد المغرب» (f07).
String? _period(String? message) {
  for (final line in (message ?? '').split('\n')) {
    final text = line.trim();
    if (text.startsWith('الفترة:')) {
      final period = text.substring('الفترة:'.length).trim();
      if (period.isEmpty) return null;
      return period.split(' · ').last;
    }
  }
  return null;
}
