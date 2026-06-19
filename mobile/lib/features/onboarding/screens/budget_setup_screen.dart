import 'package:flutter/material.dart';

import '../models/guest_onboarding_draft.dart';
import '../widgets/guest_onboarding_step_scaffold.dart';

class BudgetSetupScreen extends StatefulWidget {
  const BudgetSetupScreen({
    this.draft = const GuestOnboardingDraft.empty(),
    this.onSaveBudget,
    this.onBack,
    super.key,
  });

  final GuestOnboardingDraft draft;
  final Future<void> Function({String? currency, String? estimatedBudget})?
  onSaveBudget;
  final VoidCallback? onBack;

  @override
  State<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends State<BudgetSetupScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _currencyController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.draft.estimatedBudget,
    );
    _currencyController = TextEditingController(
      text: widget.draft.currency ?? 'YER',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GuestOnboardingStepScaffold(
      title: 'ميزانية تقريبية',
      description: 'أدخل مبلغًا تقديريًا أو تخط هذه الخطوة الآن.',
      continueLabel: 'حفظ الميزانية',
      onContinue: () => widget.onSaveBudget?.call(
        currency: _currencyController.text,
        estimatedBudget: _amountController.text,
      ),
      onBack: widget.onBack,
      child: Column(
        children: [
          TextField(
            controller: _amountController,
            textAlign: TextAlign.right,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'المبلغ التقديري'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _currencyController,
            textAlign: TextAlign.right,
            decoration: const InputDecoration(
              labelText: 'العملة',
              hintText: 'YER',
            ),
          ),
          const SizedBox(height: 12),
          GuestOnboardingOptionTile(
            title: 'تخطي الآن',
            subtitle: 'يمكن إضافة الميزانية من شاشة المال لاحقًا.',
            icon: Icons.skip_next_rounded,
            selected: widget.draft.estimatedBudget == null,
            onTap: () => widget.onSaveBudget?.call(),
          ),
        ],
      ),
    );
  }
}
