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

class CreateBudgetCategoryScreen extends StatefulWidget {
  const CreateBudgetCategoryScreen({
    required this.weddingPlanId,
    this.initialName,
    super.key,
  });

  final String weddingPlanId;
  final String? initialName;

  @override
  State<CreateBudgetCategoryScreen> createState() =>
      _CreateBudgetCategoryScreenState();
}

class _CreateBudgetCategoryScreenState
    extends State<CreateBudgetCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initialName = widget.initialName?.trim();
    if (initialName != null && initialName.isNotEmpty) {
      _nameController.text = initialName;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FinanceProvider>().loadFinance(widget.weddingPlanId);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
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

    return AarastScreenFrame(
      maxWidth: 500,
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
                      'تصنيف ميزانية',
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
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _CategoryHero(),
                    const SizedBox(height: 18),
                    AarastCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            textAlign: TextAlign.right,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'اسم التصنيف',
                              hintText: 'مثال: القاعة، الضيافة، التصوير...',
                              prefixIcon: Icon(LucideIcons.tag),
                            ),
                            validator: _required('اسم التصنيف مطلوب'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _targetAmountController,
                            textAlign: TextAlign.right,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'المبلغ المستهدف (اختياري)',
                              suffixText: currencyLabel,
                              prefixIcon: const Icon(LucideIcons.target),
                            ),
                            validator: _nonNegativeOptional,
                          ),
                          if (provider.errorMessage != null) ...[
                            const SizedBox(height: 14),
                            AarastStatusPill(
                              label: provider.errorMessage!,
                              color: AppTheme.danger,
                              icon: LucideIcons.alertCircle,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    AarastButton(
                      label: 'حفظ التصنيف',
                      icon: LucideIcons.check,
                      isLoading: provider.isSubmitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRouter.finance(widget.weddingPlanId));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (await AuthActionGuard.blockCloudSubmitForNonLocalPlanning(
      context,
      weddingPlanId: widget.weddingPlanId,
    )) {
      return;
    }
    if (!mounted) return;

    final provider = context.read<FinanceProvider>();
    final target = _targetAmountController.text.trim();
    final created = await provider.createBudgetCategory(
      weddingPlanId: widget.weddingPlanId,
      name: _nameController.text.trim(),
      targetAmount: target.isEmpty ? null : target,
    );

    if (created && mounted) {
      final notice = provider.noticeMessage;
      if (notice != null) {
        AarastToast.showSuccess(context, notice);
      }
      _goBack();
    }
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

class _CategoryHero extends StatelessWidget {
  const _CategoryHero();

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.burgundySoft.withAlpha(120),
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
              LucideIcons.folderPlus,
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
                  'قسمي الميزانية إلى بنود واضحة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.burgundyDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'كل تصنيف يجعل المصاريف أسهل في القراءة والمراجعة.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
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

FormFieldValidator<String> _required(String message) {
  return (value) => value == null || value.trim().isEmpty ? message : null;
}

String? _nonNegativeOptional(String? value) {
  final rawValue = value?.trim() ?? '';
  if (rawValue.isEmpty) return null;
  final parsed = num.tryParse(rawValue);
  if (parsed == null || parsed < 0) {
    return 'المبلغ يجب أن يكون رقماً غير سالب';
  }
  return null;
}
