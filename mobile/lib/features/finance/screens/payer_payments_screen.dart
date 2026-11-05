import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/money_payer_words.dart';
import '../models/money_summary.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';

export '../models/money_payer_words.dart' show payerKey, payerLabel;

/// w20 «الدفعات · مين دفع ايش» (G14): who paid what. The server sums each
/// payer's agreements and payments (`money-summary` `payers`); a payment is
/// filed under its item's payer («الوالد», «خالي أحمد»), which is how the
/// plan records who pays: a payment itself names no payer.
///
/// D86: the list under the server's total is every payment of the plan,
/// not the first page; while the rest is still coming the screen says so,
/// and a read that failed offers to read again instead of «ما فيه دفعات».
class PayerPaymentsScreen extends StatefulWidget {
  const PayerPaymentsScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<PayerPaymentsScreen> createState() => _PayerPaymentsScreenState();
}

class _PayerPaymentsScreenState extends State<PayerPaymentsScreen> {
  /// The chosen payer's key, or null for «الكل».
  String? _chosen;

  /// The remaining pages are still being read.
  bool _readingRest = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final finance = context.read<FinanceProvider>();
    if (finance.loadedPlanId != widget.weddingPlanId || finance.isStale) {
      await finance.loadMoney(widget.weddingPlanId);
    }
    if (!mounted || finance.loadedPlanId != widget.weddingPlanId) return;
    setState(() => _readingRest = true);
    try {
      await finance.loadAllCostsAndPayments();
    } finally {
      if (mounted) setState(() => _readingRest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final loaded = finance.loadedPlanId == widget.weddingPlanId;
    final failed = loaded && finance.errorMessage != null && !finance.isLoading;
    final summary = finance.summary;
    final currency = summary.currency;
    final profile = context.journeyProfile;
    // D59: «أنا» only for the plan's owner; anyone else reads the parties.
    final owner = profile.readerIsOwner;
    String label(MoneyPayerSummary group) => payerLabel(
      group.payer,
      group.payerName,
      bridePlan: profile.isBride,
      owner: owner,
    );
    final groups = [
      for (final group in summary.payers)
        if (moneyValue(group.paid) > 0 || group.costsCount > 0) group,
    ];
    final chosen = groups
        .where((group) => payerKey(group.payer, group.payerName) == _chosen)
        .firstOrNull;
    final payments = [
      for (final payment in finance.payments)
        if (payment.entryType == 'PAYMENT' && payment.reversedById == null)
          if (_matches(finance.costById(payment.costId), chosen)) payment,
    ]..sort((a, b) => b.paidAt.compareTo(a.paidAt));
    final paid = chosen?.paid ?? summary.costs.paid;
    // G17: «أخفِ المبالغ» hides these figures as on every money screen.
    String amount(Object? value) => finance.shownAmount(
      compactMoneyParts(moneyValue(value), currencyCode: currency).plainText,
    );
    final stillComing =
        _readingRest ||
        finance.isLoadingMoreCosts ||
        finance.isLoadingMorePayments;

    return AarastScreenFrame(
      maxWidth: 560,
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          key: const ValueKey('payer-payments'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AarastV3Density.pageInsets,
          children: [
            JourneySubHeader(
              title: 'الدفعات',
              subtitle: 'مين دفع ايش',
              onBack: () =>
                  context.popOrGo(AppRouter.money(widget.weddingPlanId)),
            ),
            const SizedBox(height: AarastV3Space.x3),
            if (failed)
              JourneyListState(
                key: const ValueKey('payer-error'),
                phase: JourneyListPhase.error,
                section: JourneySection.money,
                onRetry: _load,
              )
            else if (!loaded || (finance.isLoading && !finance.hasLoadedMoney))
              const JourneyListState(
                phase: JourneyListPhase.loading,
                section: JourneySection.money,
              )
            else ...[
              if (finance.isStale) ...[
                JourneyListNotice(offline: true, onRetry: _load),
                const SizedBox(height: AarastV3Space.x3),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  JourneyChip(
                    key: const ValueKey('payer-all'),
                    label: 'الكل',
                    selected: chosen == null,
                    onTap: () => setState(() => _chosen = null),
                  ),
                  for (final group in groups)
                    JourneyChip(
                      key: ValueKey(
                        'payer-${payerKey(group.payer, group.payerName)}',
                      ),
                      label: label(group),
                      selected: chosen == group,
                      onTap: () => setState(
                        () => _chosen = payerKey(group.payer, group.payerName),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AarastV3Space.x3),
              JourneyBox(
                key: const ValueKey('payer-total'),
                padding: const EdgeInsets.all(AarastV3Space.x4),
                child: Row(
                  children: [
                    JourneyAvatar(
                      letter: chosen == null
                          ? 'ك'
                          : payerAvatarLetter(label(chosen)),
                      color: context.accent.primary,
                      size: 40,
                    ),
                    const SizedBox(width: AarastV3Space.x3),
                    Expanded(
                      child: Text(
                        chosen == null
                            ? 'اللي انحسب دفعه'
                            : payerPaidLine(
                                chosen.payer,
                                label(chosen),
                                profile,
                              ),
                        style: JourneyType.of(
                          JourneyType.bodyLarge,
                          weight: JourneyType.bold,
                        ),
                      ),
                    ),
                    Text(
                      amount(paid),
                      style: JourneyType.of(
                        JourneyType.title,
                        weight: JourneyType.bold,
                        color: context.accent.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AarastV3Space.x3),
              if (payments.isEmpty && stillComing)
                const JourneyListState(
                  key: ValueKey('payer-list-loading'),
                  phase: JourneyListPhase.loading,
                  section: JourneySection.money,
                )
              else if (payments.isEmpty)
                const JourneyListState(
                  phase: JourneyListPhase.empty,
                  section: JourneySection.money,
                  emptyIcon: LucideIcons.receipt,
                  emptyTitle: 'ما فيه دفعات بعد',
                )
              else ...[
                JourneyBox(
                  padding: EdgeInsets.zero,
                  child: JourneyList(
                    children: [
                      for (final payment in payments)
                        JourneyListRow(
                          key: ValueKey('payer-payment-${payment.id}'),
                          icon: LucideIcons.receipt,
                          color: context.accent.primary,
                          soft: context.accent.primarySoft,
                          title:
                              payment.providerName ??
                              payment.costTitle ??
                              finance.costById(payment.costId)?.title ??
                              'دفعة',
                          subtitle: [
                            if (payment.note?.trim().isNotEmpty == true)
                              payment.note!.trim(),
                            formatArabicDayMonth(payment.paidAt),
                            if (finance.costById(payment.costId)
                                case final cost?)
                              payerLabel(
                                cost.payer,
                                cost.payerName,
                                bridePlan: profile.isBride,
                                owner: owner,
                              ),
                          ].join(' · '),
                          trailing: Text(
                            amount(payment.amount),
                            style: JourneyType.of(
                              JourneyType.bodyLarge,
                              weight: JourneyType.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (stillComing) ...[
                  const SizedBox(height: AarastV3Space.x3),
                  const JourneyNote(
                    key: ValueKey('payer-list-more'),
                    text: 'باقي الدفعات جاية.',
                    icon: LucideIcons.loader,
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  bool _matches(WeddingCost? cost, MoneyPayerSummary? chosen) {
    if (chosen == null) return true;
    if (cost == null) return false;
    return payerKey(cost.payer, cost.payerName) ==
        payerKey(chosen.payer, chosen.payerName);
  }
}
