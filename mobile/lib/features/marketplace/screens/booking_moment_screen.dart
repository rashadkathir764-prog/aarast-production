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

  @override
  Widget build(BuildContext context) {
    final quote = context
        .watch<ProviderMarketplaceProvider>()
        .quotesForPlan(widget.weddingPlanId)
        .where((quote) => quote.id == widget.quoteId)
        .firstOrNull;
    final booking = quote?.booking;
    if (quote == null || booking == null) {
      return _framed(
        JourneyMoment(
          color: AarastV3Color.cobalt,
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
    final price = providerMoneyLabel(offer?.amount, offer?.currency);
    final scheduleAmount = schedule == null
        ? null
        : providerMoneyLabel(schedule.amount, offer?.currency);
    final scheduleName = schedule?.note?.trim().isNotEmpty == true
        ? schedule!.note!.trim()
        : 'العربون';
    final name = quote.provider?.businessName ?? service ?? '';

    final (String action, VoidCallback onAction) = schedule != null
        ? (
            'سجّل $scheduleName',
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
            'سجّل العربون',
            () => _go(
              AppRouter.moneyPaymentCreate(widget.weddingPlanId, cost.id),
            ),
          )
        : ('تمام', _close);

    return _framed(
      JourneyMoment(
        color: AarastV3Color.cobalt,
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
    backgroundColor: AarastV3Color.cobalt,
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
