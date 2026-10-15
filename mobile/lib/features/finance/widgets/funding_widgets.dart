import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/funding_source.dart';
import '../models/money_summary.dart';
import 'money_input_formatter.dart';
import 'money_widgets.dart';

/// Money in versus money committed, on the money overview (owner only).
class MoneyFundingCard extends StatelessWidget {
  const MoneyFundingCard({
    required this.funding,
    required this.currency,
    required this.onOpen,
    super.key,
  });

  final MoneyFundingSummary funding;
  final String currency;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final empty = funding.sourcesCount == 0;
    return AarastCard(
      key: const ValueKey('money-funding-card'),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.wallet, color: AppTheme.brand),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'مصادر التمويل',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(LucideIcons.chevronLeft, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          if (empty)
            const Text(
              'سجّل مدخراتك ودعم الأهل والرفد والسلف لتعرف كم يغطي مالك من التكاليف.',
              style: TextStyle(color: AppTheme.textSecondary, height: 1.45),
            )
          else ...[
            _FundingLine(
              label: 'المتوفر الآن بعد المدفوع',
              amount: funding.availableCash,
              currency: currency,
            ),
            if (funding.shortfall != null)
              _FundingLine(
                label: 'تكاليف لم يُغطّها التمويل بعد',
                amount: funding.shortfall,
                currency: currency,
                color: AppTheme.danger,
              ),
            if (funding.overdueLoanRepayments > 0)
              Text(
                '${funding.overdueLoanRepayments} دفعة سداد سلفة متأخرة',
                style: const TextStyle(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _FundingLine extends StatelessWidget {
  const _FundingLine({
    required this.label,
    required this.amount,
    required this.currency,
    this.color,
  });

  final String label;
  final Object? amount;
  final String currency;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          MoneyAmountText(amount: amount, currency: currency, color: color),
        ],
      ),
    );
  }
}

/// What the funding form returns; [delete] asks to remove the source.
class FundingFormResult {
  const FundingFormResult({
    required this.kind,
    required this.sourceName,
    required this.amount,
    required this.status,
    this.sourcePhone,
    this.note,
    this.delete = false,
  });

  const FundingFormResult.delete()
    : kind = '',
      sourceName = '',
      amount = '',
      status = '',
      sourcePhone = null,
      note = null,
      delete = true;

  final String kind;
  final String sourceName;
  final String amount;
  final String status;
  final String? sourcePhone;
  final String? note;
  final bool delete;
}

/// Add or edit one funding source: savings, family support, gifts, a loan.
class FundingSourceFormSheet extends StatefulWidget {
  const FundingSourceFormSheet({this.source, super.key});

  final FundingSource? source;

