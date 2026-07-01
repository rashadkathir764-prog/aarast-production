import 'package:flutter/material.dart';

import '../models/guest_onboarding_draft.dart';
import '../models/persona_copy.dart';
import '../widgets/guest_onboarding_step_scaffold.dart';

class BudgetSetupScreen extends StatefulWidget {
  const BudgetSetupScreen({
    this.draft = const GuestOnboardingDraft.empty(),
    this.onSaveBudget,
    this.onBack,
    super.key,
  });

  final GuestOnboardingDraft draft;
  final Future<void> Function({
    String? currency,
    String? estimatedBudget,
    bool skipped,
  })?
  onSaveBudget;
  final VoidCallback? onBack;

  @override
  State<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends State<BudgetSetupScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _currencyController;
  late bool _skipBudget;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.draft.estimatedBudget,
    );
    _currencyController = TextEditingController(
      text: widget.draft.currency ?? 'YER',
    );
    _skipBudget = widget.draft.budgetSkipped;
    _amountController.addListener(_handleFieldChanged);
    _currencyController.addListener(_handleFieldChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_handleFieldChanged);
    _currencyController.removeListener(_handleFieldChanged);
    _amountController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  void _handleFieldChanged() {
    if (_skipBudget && _amountController.text.trim().isNotEmpty) {
      setState(() {
        _skipBudget = false;
      });
      return;
    }
    setState(() {});
  }

  bool get _canContinue {
    return _skipBudget || _amountController.text.trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final copy = personaCopyForGuest(widget.draft.persona);

    return GuestOnboardingStepScaffold(
      stepNumber: 6,
      title: 'ميزانية تقريبية',
      description: copy.budgetDescription,
      continueLabel: 'حفظ الميزانية',
      onContinue: _canContinue
          ? () => widget.onSaveBudget?.call(
              currency: _skipBudget ? null : _currencyController.text,
              estimatedBudget: _skipBudget ? null : _amountController.text,
              skipped: _skipBudget,
            )
          : null,
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
            key: const Key('guest-budget-skip'),
            title: 'تخطي الآن',
            subtitle: 'يمكن إضافة الميزانية من شاشة المال لاحقًا.',
            icon: Icons.skip_next_rounded,
            selected: _skipBudget,
            onTap: () {
              _amountController.removeListener(_handleFieldChanged);
              _amountController.clear();
              _amountController.addListener(_handleFieldChanged);
              setState(() {
                _skipBudget = true;
              });
            },
          ),
        ],
      ),
    );
  }
}
