import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_date_formatter.dart';
import '../../../../core/widgets/aarast_ui.dart';
import '../../models/financial_commitment.dart';
import '../../models/money_formatters.dart';
import '../../models/money_summary.dart';
import 'finance_overview_components.dart';

class FinancialPayablesSection extends StatelessWidget {
  const FinancialPayablesSection({
    required this.summary,
    required this.currencyCode,
    required this.commitments,
    required this.installments,
    required this.onOpenPayables,
    required this.onOpenCommitment,
    super.key,
  });

  final MoneySummary summary;
  final String currencyCode;
  final List<FinancialCommitment> commitments;
  final List<FinancialInstallment> installments;
  final VoidCallback onOpenPayables;
  final ValueChanged<String> onOpenCommitment;

  @override
  Widget build(BuildContext context) {
    final active = commitments
        .where((commitment) => !commitment.isCancelled)
        .toList();
    final openPayables =
        active
            .where((commitment) => _moneyValue(commitment.remainingAmount) > 0)
            .toList()
          ..sort(_compareCommitmentDueDate);
    final dueInstallments =
        installments.where((installment) => !installment.isPaid).toList()
          ..sort(_compareInstallmentDueDate);
    final totalRemaining = active.fold<num>(
      0,
      (sum, commitment) => sum + _moneyValue(commitment.remainingAmount),
    );
    final commitmentTitles = {
      for (final commitment in active) commitment.id: commitment.title,
    };
    final hasContent = openPayables.isNotEmpty || dueInstallments.isNotEmpty;
    final nextPayable = openPayables.firstOrNull;
    final nextInstallment = dueInstallments.firstOrNull;
    final showInstallment = _installmentComesFirst(
      nextInstallment,
      nextPayable,
    );
    final previewInstallment = showInstallment ? nextInstallment : null;

    return FinanceSectionCard(
      title: 'الدفعات والمستحقات',
      icon: LucideIcons.wallet,
      onTap: onOpenPayables,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PayablesSummaryRow(
            remaining: totalRemaining,
            currencyCode: currencyCode,
            payablesCount: openPayables.length,
            installmentsCount: dueInstallments.length,
          ),
          const SizedBox(height: 12),
          if (!hasContent)
            const FinanceTinyEmptyText(
              message: 'لا توجد مستحقات أو أقساط قريبة الآن.',
            )
          else ...[
            const _FinanceSubhead(label: 'القادم'),
            const SizedBox(height: 8),
            if (previewInstallment != null)
              FinanceTapInlineTile(
                onTap: () =>
                    onOpenCommitment(previewInstallment.financialCommitmentId),
                child: FinanceMoneyEventTile(
                  title:
                      commitmentTitles[previewInstallment
                          .financialCommitmentId] ??
                      'قسط مالي',
                  subtitle: previewInstallment.dueDate == null
                      ? 'بدون تاريخ'
                      : _shortDate(previewInstallment.dueDate!),
                  amount: previewInstallment.amount,
                  icon: LucideIcons.calendarCheck,
                  color: AppTheme.gold,
                  currencyCode: currencyCode,
                ),
              )
            else if (nextPayable != null)
              _CommitmentTile(
                commitment: nextPayable,
                currencyCode: currencyCode,
                onTap: () => onOpenCommitment(nextPayable.id),
              ),
          ],
        ],
      ),
    );
  }
}

class _PayablesSummaryRow extends StatelessWidget {
  const _PayablesSummaryRow({
    required this.remaining,
    required this.currencyCode,
    required this.payablesCount,
    required this.installmentsCount,
  });

  final num remaining;
  final String currencyCode;
  final int payablesCount;
  final int installmentsCount;

  @override
  Widget build(BuildContext context) {
    final summaryText = Text(
      payablesCount == 0 && installmentsCount == 0
          ? 'لا يوجد شيء مستحق عليك الآن'
          : '$payablesCount مستحق · $installmentsCount قسط قريب',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppTheme.ink,
        fontWeight: FontWeight.w900,
        fontSize: 13,
      ),
    );
    final remainingText = Text(
      'باقي ${formatCompactMoney(remaining, currencyCode: currencyCode)}',
      maxLines: 1,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        color: remaining <= 0 ? AppTheme.success : AppTheme.danger,
        fontWeight: FontWeight.w900,
        fontSize: 12.5,
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.ivory,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 320) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      LucideIcons.receipt,
                      color: AppTheme.burgundy,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: summaryText),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: remainingText,
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              const Icon(
                LucideIcons.receipt,
                color: AppTheme.burgundy,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: summaryText),
              const SizedBox(width: 8),
              remainingText,
            ],
          );
        },
      ),
    );
  }
}

class _FinanceSubhead extends StatelessWidget {
  const _FinanceSubhead({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppTheme.muted,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _CommitmentTile extends StatelessWidget {
  const _CommitmentTile({
    required this.commitment,
    required this.currencyCode,
    required this.onTap,
  });

  final FinancialCommitment commitment;
  final String currencyCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final remaining = _moneyValue(commitment.remainingAmount);
    final statusColor = switch (commitment.status) {
      'PAID' => AppTheme.success,
      'CANCELLED' => AppTheme.muted,
      _ => AppTheme.gold,
    };
    final sourceLabel = commitment.isProviderLinked
        ? 'مورد / خدمة'
        : commitment.isManualPayable
        ? 'مستحق عليك'
        : 'مستحق مالي';
    final party = commitment.partyName?.trim();
    final leading = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Icon(LucideIcons.landmark, color: statusColor),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          commitment.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.ink,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            AarastStatusPill(label: sourceLabel, color: statusColor),
            if (party != null && party.isNotEmpty)
              AarastStatusPill(
                label: party,
                color: AppTheme.muted,
                icon: LucideIcons.user,
              ),
          ],
        ),
      ],
    );
    final amounts = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatCompactMoney(
            _moneyValue(commitment.totalAmount),
            currencyCode: currencyCode,
          ),
          style: const TextStyle(
            color: AppTheme.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'باقي ${formatCompactMoney(remaining, currencyCode: currencyCode)}',
          style: TextStyle(
            color: remaining <= 0 ? AppTheme.success : AppTheme.danger,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    );

    return FinanceTapInlineTile(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 280) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(child: details),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: amounts,
                ),
              ],
            );
          }

          return Row(
            children: [
              leading,
              const SizedBox(width: 12),
              Expanded(child: details),
              const SizedBox(width: 10),
              amounts,
            ],
          );
        },
      ),
    );
  }
}

int _compareCommitmentDueDate(
  FinancialCommitment left,
  FinancialCommitment right,
) {
  return _compareOptionalDates(left.dueDate, right.dueDate);
}

int _compareInstallmentDueDate(
  FinancialInstallment left,
  FinancialInstallment right,
) {
  return _compareOptionalDates(left.dueDate, right.dueDate);
}

int _compareOptionalDates(DateTime? left, DateTime? right) {
  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return left.compareTo(right);
}

bool _installmentComesFirst(
  FinancialInstallment? installment,
  FinancialCommitment? commitment,
) {
  if (installment == null) return false;
  if (commitment == null) return true;
  return _compareOptionalDates(installment.dueDate, commitment.dueDate) < 0;
}

num _moneyValue(String value) =>
    num.tryParse(value.replaceAll(',', '').trim()) ?? 0;

String _shortDate(DateTime date) => formatArabicCompactDate(date);
