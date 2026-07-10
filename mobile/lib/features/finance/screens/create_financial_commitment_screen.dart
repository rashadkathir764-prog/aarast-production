import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';
import '../models/financial_commitment.dart';
import '../providers/finance_provider.dart';

class CreateFinancialCommitmentScreen extends StatefulWidget {
  const CreateFinancialCommitmentScreen({
    required this.weddingPlanId,
    this.commitmentId,
    this.initialCommitment,
    this.initialBudgetCategoryId,
    this.initialSourceType = 'MANUAL_COMMITMENT',
    super.key,
  });

  final String weddingPlanId;
  final String? commitmentId;
  final FinancialCommitment? initialCommitment;
  final String? initialBudgetCategoryId;
  final String initialSourceType;

  @override
  State<CreateFinancialCommitmentScreen> createState() =>
      _CreateFinancialCommitmentScreenState();
}

class _CreateFinancialCommitmentScreenState
    extends State<CreateFinancialCommitmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _partyNameController = TextEditingController();
  final _partyPhoneController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _budgetCategoryId;
  late String _sourceType;
  DateTime? _dueDate;
  DateTime? _agreementDate;

  bool get _isEditMode => widget.commitmentId != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCommitment;
    _budgetCategoryId =
        widget.initialBudgetCategoryId ?? initial?.budgetCategoryId;
    _sourceType = initial?.sourceType ?? widget.initialSourceType;
    if (initial != null) {
      _titleController.text = initial.title;
      _partyNameController.text = initial.partyName ?? '';
      _partyPhoneController.text = initial.partyPhone ?? '';
      _totalAmountController.text = initial.totalAmount;
      _noteController.text = initial.note ?? '';
      _dueDate = initial.dueDate;
      _agreementDate = initial.agreementDate;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<FinanceProvider>().loadFinance(widget.weddingPlanId);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _partyNameController.dispose();
    _partyPhoneController.dispose();
    _totalAmountController.dispose();
    _paidAmountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final categories = provider.budgetCategories;
    final currencyLabel = _planCurrencyLabel(context, widget.weddingPlanId);

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
                      _sourceType == 'PROVIDER_SERVICE'
                          ? 'حجز مورد / تكلفة خدمة'
                          : _sourceType == 'MANUAL_DEBT'
                          ? 'مستحق عليك'
                          : _isEditMode
                          ? 'تعديل مستحق مالي'
                          : 'مستحق مالي',
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
                    if (categories.isEmpty)
                      _NoCategoryCard(weddingPlanId: widget.weddingPlanId)
                    else
                      AarastCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: _categoryValue(categories),
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'التصنيف المالي',
                                prefixIcon: Icon(LucideIcons.tags),
                              ),
                              items: [
                                for (final category in categories)
                                  DropdownMenuItem(
                                    value: category.id,
                                    child: Text(
                                      category.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (value) {
                                setState(() => _budgetCategoryId = value);
                              },
                              validator: (value) =>
                                  value == null ? 'اختر تصنيفاً مالياً' : null,
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              initialValue: _sourceType,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'نوع المستحق',
                                prefixIcon: Icon(LucideIcons.fileText),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'PROVIDER_SERVICE',
                                  child: Text('مورد / تكلفة خدمة'),
                                ),
                                DropdownMenuItem(
                                  value: 'MANUAL_DEBT',
                                  child: Text('مستحق عليك'),
                                ),
                                DropdownMenuItem(
                                  value: 'MANUAL_COMMITMENT',
                                  child: Text('مستحق يدوي'),
                                ),
                                DropdownMenuItem(
                                  value: 'OTHER',
                                  child: Text('أخرى'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _sourceType = value);
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _titleController,
                              textAlign: TextAlign.right,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'اسم المستحق',
                                hintText: 'مثال: باقي القاعة أو دفعة التصوير',
                                prefixIcon: Icon(LucideIcons.badgeCheck),
                              ),
                              validator: _required('اسم المستحق مطلوب'),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _partyNameController,
                              textAlign: TextAlign.right,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'المورد / الشخص',
                                prefixIcon: Icon(Icons.account_circle_outlined),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _partyPhoneController,
                              textAlign: TextAlign.right,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'رقم التواصل',
                                prefixIcon: Icon(LucideIcons.phone),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _totalAmountController,
                              textAlign: TextAlign.right,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: 'التكلفة المتفق عليها',
                                suffixText: currencyLabel,
                                prefixIcon: const Icon(LucideIcons.banknote),
                              ),
                              validator: _requiredMoney,
                            ),
                            const SizedBox(height: 14),
                            if (!_isEditMode) ...[
                              TextFormField(
                                controller: _paidAmountController,
                                textAlign: TextAlign.right,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'المدفوع الآن',
                                  suffixText: currencyLabel,
                                  prefixIcon: const Icon(LucideIcons.receipt),
                                ),
                                validator: _optionalMoney,
                              ),
                              const SizedBox(height: 14),
                            ] else ...[
                              const _EditPaymentHint(),
                              const SizedBox(height: 14),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: _DateButton(
                                    label: 'تاريخ الاتفاق',
                                    value: _agreementDate,
                                    onTap: () => _pickDate(
                                      current: _agreementDate,
                                      onPicked: (date) =>
                                          setState(() => _agreementDate = date),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _DateButton(
                                    label: 'تاريخ الاستحقاق',
                                    value: _dueDate,
                                    onTap: () => _pickDate(
                                      current: _dueDate,
                                      onPicked: (date) =>
                                          setState(() => _dueDate = date),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _noteController,
                              textAlign: TextAlign.right,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'ملاحظة',
                                prefixIcon: Icon(Icons.note_alt_outlined),
                              ),
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
                      label: _isEditMode ? 'حفظ التعديل' : 'حفظ المستحق',
                      icon: LucideIcons.check,
                      isLoading: provider.isSubmitting,
                      onPressed: categories.isEmpty ? null : _submit,
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

  String? _categoryValue(List<dynamic> categories) {
    final selected = _budgetCategoryId;
    if (selected == null) {
      return categories.isEmpty ? null : categories.first.id;
    }
    return categories.any((category) => category.id == selected)
        ? selected
        : categories.first.id;
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime?> onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('ar'),
    );
    onPicked(picked);
  }

  Future<void> _submit() async {
    final categories = context.read<FinanceProvider>().budgetCategories;
    _budgetCategoryId = _categoryValue(categories);
    if (!_formKey.currentState!.validate()) return;
    if (await AuthActionGuard.blockCloudSubmitForNonLocalPlanning(
      context,
      weddingPlanId: widget.weddingPlanId,
    )) {
      return;
    }
    if (!mounted) return;

    final paid = _paidAmountController.text.trim();
    final provider = context.read<FinanceProvider>();
    final current = _commitmentFromProvider(provider);
    final ok = _isEditMode && current != null
        ? await provider.updateFinancialCommitment(
            weddingPlanId: widget.weddingPlanId,
            commitment: current,
            budgetCategoryId: _budgetCategoryId!,
            title: _titleController.text.trim(),
            totalAmount: _totalAmountController.text.trim(),
            sourceType: _sourceType,
            partyName: _partyNameController.text.trim(),
            partyPhone: _partyPhoneController.text.trim(),
            dueDate: _dueDate,
            agreementDate: _agreementDate,
            note: _noteController.text.trim(),
          )
        : await provider.createFinancialCommitment(
            weddingPlanId: widget.weddingPlanId,
            budgetCategoryId: _budgetCategoryId!,
            title: _titleController.text.trim(),
            totalAmount: _totalAmountController.text.trim(),
            sourceType: _sourceType,
            partyName: _partyNameController.text.trim(),
            partyPhone: _partyPhoneController.text.trim(),
            paidAmount: paid.isEmpty ? null : paid,
            dueDate: _dueDate,
            agreementDate: _agreementDate,
            note: _noteController.text.trim(),
          );
    if (ok && mounted) _goBack(changed: true);
  }

  FinancialCommitment? _commitmentFromProvider(FinanceProvider provider) {
    final initial = widget.initialCommitment;
    if (initial != null) return initial;
    final id = widget.commitmentId;
    if (id == null) return null;
    for (final commitment in provider.financialCommitments) {
      if (commitment.id == id) return commitment;
    }
    return null;
  }

  void _goBack({bool changed = false}) {
    if (context.canPop()) {
      context.pop(changed);
      return;
    }
    context.go(AppRouter.finance(widget.weddingPlanId));
  }
}

class _EditPaymentHint extends StatelessWidget {
  const _EditPaymentHint();

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(12),
      color: AppTheme.ivory,
      border: Border.all(color: AppTheme.border),
      child: Row(
        children: [
          const Icon(LucideIcons.receipt, color: AppTheme.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'تعديل المدفوع يتم من سجل الحركات: أضف دفعة جديدة أو أنشئ قيد عكس للدفعة الخاطئة من تفاصيل المستحق.',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoCategoryCard extends StatelessWidget {
  const _NoCategoryCard({required this.weddingPlanId});

  final String weddingPlanId;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(LucideIcons.tags, color: AppTheme.burgundy, size: 34),
          const SizedBox(height: 12),
          Text(
            'أضف بند ميزانية أولاً',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.title,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () =>
                context.push(AppRouter.createBudgetCategory(weddingPlanId)),
            icon: const Icon(LucideIcons.plus),
            label: const Text('إضافة بند ميزانية'),
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(LucideIcons.calendarDays, size: 17),
      label: Text(
        value == null
            ? label
            : '${value!.year}/${value!.month.toString().padLeft(2, '0')}/${value!.day.toString().padLeft(2, '0')}',
        overflow: TextOverflow.ellipsis,
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

FormFieldValidator<String> _required(String message) {
  return (value) => value == null || value.trim().isEmpty ? message : null;
}

String? _requiredMoney(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return 'المبلغ مطلوب';
  final parsed = num.tryParse(raw);
  if (parsed == null || parsed < 0) return 'أدخل مبلغاً صحيحاً';
  return null;
}

String? _optionalMoney(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return null;
  final parsed = num.tryParse(raw);
  if (parsed == null || parsed < 0) return 'أدخل مبلغاً صحيحاً';
  return null;
}
