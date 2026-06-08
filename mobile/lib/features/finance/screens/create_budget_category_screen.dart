import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/primary_action_button.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('تصنيف ميزانية جديد')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'أضف بندا واضحا للميزانية',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'اسم التصنيف',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'اسم التصنيف مطلوب'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _targetAmountController,
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ المستهدف اختياري',
                      ),
                      validator: (value) {
                        final rawValue = value?.trim() ?? '';
                        if (rawValue.isEmpty) {
                          return null;
                        }
                        final parsed = num.tryParse(rawValue);
                        if (parsed == null || parsed < 0) {
                          return 'المبلغ يجب أن يكون رقما غير سالب';
                        }
                        return null;
                      },
                    ),
                    if (provider.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        provider.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                    const SizedBox(height: 20),
                    PrimaryActionButton(
                      label: 'حفظ التصنيف',
                      isLoading: provider.isSubmitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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
