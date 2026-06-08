import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../providers/debt_installment_provider.dart';

class CreateDebtScreen extends StatefulWidget {
  const CreateDebtScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<CreateDebtScreen> createState() => _CreateDebtScreenState();
}

class _CreateDebtScreenState extends State<CreateDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _creditorNameController = TextEditingController();
  final _titleController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime? _dueDate;
  String _status = 'OPEN';

  @override
  void dispose() {
    _creditorNameController.dispose();
    _titleController.dispose();
    _totalAmountController.dispose();
    _paidAmountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DebtInstallmentProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('دين جديد')),
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
                      'سجل التزاما ماليا واضحا',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _creditorNameController,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'اسم الدائن',
                      ),
                      validator: _required('اسم الدائن مطلوب'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _titleController,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'عنوان الدين',
                      ),
                      validator: _required('عنوان الدين مطلوب'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _totalAmountController,
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'إجمالي الدين',
                      ),
                      validator: _nonNegativeRequired('إجمالي الدين مطلوب'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _paidAmountController,
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ المدفوع اختياري',
                      ),
                      validator: _nonNegativeOptional,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'الحالة'),
                      items: const [
                        DropdownMenuItem(value: 'OPEN', child: Text('مفتوح')),
                        DropdownMenuItem(
                          value: 'PARTIALLY_PAID',
                          child: Text('مدفوع جزئيا'),
                        ),
                        DropdownMenuItem(value: 'PAID', child: Text('مدفوع')),
                        DropdownMenuItem(
                          value: 'CANCELLED',
                          child: Text('ملغي'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _status = value ?? 'OPEN'),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _pickDueDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _dueDate == null
                            ? 'اختيار تاريخ الاستحقاق اختياري'
                            : _formatDate(_dueDate!),
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
                      label: 'حفظ الدين',
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

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (selectedDate != null) {
      setState(() => _dueDate = selectedDate);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<DebtInstallmentProvider>();
    final debt = await provider.createDebt(
      weddingPlanId: widget.weddingPlanId,
      creditorName: _creditorNameController.text,
      title: _titleController.text,
      totalAmount: _totalAmountController.text,
      paidAmount: _paidAmountController.text,
      dueDate: _dueDate,
      status: _status,
      note: _noteController.text,
    );

    if (debt != null && mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRouter.debts(widget.weddingPlanId));
      }
    }
  }
}

FormFieldValidator<String> _required(String message) {
  return (value) => value == null || value.trim().isEmpty ? message : null;
}

FormFieldValidator<String> _nonNegativeRequired(String message) {
  return (value) {
    final rawValue = value?.trim() ?? '';
    final parsed = num.tryParse(rawValue);
    if (parsed == null || parsed < 0) {
      return message;
    }
    return null;
  };
}

String? _nonNegativeOptional(String? value) {
  final rawValue = value?.trim() ?? '';
  if (rawValue.isEmpty) {
    return null;
  }
  final parsed = num.tryParse(rawValue);
  if (parsed == null || parsed < 0) {
    return 'المبلغ يجب أن يكون رقما غير سالب';
  }
  return null;
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
