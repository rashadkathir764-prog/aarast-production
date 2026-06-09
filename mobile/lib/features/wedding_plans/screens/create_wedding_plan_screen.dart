import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../providers/wedding_plans_provider.dart';

class CreateWeddingPlanScreen extends StatefulWidget {
  const CreateWeddingPlanScreen({super.key});

  @override
  State<CreateWeddingPlanScreen> createState() =>
      _CreateWeddingPlanScreenState();
}

class _CreateWeddingPlanScreenState extends State<CreateWeddingPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _cityController = TextEditingController();
  final _budgetController = TextEditingController();
  final _currencyController = TextEditingController(text: 'YER');

  DateTime? _weddingDate;

  @override
  void dispose() {
    _titleController.dispose();
    _cityController.dispose();
    _budgetController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WeddingPlansProvider>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.dBg,
      body: SafeArea(
        child: Stack(
          children: [
            const _CreatePlanDecorations(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                        child: _Header(
                          onBack: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go(AppRouter.home);
                            }
                          },
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 6, 18, 26),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                          decoration: AppTheme.premiumCardDecoration(
                            radius: 30,
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _PlanIcon(),
                                const SizedBox(height: 18),
                                Text(
                                  'ابدأ بخطة واضحة',
                                  textAlign: TextAlign.center,
                                  style: textTheme.headlineSmall?.copyWith(
                                    color: AppTheme.dMaroon,
                                    fontWeight: FontWeight.w900,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'دعنا نجهز لك خطة زفافك خطوة بخطوة بكل سهولة',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.dInkSoft,
                                    fontWeight: FontWeight.w600,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _titleController,
                                  textAlign: TextAlign.right,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'عنوان الخطة',
                                    hintText: 'مثال: خطة زفافنا',
                                    prefixIcon: Icon(
                                      Icons.format_list_bulleted_rounded,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'عنوان الخطة مطلوب';
                                    }
                                    if (value.trim().length < 3) {
                                      return 'عنوان الخطة قصير جداً';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _cityController,
                                  textAlign: TextAlign.right,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'المدينة اختياري',
                                    hintText: 'مثال: صنعاء',
                                    prefixIcon: Icon(
                                      Icons.location_on_outlined,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _PickerField(
                                  label: 'تاريخ الزفاف',
                                  value: _weddingDate == null
                                      ? 'اختيار تاريخ الزفاف اختياري'
                                      : _formatDate(_weddingDate!),
                                  icon: Icons.calendar_month_rounded,
                                  isActive: _weddingDate != null,
                                  onTap: _pickDate,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _budgetController,
                                  textAlign: TextAlign.right,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'الميزانية التقديرية اختياري',
                                    hintText: 'مثال: 2500000',
                                    prefixIcon: Icon(
                                      Icons.account_balance_wallet_outlined,
                                    ),
                                  ),
                                  validator: (value) {
                                    final rawValue = value?.trim() ?? '';
                                    if (rawValue.isEmpty) return null;

                                    final parsed = num.tryParse(rawValue);
                                    if (parsed == null || parsed < 0) {
                                      return 'الميزانية يجب أن تكون رقماً غير سالب';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _currencyController,
                                  textAlign: TextAlign.right,
                                  textInputAction: TextInputAction.done,
                                  decoration: const InputDecoration(
                                    labelText: 'العملة',
                                    prefixIcon: Icon(Icons.paid_outlined),
                                  ),
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'العملة مطلوبة';
                                    }
                                    return null;
                                  },
                                ),
                                if (provider.errorMessage != null) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.dPinkBg,
                                      borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMd,
                                      ),
                                      border: Border.all(
                                        color: AppTheme.danger.withAlpha(70),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: AppTheme.danger,
                                          size: 19,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            provider.errorMessage!,
                                            textAlign: TextAlign.right,
                                            style:
                                                textTheme.bodySmall?.copyWith(
                                              color: AppTheme.danger,
                                              fontWeight: FontWeight.w700,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 22),
                                PrimaryActionButton(
                                  label: 'حفظ ومتابعة',
                                  isLoading: provider.isSubmitting,
                                  onPressed: _submit,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'يمكنك تعديل تفاصيل الخطة في أي وقت',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: AppTheme.dMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _weddingDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppTheme.dMaroon,
                  secondary: AppTheme.dGold,
                ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      setState(() => _weddingDate = selectedDate);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<WeddingPlansProvider>();

    final plan = await provider.createWeddingPlan(
      title: _titleController.text.trim(),
      city: _cityController.text.trim(),
      weddingDate: _weddingDate,
      estimatedBudget: _budgetController.text.trim(),
      currency: _currencyController.text.trim().isEmpty
          ? 'YER'
          : _currencyController.text.trim(),
    );

    if (plan != null && mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRouter.home);
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        _RoundIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: onBack,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'إنشاء خطة زفاف',
            textAlign: TextAlign.right,
            style: textTheme.titleLarge?.copyWith(
              color: AppTheme.dMaroon,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanIcon extends StatelessWidget {
  const _PlanIcon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppTheme.dCard2,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.dGold2),
          boxShadow: AppTheme.cardShadow(),
        ),
        child: const Icon(
          Icons.favorite_rounded,
          color: AppTheme.dMaroon,
          size: 32,
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.dCard2,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isActive ? AppTheme.dMaroon : AppTheme.dLine,
            width: isActive ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? AppTheme.dMaroon : AppTheme.dGoldDeep,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.right,
                    style: textTheme.labelMedium?.copyWith(
                      color: AppTheme.dInkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    textAlign: TextAlign.right,
                    style: textTheme.bodyMedium?.copyWith(
                      color: isActive ? AppTheme.dMaroon : AppTheme.dMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.dCard2,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.dLine),
          ),
          child: Icon(
            icon,
            color: AppTheme.dMaroon,
          ),
        ),
      ),
    );
  }
}

class _CreatePlanDecorations extends StatelessWidget {
  const _CreatePlanDecorations();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: -55,
              child: _DecorativeCircle(
                size: 170,
                color: AppTheme.dGold.withAlpha(32),
              ),
            ),
            Positioned(
              top: 150,
              left: -82,
              child: _DecorativeCircle(
                size: 170,
                color: AppTheme.dMaroon.withAlpha(16),
              ),
            ),
            Positioned(
              bottom: -95,
              right: -60,
              child: _DecorativeCircle(
                size: 210,
                color: AppTheme.dPinkBg.withAlpha(170),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}