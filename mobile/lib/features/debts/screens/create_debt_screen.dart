import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.dBg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
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
                              'دين جديد',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: AppTheme.dMaroonDeep,
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
                            const _DebtHero(),
                            const SizedBox(height: 18),
                            AarastCard(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _creditorNameController,
                                    textAlign: TextAlign.right,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'اسم الدائن',
                                      hintText: 'مثال: قاعة الفرح',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    validator: _required('اسم الدائن مطلوب'),
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _titleController,
                                    textAlign: TextAlign.right,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'عنوان الدين',
                                      hintText: 'مثال: دفعة قاعة مؤجلة',
                                      prefixIcon: Icon(
                                        Icons.receipt_long_outlined,
                                      ),
                                    ),
                                    validator: _required('عنوان الدين مطلوب'),
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _totalAmountController,
                                    textAlign: TextAlign.right,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'إجمالي الدين',
                                      suffixText: 'YER',
                                      prefixIcon: Icon(
                                        Icons.account_balance_wallet_outlined,
                                      ),
                                    ),
                                    validator: _nonNegativeRequired(
                                      'إجمالي الدين مطلوب',
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _paidAmountController,
                                    textAlign: TextAlign.right,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'المبلغ المدفوع (اختياري)',
                                      suffixText: 'YER',
                                      prefixIcon: Icon(
                                        Icons.check_circle_outline_rounded,
                                      ),
                                    ),
                                    validator: _nonNegativeOptional,
                                  ),
                                  const SizedBox(height: 14),
                                  _SelectorField(
                                    label: 'تاريخ الاستحقاق',
                                    value: _dueDate == null
                                        ? 'اختياري'
                                        : _formatDate(_dueDate!),
                                    icon: Icons.calendar_month_rounded,
                                    selected: _dueDate != null,
                                    onTap: _showCalendarPicker,
                                  ),
                                  const SizedBox(height: 18),
                                  const Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      'حالة الدين',
                                      style: TextStyle(
                                        color: AppTheme.dInk,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _StatusChoice(
                                        label: 'مفتوح',
                                        value: 'OPEN',
                                        color: AppTheme.dMaroon,
                                        selected: _status == 'OPEN',
                                        onTap: _setStatus,
                                      ),
                                      _StatusChoice(
                                        label: 'جزئي',
                                        value: 'PARTIALLY_PAID',
                                        color: AppTheme.dGoldDeep,
                                        selected: _status == 'PARTIALLY_PAID',
                                        onTap: _setStatus,
                                      ),
                                      _StatusChoice(
                                        label: 'مدفوع',
                                        value: 'PAID',
                                        color: AppTheme.dGreen,
                                        selected: _status == 'PAID',
                                        onTap: _setStatus,
                                      ),
                                      _StatusChoice(
                                        label: 'ملغي',
                                        value: 'CANCELLED',
                                        color: AppTheme.dMuted,
                                        selected: _status == 'CANCELLED',
                                        onTap: _setStatus,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _noteController,
                                    textAlign: TextAlign.right,
                                    minLines: 3,
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                      labelText: 'ملاحظة اختيارية',
                                      hintText:
                                          'أضيفي تفاصيل الاتفاق أو موعد السداد...',
                                      alignLabelWithHint: true,
                                    ),
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
                            PrimaryActionButton(
                              label: 'حفظ الدين',
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
            ),
          ),
        ),
      ),
    );
  }

  void _setStatus(String value) => setState(() => _status = value);

  Future<void> _showCalendarPicker() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    var tempDate = _dueDate ?? now;

    final selected = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 20),
                  const AarastSectionHeader(
                    title: 'تاريخ الاستحقاق',
                    icon: Icons.event_available_rounded,
                  ),
                  const SizedBox(height: 8),
                  Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                        primary: AppTheme.dMaroon,
                        onPrimary: Colors.white,
                        surface: AppTheme.dCard2,
                        onSurface: AppTheme.dInk,
                      ),
                    ),
                    child: CalendarDatePicker(
                      initialDate: tempDate,
                      firstDate: DateTime(now.year - 1),
                      lastDate: DateTime(now.year + 10),
                      onDateChanged: (date) => tempDate = date,
                    ),
                  ),
                  const SizedBox(height: 12),
                  PrimaryActionButton(
                    label: 'تأكيد التاريخ',
                    icon: Icons.check_rounded,
                    onPressed: () => Navigator.of(sheetContext).pop(tempDate),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null) setState(() => _dueDate = selected);
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRouter.debts(widget.weddingPlanId));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<DebtInstallmentProvider>();
    final paid = _paidAmountController.text.trim();
    final note = _noteController.text.trim();
    final debt = await provider.createDebt(
      weddingPlanId: widget.weddingPlanId,
      creditorName: _creditorNameController.text.trim(),
      title: _titleController.text.trim(),
      totalAmount: _totalAmountController.text.trim(),
      paidAmount: paid.isEmpty ? null : paid,
      dueDate: _dueDate,
      status: _status,
      note: note.isEmpty ? null : note,
    );

    if (debt != null && mounted) _goBack();
  }
}

class _DebtHero extends StatelessWidget {
  const _DebtHero();

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dPinkBg.withAlpha(120),
      border: Border.all(color: AppTheme.dMaroon.withAlpha(35)),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.dCard2,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppTheme.dMaroon,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سجلي الالتزام كما هو',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.dMaroonDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'الدين الواضح أسهل في السداد والمتابعة مع الأقساط.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.dInkSoft,
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

class _SelectorField extends StatelessWidget {
  const _SelectorField({
    required this.label,
    required this.value,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.dCard2,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppTheme.dMaroon : AppTheme.dLine,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.dMaroon : AppTheme.dGoldDeep),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppTheme.dInkSoft),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.dInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.dMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChoice extends StatelessWidget {
  const _StatusChoice({
    required this.label,
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final bool selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: InkWell(
        onTap: () => onTap(value),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color.withAlpha(24) : AppTheme.dCard2,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? color : AppTheme.dLine),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                Icon(Icons.check_circle_rounded, color: color, size: 15),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? color : AppTheme.dInkSoft,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: AppTheme.dLine,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

FormFieldValidator<String> _required(String message) {
  return (value) => value == null || value.trim().isEmpty ? message : null;
}

FormFieldValidator<String> _nonNegativeRequired(String message) {
  return (value) {
    final rawValue = value?.trim() ?? '';
    final parsed = num.tryParse(rawValue);
    if (parsed == null || parsed < 0) return message;
    return null;
  };
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

String _formatDate(DateTime date) {
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}
