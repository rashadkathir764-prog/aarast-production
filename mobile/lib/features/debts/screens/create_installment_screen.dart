import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
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
                      'قسط جديد',
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
                    const _InstallmentHero(),
                    const SizedBox(height: 18),
                    AarastCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _amountController,
                            textAlign: TextAlign.right,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'المبلغ',
                              suffixText: 'YER',
                              prefixIcon: Icon(Icons.payments_outlined),
                            ),
                            validator: _nonNegativeRequired(
                              'المبلغ يجب أن يكون رقماً غير سالب',
                            ),
                          ),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final dueField = _SelectorField(
                                label: 'الاستحقاق',
                                value: _dueDate == null
                                    ? 'لم يحدد بعد'
                                    : _formatDate(_dueDate!),
                                icon: Icons.event_available_rounded,
                                selected: _dueDate != null,
                                onTap: () =>
                                    _showCalendarPicker(mode: _DateMode.due),
                              );
                              final paidField = _SelectorField(
                                label: 'الدفع',
                                value: _paidAt == null
                                    ? 'لم يحدد بعد'
                                    : _formatDate(_paidAt!),
                                icon: Icons.check_circle_outline_rounded,
                                selected: _paidAt != null,
                                onTap: () =>
                                    _showCalendarPicker(mode: _DateMode.paid),
                              );

                              if (constraints.maxWidth < 330) {
                                return Column(
                                  children: [
                                    dueField,
                                    const SizedBox(height: 12),
                                    paidField,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: dueField),
                                  const SizedBox(width: 12),
                                  Expanded(child: paidField),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          const Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              'حالة القسط',
                              style: TextStyle(
                                color: AppTheme.ink,
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
                                label: 'منتظر',
                                value: 'PENDING',
                                color: AppTheme.gold,
                                selected: _status == 'PENDING',
                                onTap: _setStatus,
                              ),
                              _StatusChoice(
                                label: 'مدفوع',
                                value: 'PAID',
                                color: AppTheme.success,
                                selected: _status == 'PAID',
                                onTap: _setStatus,
                              ),
                              _StatusChoice(
                                label: 'متأخر',
                                value: 'OVERDUE',
                                color: AppTheme.danger,
                                selected: _status == 'OVERDUE',
                                onTap: _setStatus,
                              ),
                              _StatusChoice(
                                label: 'ملغي',
                                value: 'CANCELLED',
                                color: AppTheme.muted,
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
                              hintText: 'تفاصيل القسط أو طريقة السداد...',
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
                    AarastButton(
                      label: 'حفظ القسط',
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

  void _setStatus(String value) => setState(() => _status = value);

  Future<void> _showCalendarPicker({required _DateMode mode}) async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final current = mode == _DateMode.due ? _dueDate : _paidAt;
    var tempDate = current ?? now;

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
                  AarastSectionHeader(
                    title: mode == _DateMode.due
                        ? 'تاريخ الاستحقاق'
                        : 'تاريخ الدفع',
                    icon: mode == _DateMode.due
                        ? Icons.event_available_rounded
                        : Icons.check_circle_outline_rounded,
                  ),
                  const SizedBox(height: 8),
                  Theme(
                    data: Theme.of(sheetContext).copyWith(
                      colorScheme: Theme.of(sheetContext).colorScheme.copyWith(
                        primary: AppTheme.burgundy,
                        onPrimary: Colors.white,
                        surface: AppTheme.surface,
                        onSurface: AppTheme.ink,
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
                  AarastButton(
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

    if (selected == null || !mounted) return;
    setState(() {
      if (mode == _DateMode.due) {
        _dueDate = selected;
      } else {
        _paidAt = selected;
      }
    });
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRouter.debtDetails(widget.debtId));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<DebtInstallmentProvider>();
    final note = _noteController.text.trim();
    final created = await provider.createInstallment(
      debtId: widget.debtId,
      amount: _amountController.text.trim(),
      dueDate: _dueDate,
      paidAt: _paidAt,
      status: _status,
      note: note.isEmpty ? null : note,
    );

    if (created && mounted) {
      final notice = provider.noticeMessage;
      if (notice != null) {
        AarastToast.showSuccess(context, notice);
      }
      _goBack();
    }
  }
}

class _InstallmentHero extends StatelessWidget {
  const _InstallmentHero();

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.ivory,
      border: Border.all(color: AppTheme.goldSoft),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: AppTheme.goldGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'قسطي الالتزام إلى خطوات',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.burgundyDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'كل قسط بتاريخ واضح يعني متابعة أسهل وهدوء أكثر.',
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
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppTheme.burgundy : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.burgundy : AppTheme.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppTheme.muted),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.muted,
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
            color: selected ? color.withAlpha(24) : AppTheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? color : AppTheme.border),
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
                    color: selected ? color : AppTheme.muted,
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
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

enum _DateMode { due, paid }

FormFieldValidator<String> _nonNegativeRequired(String message) {
  return (value) {
    final rawValue = value?.trim() ?? '';
    final parsed = num.tryParse(rawValue);
    if (parsed == null || parsed < 0) return message;
    return null;
  };
}

String _formatDate(DateTime date) {
  return formatArabicCompactDate(date);
}
