import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../providers/finance_provider.dart';

class CreateBudgetCategoryScreen extends StatefulWidget {
  const CreateBudgetCategoryScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<CreateBudgetCategoryScreen> createState() => _CreateBudgetCategoryScreenState();
}

class _CreateBudgetCategoryScreenState extends State<CreateBudgetCategoryScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.dBg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.dPinkBg.withAlpha(200),
                ),
              ),
            ),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go(AppRouter.finance(widget.weddingPlanId));
                          }
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.dCard,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.dLine),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: AppTheme.dInk),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'تصنيف ميزانية',
                        style: textTheme.titleLarge?.copyWith(
                          color: AppTheme.dInk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildAnimated(
                            0,
                            Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppTheme.dPinkBg,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppTheme.dLine),
                                  ),
                                  child: const Icon(LucideIcons.folderPlus, color: AppTheme.dMaroon, size: 36),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'أضيفي بنداً واضحاً لتنظيم مصروفاتك ✨',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: AppTheme.dInkSoft,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),

                          _buildAnimated(
                            1,
                            TextFormField(
                              controller: _nameController,
                              textAlign: TextAlign.right,
                              textInputAction: TextInputAction.next,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              decoration: InputDecoration(
                                labelText: 'اسم التصنيف',
                                hintText: 'مثال: الملابس، القاعة، الضيافة...',
                                prefixIcon: const Icon(LucideIcons.tag),
                                filled: true,
                                fillColor: AppTheme.dCard,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  borderSide: const BorderSide(color: AppTheme.dLine),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  borderSide: const BorderSide(color: AppTheme.dLine),
                                ),
                              ),
                              validator: (value) => value == null || value.trim().isEmpty ? 'اسم التصنيف مطلوب' : null,
                            ),
                          ),
                          const SizedBox(height: 20),

                          _buildAnimated(
                            2,
                            TextFormField(
                              controller: _targetAmountController,
                              textAlign: TextAlign.right,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppTheme.dMaroonDeep),
                              decoration: InputDecoration(
                                labelText: 'المبلغ المستهدف (اختياري)',
                                prefixIcon: const Icon(LucideIcons.target),
                                suffixText: 'YER',
                                filled: true,
                                fillColor: AppTheme.dCard,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  borderSide: const BorderSide(color: AppTheme.dLine),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                                  borderSide: const BorderSide(color: AppTheme.dLine),
                                ),
                              ),
                              validator: (value) {
                                final rawValue = value?.trim() ?? '';
                                if (rawValue.isEmpty) return null;
                                final parsed = num.tryParse(rawValue);
                                if (parsed == null || parsed < 0) return 'المبلغ غير صحيح';
                                return null;
                              },
                            ),
                          ),
                          
                          if (provider.errorMessage != null) ...[
                            const SizedBox(height: 24),
                            _buildAnimated(
                              3,
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.danger.withAlpha(20),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                  border: Border.all(color: AppTheme.danger.withAlpha(50)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.alertCircle, color: AppTheme.danger),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        provider.errorMessage!,
                                        style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),

                          _buildAnimated(
                            4,
                            PrimaryActionButton(
                              label: 'حفظ التصنيف',
                              isLoading: provider.isSubmitting,
                              onPressed: _submit,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimated(int index, Widget child) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, childWidget) {
        final delay = 0.1 + (index * 0.05);
        final value = (_animationController.value - delay).clamp(0.0, 1.0);
        final curve = Curves.easeOutCubic.transform(value);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - curve)),
          child: Opacity(
            opacity: curve,
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<FinanceProvider>();
    final created = await provider.createBudgetCategory(
      weddingPlanId: widget.weddingPlanId,
      name: _nameController.text,
      targetAmount: _targetAmountController.text,
    );
    if (created && mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRouter.finance(widget.weddingPlanId));
      }
    }
  }
}
