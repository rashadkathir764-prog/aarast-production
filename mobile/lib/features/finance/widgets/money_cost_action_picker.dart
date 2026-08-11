import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_bottom_sheet.dart';
import '../../../core/widgets/aarast_pressable.dart';
import '../models/wedding_cost.dart';
import 'money_widgets.dart';

enum MoneyCostActionIntent { payment, schedule }

class MoneyCostActionSelection {
  const MoneyCostActionSelection.cost(this.cost) : createCost = false;

  const MoneyCostActionSelection.createCost() : cost = null, createCost = true;

  final WeddingCost? cost;
  final bool createCost;
}

Future<MoneyCostActionSelection?> showMoneyCostActionPicker(
  BuildContext context, {
  required MoneyCostActionIntent intent,
  required List<WeddingCost> costs,
  required String currency,
}) {
  final eligible = costs
      .where(
        (cost) => !cost.isCancelled && moneyValue(cost.remainingAmount) > 0,
      )
      .toList(growable: false);

  return showAarastBottomSheet<MoneyCostActionSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: (sheetContext) => _MoneyCostActionPicker(
      intent: intent,
      costs: eligible,
      currency: currency,
    ),
  );
}

class _MoneyCostActionPicker extends StatelessWidget {
  const _MoneyCostActionPicker({
    required this.intent,
    required this.costs,
    required this.currency,
  });

  final MoneyCostActionIntent intent;
  final List<WeddingCost> costs;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final isPayment = intent == MoneyCostActionIntent.payment;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AarastBottomSheetHandle(),
            Text(
              isPayment ? 'لأي تكلفة ستسجّل الدفعة؟' : 'لأي تكلفة تضيف موعدًا؟',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isPayment
                  ? 'نعرض التكاليف التي ما زال عليها مبلغ غير مدفوع.'
                  : 'اختر التكلفة ثم حدّد المبلغ والموعد في خطوة قصيرة.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            if (costs.isEmpty)
              _NoEligibleCosts(intent: intent)
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.48,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: costs.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppTheme.borderStrong),
                  itemBuilder: (context, index) =>
                      _CostChoiceRow(cost: costs[index], currency: currency),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CostChoiceRow extends StatelessWidget {
  const _CostChoiceRow({required this.cost, required this.currency});

  final WeddingCost cost;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: () =>
          Navigator.of(context).pop(MoneyCostActionSelection.cost(cost)),
      semanticLabel: 'اختيار ${cost.title}',
      borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 68),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.brandMuted,
                borderRadius: BorderRadius.circular(AppTheme.radiusControl),
              ),
              child: const Icon(
                LucideIcons.receipt,
                size: 19,
                color: AppTheme.brand,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cost.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'غير مدفوع',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: MoneyAmountText(
                          amount: moneyValue(cost.remainingAmount),
                          currency: currency,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.chevronLeft,
              size: 20,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoEligibleCosts extends StatelessWidget {
  const _NoEligibleCosts({required this.intent});

  final MoneyCostActionIntent intent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.borderStrong),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.receipt, color: AppTheme.brand, size: 26),
          const SizedBox(height: 8),
          Text(
            'أضف تكلفة أولًا',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            intent == MoneyCostActionIntent.payment
                ? 'الدفعة ترتبط بتكلفة حتى تبقى أرقامك دقيقة.'
                : 'موعد الدفع يرتبط بتكلفة ومبلغ واضحين.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(
                context,
              ).pop(const MoneyCostActionSelection.createCost()),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('إضافة تكلفة'),
            ),
          ),
        ],
      ),
    );
  }
}
