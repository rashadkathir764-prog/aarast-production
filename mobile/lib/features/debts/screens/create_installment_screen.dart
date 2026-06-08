import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../providers/debt_installment_provider.dart';

class CreateInstallmentScreen extends StatefulWidget {
  const CreateInstallmentScreen({required this.debtId, super.key});

  final String debtId;

  @override
  State<CreateInstallmentScreen> createState() =>
      _CreateInstallmentScreenState();
}

class _CreateInstallmentScreenState extends State<CreateInstallmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime? _dueDate;
  DateTime? _paidAt;
  String _status = 'PENDING';

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DebtInstallmentProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('قسط جديد')),
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
                      'أضف قسطا لهذا الدين',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 16),
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
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'الحالة'),
                      items: const [
                        DropdownMenuItem(
                          value: 'PENDING',
                          child: Text('قيد الانتظار'),
                        ),
                        DropdownMenuItem(value: 'PAID', child: Text('مدفوع')),
                        DropdownMenuItem(
                          value: 'OVERDUE',
                          child: Text('متأخر'),
                        ),
                        DropdownMenuItem(
                          value: 'CANCELLED',
                          child: Text('ملغي'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _status = value ?? 'PENDING'),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _pickDueDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _dueDate == null
                            ? 'اختيار تاريخ الاستحقاق اختياري'
                            : 'الاستحقاق: ${_formatDate(_dueDate!)}',
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _pickPaidAt,
                      icon: const Icon(Icons.event_available),
                      label: Text(
                        _paidAt == null
                            ? 'اختيار تاريخ الدفع اختياري'
                            : 'الدفع: ${_formatDate(_paidAt!)}',
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
                      label: 'حفظ القسط',
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

  Future<void> _pickPaidAt() async {
    final now = DateTime.now();
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _paidAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (selectedDate != null) {
      setState(() => _paidAt = selectedDate);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<DebtInstallmentProvider>();
    final created = await provider.createInstallment(
      debtId: widget.debtId,
      amount: _amountController.text,
      dueDate: _dueDate,
      paidAt: _paidAt,
      status: _status,
      note: _noteController.text,
    );

    if (created && mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRouter.debtDetails(widget.debtId));
      }
    }
  }
}

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
