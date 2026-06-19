import 'package:flutter/material.dart';

class UserRebuildMoneyTab extends StatelessWidget {
  const UserRebuildMoneyTab({
    super.key,
    this.currentPlanId,
    this.canAccessFinance = true,
  });

  final String? currentPlanId;
  final bool canAccessFinance;

  static const noPlanMessage =
      'تبويب المال التجريبي — يحتاج خطة حالية قبل عرض الميزانية والمصروفات';

  static const noPermissionMessage =
      'صلاحية المال غير مفعلة في هذا العرض التجريبي';

  @override
  Widget build(BuildContext context) {
    final hasCurrentPlan = currentPlanId != null && currentPlanId!.isNotEmpty;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 44),
                const SizedBox(height: 12),
                const Text(
                  'المال',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'هدف تبويب المال هو جمع الميزانية والمصروفات والديون والأقساط في مكان واحد لاحقاً.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                _MoneyCapabilityGrid(),
                const SizedBox(height: 20),
                _MoneyStateNotice(
                  message: !hasCurrentPlan
                      ? noPlanMessage
                      : canAccessFinance
                      ? 'سيتم ربط تبويب المال بمصدر الخطة الحالي في مرحلة لاحقة.'
                      : noPermissionMessage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoneyCapabilityGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const labels = ['الميزانية', 'المصروفات', 'الديون', 'الأقساط'];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: labels.map((label) => _MoneyCapabilityChip(label)).toList(),
    );
  }
}

class _MoneyCapabilityChip extends StatelessWidget {
  const _MoneyCapabilityChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _MoneyStateNotice extends StatelessWidget {
  const _MoneyStateNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
