import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../providers/finance_provider.dart';

class CreateBudgetCategoryScreen extends StatefulWidget {
  const CreateBudgetCategoryScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

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
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

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
                    icon: const Icon(Icons.arrow_forward_rounded),
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
                              prefixIcon: Icon(Icons.sell_outlined),
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
                            decoration: const InputDecoration(
                              labelText: 'المبلغ المستهدف (اختياري)',
                              suffixText: 'ر.ي',
                              prefixIcon: Icon(Icons.track_changes_rounded),
                            ),
                            validator: _nonNegativeOptional,
                          ),
                          if (provider.errorMessage != null) ...[
                            const SizedBox(height: 14),
                            AarastStatusPill(
                              label: provider.errorMessage!,
                              color: AppTheme.danger,
                              icon: Icons.error_outline_rounded,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    AarastButton(
                      label: 'حفظ التصنيف',
                      icon: Icons.check_rounded,
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
    if (await AuthActionGuard.blockProtectedSubmitWithoutAccount(context)) {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(notice)));
      }
      _goBack();
    }
  }
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
              Icons.create_new_folder_outlined,
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
