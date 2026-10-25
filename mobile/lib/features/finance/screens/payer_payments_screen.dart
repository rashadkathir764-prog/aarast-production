import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController, AccountContextRole;
import '../models/money_summary.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';

/// w20 «الدفعات · مين دفع ايش» (G14): who paid what. The server sums each
/// payer's agreements and payments (`money-summary` `payers`); a payment is
/// filed under its item's payer («الوالد», «خالي أحمد»), which is how the
/// plan records who pays: a payment itself names no payer.
class PayerPaymentsScreen extends StatefulWidget {
  const PayerPaymentsScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<PayerPaymentsScreen> createState() => _PayerPaymentsScreenState();
}

class _PayerPaymentsScreenState extends State<PayerPaymentsScreen> {
  /// The chosen payer's key, or null for «الكل».
  String? _chosen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final finance = context.read<FinanceProvider>();
      if (finance.loadedPlanId != widget.weddingPlanId) {
        finance.loadMoney(widget.weddingPlanId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider>();
    final loaded = finance.loadedPlanId == widget.weddingPlanId;
    final summary = finance.summary;
    final currency = summary.currency;
    final selected = context
        .watch<AccountContextController?>()
        ?.selectedContext;
    final owner =
        selected?.weddingPlanId == widget.weddingPlanId &&
        selected?.role == AccountContextRole.owner;
    final profile = context.journeyProfile;
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
    String amount(Object? value) =>
        compactMoneyParts(moneyValue(value), currencyCode: currency).plainText;

    return AarastScreenFrame(
      maxWidth: 560,
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        key: const ValueKey('payer-payments'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          JourneySubHeader(
            title: 'الدفعات',
            subtitle: 'مين دفع ايش',
            onBack: () =>
                context.popOrGo(AppRouter.money(widget.weddingPlanId)),
          ),
          const SizedBox(height: 12),
          if (!loaded)
            const JourneyListState(
              phase: JourneyListPhase.loading,
              section: JourneySection.money,
            )
          else ...[
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
            const SizedBox(height: 14),
            JourneyBox(
              key: const ValueKey('payer-total'),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  JourneyAvatar(
                    letter: chosen == null
                        ? 'ك'
                        : label(chosen).characters.first,
                    color: context.accent.primary,
                    size: 40,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      chosen == null
                          ? 'اللي انحسب دفعه'
                          : label(chosen) == 'أنا'
                          ? context.say('دفعت أنا', 'دفعتِ أنا')
                          : '${label(chosen)} دفع',
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
            const SizedBox(height: 12),
            if (payments.isEmpty)
              const JourneyListState(
                phase: JourneyListPhase.empty,
                section: JourneySection.money,
                emptyIcon: LucideIcons.receipt,
                emptyTitle: 'ما فيه دفعات بعد',
              )
            else
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
                          if (finance.costById(payment.costId) case final cost?)
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
          ],
        ],
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

/// One payer group's key: its payer and the name written with it.
String payerKey(String? payer, String? payerName) =>
    '${payer ?? ''}|${payerName?.trim() ?? ''}';

/// The payer as the plan's owner says it: «أنا» for the plan's own party,
/// the other party by their word, the family or someone else by the name
/// written with it.
String payerLabel(
  String? payer,
  String? payerName, {
  required bool bridePlan,
  required bool owner,
}) {
  final name = payerName?.trim();
  return switch (payer) {
    'GROOM' => owner && !bridePlan ? 'أنا' : 'العريس',
    'BRIDE' => owner && bridePlan ? 'أنا' : 'العروسة',
    'FAMILY' => name == null || name.isEmpty ? 'الأهل' : name,
    'SHARED' => 'مشترك',
    'OTHER' => name == null || name.isEmpty ? 'غيره' : name,
    _ => 'ما تحدد',
  };
}
