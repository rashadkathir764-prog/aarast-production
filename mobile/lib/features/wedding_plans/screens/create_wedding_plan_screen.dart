import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('إنشاء خطة زفاف')),
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
                      'ابدأ بخطة واضحة',
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
                        labelText: 'عنوان الخطة',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'عنوان الخطة مطلوب'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _cityController,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'المدينة اختياري',
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _weddingDate == null
                            ? 'اختيار تاريخ الزفاف اختياري'
                            : _formatDate(_weddingDate!),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _budgetController,
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'الميزانية التقديرية اختياري',
                      ),
                      validator: (value) {
                        final rawValue = value?.trim() ?? '';
                        if (rawValue.isEmpty) {
                          return null;
                        }
                        final parsed = num.tryParse(rawValue);
                        if (parsed == null || parsed < 0) {
                          return 'الميزانية يجب أن تكون رقما غير سالب';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _currencyController,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(labelText: 'العملة'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'العملة مطلوبة'
                          : null,
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
                      label: 'حفظ ومتابعة',
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
      initialDate: _weddingDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (selectedDate != null) {
      setState(() => _weddingDate = selectedDate);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<WeddingPlansProvider>();
    final plan = await provider.createWeddingPlan(
      title: _titleController.text,
      city: _cityController.text,
      weddingDate: _weddingDate,
      estimatedBudget: _budgetController.text,
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

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
