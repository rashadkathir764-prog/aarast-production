import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_duplicate_utils.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../shared/models/quote_finance_context.dart';
import '../../../shared/models/contact_phone_draft.dart';
import '../../../shared/widgets/contact_phone_field.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../wedding_plans/providers/wedding_plans_provider.dart';
import '../models/debt.dart';
import '../providers/debt_installment_provider.dart';

class CreateDebtScreen extends StatefulWidget {
  const CreateDebtScreen({
    required this.weddingPlanId,
    this.quoteContext,
    super.key,
  });

  final String weddingPlanId;
  final QuoteFinanceContext? quoteContext;

  @override
  State<CreateDebtScreen> createState() => _CreateDebtScreenState();
}

class _CreateDebtScreenState extends State<CreateDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _creditorNameController = TextEditingController();
  final _creditorPhoneController = TextEditingController();
  final _titleController = TextEditingController();
  final _totalAmountController = TextEditingController();
  final _paidAmountController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime? _dueDate;
  String _status = 'OPEN';
  String? _localErrorMessage;

  @override
  void initState() {
    super.initState();
    final quoteContext = widget.quoteContext;
    if (quoteContext != null) {
      _creditorNameController.text = quoteContext.providerName;
      _titleController.text = quoteContext.title;
      _totalAmountController.text = quoteContext.amount?.trim() ?? '';
      _noteController.text = quoteContext.note;
    }
    _creditorNameController.addListener(_handleContactChanged);
    _creditorPhoneController.addListener(_handleContactChanged);
  }

  @override
  void dispose() {
    _creditorNameController
      ..removeListener(_handleContactChanged)
      ..dispose();
    _creditorPhoneController
      ..removeListener(_handleContactChanged)
      ..dispose();
    _titleController.dispose();
    _totalAmountController.dispose();
    _paidAmountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DebtInstallmentProvider>();
    final currencyLabel = _currencyLabel(context);

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
                    icon: const Icon(LucideIcons.arrowRight),
                    tooltip: 'رجوع',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'مبلغ باقي جديد',
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
                    _DebtHero(fromQuote: widget.quoteContext != null),
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
                              labelText: 'لمن باقي المبلغ؟',
                              hintText: 'مثال: قاعة الفرح',
                              prefixIcon: Icon(LucideIcons.user),
                            ),
                            validator: _required('اسم الجهة أو الشخص مطلوب'),
                          ),
                          const SizedBox(height: 14),
                          ContactPhoneField(
                            nameController: _creditorNameController,
                            phoneController: _creditorPhoneController,
                            label: 'رقم الجوال (اختياري)',
                            duplicateMessage: _sameCreditorWarning(
                              provider.debts,
                            ),
                            duplicateIsBlocking: false,
                            planContacts: _creditorPlanContacts(provider.debts),
                            onDraftChanged: (_) {
                              if (!mounted) return;
                              setState(() => _localErrorMessage = null);
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _titleController,
                            textAlign: TextAlign.right,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'عنوان المبلغ',
                              hintText: 'مثال: باقي الصالة',
                              prefixIcon: Icon(LucideIcons.receipt),
                            ),
                            validator: _required('عنوان المبلغ مطلوب'),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _totalAmountController,
                            textAlign: TextAlign.right,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'إجمالي المبلغ',
                              suffixText: currencyLabel,
                              prefixIcon: const Icon(LucideIcons.wallet),
                            ),
                            validator: _nonNegativeRequired(
                              'إجمالي المبلغ مطلوب',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _paidAmountController,
                            textAlign: TextAlign.right,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'المبلغ المدفوع (اختياري)',
                              suffixText: currencyLabel,
                              prefixIcon: const Icon(LucideIcons.checkCircle),
                            ),
                            validator: _nonNegativeOptional,
                          ),
                          const SizedBox(height: 14),
                          _SelectorField(
                            label: 'موعد دفع الباقي',
                            value: _dueDate == null
                                ? 'لم يحدد بعد'
                                : _formatDate(_dueDate!),
                            icon: LucideIcons.calendarDays,
                            selected: _dueDate != null,
                            onTap: _showCalendarPicker,
                          ),
                          const SizedBox(height: 18),
                          const Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              'حالة المبلغ',
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
                                label: 'باقي',
                                value: 'OPEN',
                                color: AppTheme.burgundy,
                                selected: _status == 'OPEN',
                                onTap: _setStatus,
                              ),
                              _StatusChoice(
                                label: 'دفع جزئي',
                                value: 'PARTIALLY_PAID',
                                color: AppTheme.gold,
                                selected: _status == 'PARTIALLY_PAID',
                                onTap: _setStatus,
                              ),
                              _StatusChoice(
                                label: 'مسدد',
                                value: 'PAID',
                                color: AppTheme.success,
                                selected: _status == 'PAID',
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
                              hintText: 'مثال: يسدد قبل المناسبة بأسبوع...',
                              alignLabelWithHint: true,
                            ),
                          ),
                          if (_localErrorMessage != null ||
                              provider.errorMessage != null) ...[
                            const SizedBox(height: 14),
                            AarastStatusPill(
                              label:
                                  _localErrorMessage ?? provider.errorMessage!,
                              color: AppTheme.danger,
                              icon: LucideIcons.alertCircle,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    AarastButton(
                      label: 'حفظ المبلغ',
                      icon: LucideIcons.check,
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

  String _currencyLabel(BuildContext context) {
    final quoteCurrency = widget.quoteContext?.currency;
    if (quoteCurrency?.trim().isNotEmpty == true) {
      return currencyLabelAr(quoteCurrency);
    }
    final plans = context.read<WeddingPlansProvider?>();
    for (final plan in plans?.plans ?? const []) {
      if (plan.id == widget.weddingPlanId) {
        return currencyLabelAr(plan.currency);
      }
    }
    return currencyLabelAr(null);
  }

  void _setStatus(String value) => setState(() => _status = value);

  void _handleContactChanged() {
    if (mounted) {
      setState(() => _localErrorMessage = null);
    }
  }

  String? _sameCreditorWarning(List<Debt> debts) {
    final phone = _creditorPhoneController.text;
    final name = _creditorNameController.text;
    if (phone.trim().isEmpty || name.trim().isEmpty) return null;

    final duplicate = ContactDuplicateUtils.findByPhone(
      debts,
      candidatePhone: phone,
      phoneOf: (debt) => debt.creditorPhone,
    );
    if (duplicate == null ||
        !ContactDuplicateUtils.sameName(duplicate.creditorName, name)) {
      return null;
    }
    return 'هذا الشخص أو المورد لديه مبلغ مسجل سابقاً. يمكنك المتابعة إذا كان مبلغاً مختلفاً.';
  }

  List<ContactPhoneDraft> _creditorPlanContacts(List<Debt> debts) {
    final seen = <String>{};
    final contacts = <ContactPhoneDraft>[];
    for (final debt in debts) {
      final phone = debt.creditorPhone;
      final key = PhoneNumberUtils.comparisonKey(phone);
      if (phone == null || key == null || !seen.add(key)) continue;
      contacts.add(
        ContactPhoneDraft.fromInput(
          name: debt.creditorName,
          rawPhone: phone,
          source: ContactPhoneSource.planContact,
          relation: 'مبلغ باقي',
        ),
      );
    }
    return contacts;
  }

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
                    icon: LucideIcons.calendarCheck,
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
                    icon: LucideIcons.check,
                    onPressed: () => Navigator.of(sheetContext).pop(tempDate),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null && mounted) setState(() => _dueDate = selected);
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
    final normalizedPhone = PhoneNumberUtils.normalizeOptional(
      _creditorPhoneController.text,
    );
    if (_isExactDebtDuplicate(provider.debts, normalizedPhone)) {
      setState(() {
        _localErrorMessage =
            'يوجد مبلغ مطابق لنفس الشخص أو المورد والرقم والعنوان والقيمة.';
      });
      return;
    }

    if (await AuthActionGuard.blockCloudSubmitForNonLocalPlanning(
      context,
      weddingPlanId: widget.weddingPlanId,
    )) {
      return;
    }
    if (!mounted) return;

    final paid = _paidAmountController.text.trim();
    final note = _noteController.text.trim();
    final debt = await provider.createDebt(
      weddingPlanId: widget.weddingPlanId,
      creditorName: _creditorNameController.text.trim(),
      creditorPhone: normalizedPhone,
      title: _titleController.text.trim(),
      totalAmount: _totalAmountController.text.trim(),
      paidAmount: paid.isEmpty ? null : paid,
      dueDate: _dueDate,
      status: _status,
      note: note.isEmpty ? null : note,
    );

    if (debt != null && mounted) {
      final notice = provider.noticeMessage;
      if (notice != null) {
        AarastToast.showSuccess(context, notice);
      }
      _goBack();
    }
  }

  bool _isExactDebtDuplicate(List<Debt> debts, String? normalizedPhone) {
    final creditorName = _creditorNameController.text;
    final title = ContactDuplicateUtils.normalizeName(_titleController.text);
    final totalAmount = num.tryParse(_totalAmountController.text.trim());
    if (title.isEmpty || totalAmount == null) return false;

    return debts.any((debt) {
      final debtAmount = num.tryParse(debt.totalAmount);
      return ContactDuplicateUtils.sameName(debt.creditorName, creditorName) &&
          PhoneNumberUtils.areEquivalent(debt.creditorPhone, normalizedPhone) &&
          ContactDuplicateUtils.normalizeName(debt.title) == title &&
          debtAmount == totalAmount;
    });
  }
}

class _DebtHero extends StatelessWidget {
  const _DebtHero({required this.fromQuote});

  final bool fromQuote;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.burgundySoft.withAlpha(120),
      border: Border.all(color: AppTheme.burgundy.withAlpha(35)),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: const Icon(
              LucideIcons.wallet,
              color: AppTheme.burgundy,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fromQuote ? 'حوّل العرض إلى التزام واضح' : 'سجل الباقي بوضوح',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.burgundyDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'اكتب كم بقي، كم دفعت، ومتى موعد الدفعة القادمة.',
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
            const Icon(LucideIcons.chevronDown, color: AppTheme.muted),
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
                Icon(LucideIcons.checkCircle, color: color, size: 15),
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
  return formatArabicCompactDate(date);
}
