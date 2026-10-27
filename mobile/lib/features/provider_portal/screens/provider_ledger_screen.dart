import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_request_parts.dart' show providerMoneyLabel;

/// p47 «حساباتك» (B-18, D41): a month of his confirmed bookings and what
/// their customers recorded in their money: «وصلك» (paid) and «باقي لك»
/// (left), each currency on its own line, then each booking with what is
/// left on it. Read only: the customer records every payment and the app
/// moves no money, so there is no «ذكّره», no deposit and no confirmation.
class ProviderLedgerScreen extends StatefulWidget {
  const ProviderLedgerScreen({this.now, super.key});

  /// The clock the month starts from (tests).
  final DateTime? now;

  @override
  State<ProviderLedgerScreen> createState() => _ProviderLedgerScreenState();
}

class _ProviderLedgerScreenState extends State<ProviderLedgerScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = widget.now ?? DateTime.now();
    _month = DateTime(now.year, now.month);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    await context.read<ProviderDashboardProvider>().loadLedger(_month);
  }

  void _move(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final ledger = dashboard.ledgerOf(_month);
    final error = dashboard.ledgerError;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            JourneySubHeader(
              title: 'حساباتك',
              subtitle: '${arabicMonthName(_month.month)} ${_month.year} · من حجوزاتك المؤكدة',
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  key: const Key('provider-ledger-previous'),
                  tooltip: 'الشهر اللي قبل',
                  icon: const Icon(LucideIcons.chevronRight),
                  onPressed: () => _move(-1),
                ),
                IconButton(
                  key: const Key('provider-ledger-next'),
                  tooltip: 'الشهر اللي بعد',
                  icon: const Icon(LucideIcons.chevronLeft),
                  onPressed: () => _move(1),
                ),
              ],
            ),
            if (ledger == null && error == null)
              const AarastLoadingState(rows: 2)
            else if (ledger == null)
              JourneyNote(
                key: const Key('provider-ledger-error'),
                text: error!,
                icon: LucideIcons.wifiOff,
              )
            else if (ledger.bookings.isEmpty)
              JourneyBox(
                key: const Key('provider-ledger-empty'),
                child: Text(
                  'ما عندك حجز مؤكد في هذا الشهر.',
                  style: JourneyType.of(JourneyType.body),
                ),
              )
            else ...[
              for (final total in ledger.totals) ...[
                JourneyBox(
                  key: Key('provider-ledger-total-${total.currency}'),
                  color: AarastV3Color.primary,
                  child: Row(
                    children: [
                      Expanded(
                        child: _Figure(
                          label: 'وصلك',
                          value: providerMoneyLabel(total.paid, total.currency),
                          color: AarastV3Color.onPrimary,
                        ),
                      ),
                      Expanded(
                        child: _Figure(
                          label: 'باقي لك',
                          value: providerMoneyLabel(total.left, total.currency),
                          color: AarastV3Color.brandAccentSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (ledger.totals.length > 1)
                Text(
                  'كل عملة لحالها.',
                  style: JourneyType.of(
                    JourneyType.caption,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              const SizedBox(height: 8),
              const JourneySectionTitle('حجوزات الشهر'),
              JourneyList(
                children: [
                  for (final booking in ledger.bookings)
                    JourneyListRow(
                      key: Key('provider-ledger-booking-${booking.bookingId}'),
                      icon: LucideIcons.calendarCheck,
                      color: AarastV3Color.primary,
                      soft: AarastV3Color.primarySoft,
                      title: booking.customerName ?? 'حجز',
                      subtitle: [
                        formatArabicWeekdayDayMonth(booking.eventDate),
                        if (booking.money case final money?)
                          'الباقي ${providerMoneyLabel(money.left, money.currency)}'
                        else
                          'ما سجّل اتفاق',
                      ].join(' · '),
                      onTap: () => context.push(
                        AppRouter.providerRequest(booking.quoteRequestId),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            const JourneyNote(
              key: Key('provider-ledger-note'),
              text:
                  'هذا اللي سجّله العرسان في حساباتهم. التطبيق ما يستلم ولا يحوّل فلوس.',
              icon: LucideIcons.bookOpen,
            ),
          ],
        ),
      ),
    );
  }

}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: JourneyType.of(JourneyType.small, color: AarastV3Color.onPrimary),
      ),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          value,
          style: JourneyType.of(
            JourneyType.title,
            weight: JourneyType.bold,
            color: color,
          ),
        ),
      ),
    ],
  );
}