  @override
  State<FundingSourceFormSheet> createState() => _FundingSourceFormSheetState();
}

class _FundingSourceFormSheetState extends State<FundingSourceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.source?.sourceName);
  late final _phone = TextEditingController(text: widget.source?.sourcePhone);
  late final _amount = TextEditingController(
    text: formatMoneyInputValue(widget.source?.amount),
  );
  late final _note = TextEditingController(text: widget.source?.note);
  late String _kind = widget.source?.kind ?? FundingKind.familySupport;
  late bool _pledged = widget.source?.isPledged ?? false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      FundingFormResult(
        kind: _kind,
        sourceName: _name.text.trim(),
        amount: _amount.text.replaceAll(',', '').trim(),
        status: _pledged ? FundingStatus.pledged : FundingStatus.received,
        sourcePhone: _phone.text,
        note: _note.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.source != null;
    final isLoan = _kind == FundingKind.loan;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AarastV3FocusPrompt(
                  question: editing
                      ? 'ما الذي تغيّر في هذا المصدر؟'
                      : 'من أين يأتي هذا المال؟',
                  supportingText:
                      'سجّل المصدر ومبلغه؛ التطبيق يتتبّع المال ولا يحرّكه.',
                  icon: LucideIcons.wallet,
                ),
                const SizedBox(height: 14),
                AarastChoicePillRow<String>(
                  value: _kind,
                  options: [
                    for (final kind in FundingKind.all)
                      (kind, FundingKind.label(kind)),
                  ],
                  onChanged: (value) => setState(() => _kind = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('funding-name'),
                  controller: _name,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    labelText: isLoan ? 'ممّن السلفة؟' : 'من أين؟',
                    hintText: isLoan ? 'مثال: ابن العم' : 'مثال: الوالد',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'اكتب اسم المصدر'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const ValueKey('funding-amount'),
                  controller: _amount,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const [MoneyInputFormatter()],
                  decoration: const InputDecoration(labelText: 'المبلغ'),
                  validator: (value) {
                    final amount = double.tryParse(
                      (value ?? '').replaceAll(',', ''),
                    );
                    return amount == null || amount <= 0
                        ? 'اكتب مبلغًا أكبر من صفر'
                        : null;
                  },
                ),
                if (!isLoan) ...[
                  const SizedBox(height: 6),
                  SwitchListTile(
                    key: const ValueKey('funding-pledged'),
                    contentPadding: EdgeInsets.zero,
                    value: _pledged,
                    onChanged: (value) => setState(() => _pledged = value),
                    title: const Text('وعد ولم يُستلم بعد'),
                  ),
                ],
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phone,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم الجوال (اختياري)',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _note,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة (اختياري)',
                  ),
                ),
                const SizedBox(height: 16),
                AarastButton(
                  key: const ValueKey('funding-save'),
                  label: editing ? 'حفظ التعديلات' : 'إضافة',
                  icon: LucideIcons.save,
                  onPressed: _submit,
                ),
                if (editing) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const ValueKey('funding-delete'),
                    onPressed: () => Navigator.pop(
                      context,
                      const FundingFormResult.delete(),
                    ),
                    icon: const Icon(
                      LucideIcons.trash2,
                      color: AppTheme.danger,
                    ),
                    label: const Text(
                      'حذف المصدر',
                      style: TextStyle(color: AppTheme.danger),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A loan's repayment schedule: add a repayment, mark it paid, remove it.
class LoanRepaymentsSheet extends StatefulWidget {
  const LoanRepaymentsSheet({
    required this.loan,
    required this.currency,
    required this.saving,
    required this.onAdd,
    required this.onTogglePaid,
    required this.onDelete,
    required this.onEdit,
    this.errorMessage,
    super.key,
  });

  final FundingSource loan;
  final String currency;
  final bool saving;
  final String? errorMessage;
  final Future<bool> Function(String amount, DateTime? dueDate) onAdd;
  final void Function(LoanRepayment repayment, bool paid) onTogglePaid;
  final void Function(LoanRepayment repayment) onDelete;
  final VoidCallback onEdit;

  @override
  State<LoanRepaymentsSheet> createState() => _LoanRepaymentsSheetState();
}

class _LoanRepaymentsSheetState extends State<LoanRepaymentsSheet> {
  final _amount = TextEditingController();
  DateTime? _dueDate;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    releaseFieldFocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  Future<void> _add() async {
    final amount = _amount.text.replaceAll(',', '').trim();
    if ((double.tryParse(amount) ?? 0) <= 0 || widget.saving) return;
    if (await widget.onAdd(amount, _dueDate) && mounted) {
      _amount.clear();
      setState(() => _dueDate = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'سلفة من ${loan.sourceName}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'تعديل السلفة',
                    onPressed: widget.onEdit,
                    icon: const Icon(LucideIcons.pencil, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('المتبقي: '),
                  MoneyAmountText(
                    amount: loan.outstandingAmount,
                    currency: widget.currency,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final repayment in loan.repayments)
                CheckboxListTile(
                  key: ValueKey('loan-repayment-${repayment.id}'),
                  contentPadding: EdgeInsets.zero,
                  value: repayment.isPaid,
                  onChanged: widget.saving || repayment.isCancelled
                      ? null
                      : (value) =>
                            widget.onTogglePaid(repayment, value ?? false),
                  title: MoneyAmountText(
                    amount: repayment.amount,
                    currency: widget.currency,
                  ),
                  subtitle: Text(
                    repayment.isPaid
                        ? 'سُدّد ${_date(repayment.paidAt)}'
                        : repayment.dueDate == null
                        ? 'بدون موعد'
                        : 'موعده ${_date(repayment.dueDate)}',
                  ),
                  secondary: repayment.isPaid
                      ? null
                      : IconButton(
                          tooltip: 'حذف دفعة السداد',
                          onPressed: widget.saving
                              ? null
                              : () => widget.onDelete(repayment),
                          icon: const Icon(LucideIcons.trash2, size: 18),
                        ),
                ),
              if (loan.repayments.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'قسّم السداد إلى دفعات بمواعيد لتصلك تذكيراتها.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('loan-repayment-amount'),
                      controller: _amount,
                      textAlign: TextAlign.right,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: const [MoneyInputFormatter()],
                      decoration: const InputDecoration(
                        hintText: 'مبلغ دفعة السداد',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(LucideIcons.calendar, size: 18),
                    label: Text(_dueDate == null ? 'الموعد' : _date(_dueDate)),
                  ),
                  IconButton.filledTonal(
                    key: const ValueKey('loan-repayment-add'),
                    tooltip: 'إضافة دفعة السداد',
                    onPressed: widget.saving ? null : _add,
                    icon: const Icon(LucideIcons.plus),
                  ),
                ],
              ),
              if (widget.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  widget.errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _date(DateTime? value) =>
      value == null ? '' : formatArabicCompactDate(value);
}
