import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';
import '../providers/finance_provider.dart';
import '../widgets/finance_write_access_block.dart';
import '../models/financial_input_validation.dart';

class BudgetSetupScreen extends StatefulWidget {
  const BudgetSetupScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<BudgetSetupScreen> createState() => _BudgetSetupScreenState();
}

class _BudgetSetupScreenState extends State<BudgetSetupScreen> {
  late final List<_BudgetSetupItem> _items = _defaultBudgetItems
      .map(
        (item) => _BudgetSetupItem(
          name: item.name,
          icon: item.icon,
          selected: item.recommended,
        ),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FinanceProvider>().loadFinance(widget.weddingPlanId);
    });
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final accessBlock = financeWriteAccessBlock(
      context: context,
      provider: provider,
      weddingPlanId: widget.weddingPlanId,
    );
    if (accessBlock != null) return accessBlock;
    final currencyLabel = _planCurrencyLabel(context, widget.weddingPlanId);
    final existingNames = provider.budgetCategories
        .map((category) => category.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    final selectedCount = _items
        .where((item) => item.selected && !existingNames.contains(item.name))
        .length;

    return AarastScreenFrame(
      maxWidth: 520,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _goBack,
                    icon: const Icon(LucideIcons.arrowRight),
                    tooltip: 'رجوع',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'إعداد الميزانية',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.burgundyDeep,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            sliver: SliverList.list(
              children: [
                const _BudgetSetupHero(),
                const SizedBox(height: 14),
                _SetupToolbar(
                  selectedCount: selectedCount,
                  onSelectEssentials: () => _setRecommendedOnly(true),
                  onClear: () => _setAll(false),
                ),
                const SizedBox(height: 12),
                for (final item in _items) ...[
                  _BudgetSetupRow(
                    item: item,
                    currencyLabel: currencyLabel,
                    alreadyExists: existingNames.contains(item.name),
                    onChanged: (value) {
                      setState(() => item.selected = value);
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                if (provider.errorMessage != null) ...[
                  const SizedBox(height: 4),
                  AarastStatusPill(
                    label: provider.errorMessage!,
                    color: AppTheme.danger,
                    icon: LucideIcons.alertCircle,
                  ),
                  const SizedBox(height: 12),
                ],
                AarastButton(
                  label: selectedCount == 0
                      ? 'اختر بنداً للحفظ'
                      : 'حفظ $selectedCount بند',
                  icon: LucideIcons.check,
                  isLoading: provider.isSubmitting,
                  onPressed: selectedCount == 0 ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _setRecommendedOnly(bool selected) {
    setState(() {
      for (final item in _items) {
        item.selected = item.recommended == true ? selected : false;
      }
    });
  }

  void _setAll(bool selected) {
    setState(() {
      for (final item in _items) {
        item.selected = selected;
      }
    });
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRouter.finance(widget.weddingPlanId));
  }

  Future<void> _submit() async {
    if (await AuthActionGuard.blockCloudSubmitForNonLocalPlanning(
      context,
      weddingPlanId: widget.weddingPlanId,
    )) {
      return;
    }
    if (!mounted) return;

    final provider = context.read<FinanceProvider>();
    final existingNames = provider.budgetCategories
        .map((category) => category.name.trim())
        .where((name) => name.isNotEmpty)
        .toSet();
    final selected = _items
        .where((item) => item.selected && !existingNames.contains(item.name))
        .map(
          (item) => (
            name: item.name,
            targetAmount: item.amountController.text.trim().isEmpty
                ? null
                : item.amountController.text.trim(),
          ),
        )
        .toList();

    final invalidAmount = selected.any((item) {
      final raw = item.targetAmount?.trim();
      if (raw == null || raw.isEmpty) return false;
      final parsed = num.tryParse(raw);
      return parsed == null || parsed < 0;
    });
    if (invalidAmount) {
      AarastToast.showError(context, 'المبالغ يجب أن تكون أرقاماً غير سالبة.');
      return;
    }

    if (!hasUsableBudgetSetupAmount(
      selected.map((item) => item.targetAmount),
      hasGeneralBudget: provider.moneySummary.hasUsableBudget,
    )) {
      AarastToast.showError(
        context,
        'أدخل مبلغاً لبند واحد على الأقل حتى تصبح للميزانية قيمة فعلية.',
      );
      return;
    }

    final saved = await provider.createBudgetCategoryBatch(
      weddingPlanId: widget.weddingPlanId,
      categories: selected,
    );
    if (!saved || !mounted) return;

    final notice = provider.noticeMessage;
    if (notice != null) {
      AarastToast.showSuccess(context, notice);
    }
    context.go(AppRouter.finance(widget.weddingPlanId));
  }
}

class _BudgetSetupHero extends StatelessWidget {
  const _BudgetSetupHero();

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(18),
      color: AppTheme.burgundySoft.withAlpha(110),
      border: Border.all(color: AppTheme.burgundy.withAlpha(35)),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: const Icon(
              LucideIcons.slidersHorizontal,
              color: AppTheme.burgundy,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'رتب الميزانية قبل اختيار الموردين',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.burgundyDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'حدد بنود الزفاف الأساسية، واكتب مبلغاً لكل بند أو اتركه فارغاً الآن. هذه الأرقام تستخدم لاحقاً لاقتراح موردين أقرب لسعرك.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupToolbar extends StatelessWidget {
  const _SetupToolbar({
    required this.selectedCount,
    required this.onSelectEssentials,
    required this.onClear,
  });

  final int selectedCount;
  final VoidCallback onSelectEssentials;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'مختار $selectedCount',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onSelectEssentials,
          icon: const Icon(LucideIcons.sparkles, size: 17),
          label: const Text('الأساسيات'),
        ),
        TextButton.icon(
          onPressed: onClear,
          icon: const Icon(LucideIcons.x, size: 17),
          label: const Text('مسح'),
        ),
      ],
    );
  }
}

class _BudgetSetupRow extends StatelessWidget {
  const _BudgetSetupRow({
    required this.item,
    required this.currencyLabel,
    required this.alreadyExists,
    required this.onChanged,
  });

  final _BudgetSetupItem item;
  final String currencyLabel;
  final bool alreadyExists;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = !alreadyExists;
    return AarastCard(
      padding: const EdgeInsets.all(12),
      color: alreadyExists ? AppTheme.pearl : AppTheme.surface,
      border: Border.all(color: AppTheme.border),
      child: Row(
        children: [
          Checkbox(
            value: alreadyExists ? true : item.selected,
            onChanged: enabled ? (value) => onChanged(value ?? false) : null,
            activeColor: AppTheme.burgundy,
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.goldSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(item.icon, color: AppTheme.gold, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (alreadyExists)
                  Text(
                    'موجود مسبقاً',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 116,
            child: TextField(
              controller: item.amountController,
              enabled: enabled,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'المبلغ',
                suffixText: currencyLabel,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _planCurrencyLabel(BuildContext context, String weddingPlanId) {
  final provider = context.watch<WeddingPlansProvider?>();
  for (final plan in provider?.plans ?? const []) {
    if (plan.id == weddingPlanId) return currencyLabelAr(plan.currency);
  }
  return currencyLabelAr(
    provider?.selectedPlan?.currency ?? provider?.activePlan?.currency,
  );
}

class _BudgetSetupItem {
  _BudgetSetupItem({
    required this.name,
    required this.icon,
    required this.selected,
  }) : recommended = selected;

  final String name;
  final IconData icon;
  final bool recommended;
  bool selected;
  final amountController = TextEditingController();

  void dispose() {
    amountController.dispose();
  }
}

const _defaultBudgetItems = [
  _BudgetTemplate('الصالة', LucideIcons.building2),
  _BudgetTemplate('الغداء', LucideIcons.utensils),
  _BudgetTemplate('العشاء', LucideIcons.utensils),
  _BudgetTemplate('الفنان', LucideIcons.mic),
  _BudgetTemplate('الماء والضيافة', LucideIcons.cupSoda),
  _BudgetTemplate('التصوير', LucideIcons.camera),
  _BudgetTemplate('الكوشة', LucideIcons.armchair),
  _BudgetTemplate('الأزياء', LucideIcons.shirt),
  _BudgetTemplate('الزينة والورود', LucideIcons.flower2, false),
  _BudgetTemplate('المواصلات', LucideIcons.car, false),
];

class _BudgetTemplate {
  const _BudgetTemplate(this.name, this.icon, [this.recommended = true]);

  final String name;
  final IconData icon;
  final bool recommended;
}
