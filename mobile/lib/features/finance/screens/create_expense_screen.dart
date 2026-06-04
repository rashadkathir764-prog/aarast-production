import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../providers/finance_provider.dart';

class CreateExpenseScreen extends StatefulWidget {
  const CreateExpenseScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<CreateExpenseScreen> createState() => _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends State<CreateExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _budgetCategoryId;
  String _status = 'PLANNED';
  DateTime? _expenseDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<FinanceProvider>();
      if (provider.budgetCategories.isEmpty) {
        provider.loadFinance(widget.weddingPlanId);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('مصروف جديد')),
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
                      'سجل مصروفا مرتبطا بخطة الزفاف',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'عنوان المصروف',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'عنوان المصروف مطلوب'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _amountController,
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'المبلغ'),
                      validator: (value) {
                        final rawValue = value?.trim() ?? '';
                        final parsed = num.tryParse(rawValue);
                        if (parsed == null || parsed < 0) {
                          return 'المبلغ يجب أن يكون رقما غير سالب';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _budgetCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'تصنيف الميزانية اختياري',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('بدون تصنيف'),
                        ),
                        for (final category in provider.budgetCategories)
                          DropdownMenuItem<String>(
                            value: category.id,
                            child: Text(category.name),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => _budgetCategoryId = value),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'الحالة'),
                      items: const [
                        DropdownMenuItem(value: 'PLANNED', child: Text('مخطط')),
                        DropdownMenuItem(value: 'PAID', child: Text('مدفوع')),
                        DropdownMenuItem(
                          value: 'CANCELLED',
                          child: Text('ملغي'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _status = value ?? 'PLANNED'),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _expenseDate == null
                            ? 'اختيار تاريخ المصروف اختياري'
                            : _formatDate(_expenseDate!),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _noteController,
                      textAlign: TextAlign.right,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظة اختيارية',
                      ),
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
                      label: 'حفظ المصروف',
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _expenseDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (selectedDate != null) {
      setState(() => _expenseDate = selectedDate);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<FinanceProvider>();
    final created = await provider.createExpense(
      weddingPlanId: widget.weddingPlanId,
      title: _titleController.text,
      amount: _amountController.text,
      budgetCategoryId: _budgetCategoryId,
      status: _status,
      expenseDate: _expenseDate,
      note: _noteController.text,
    );

    if (created && mounted) {
      context.go(AppRouter.finance(widget.weddingPlanId));
    }
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
