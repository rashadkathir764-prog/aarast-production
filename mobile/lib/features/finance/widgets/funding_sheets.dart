import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/funding_source.dart';
import '../models/wedding_cost.dart' show moneyValue;
import 'money_input_formatter.dart';
import 'money_widgets.dart' show shownMoney;

/// c13 «السلفة»: what is still owed, the repayments in order, and one
/// button for the next one. Loan reminders are a fixed server job, so
/// there is no per-loan reminder switch.
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

  String _plain(Object? value) => shownMoney(
    context,
    compactMoneyParts(
      moneyValue(value),
      currencyCode: widget.currency,
    ).plainText,
  );

  Future<void> _pickDate() async {
    releaseFieldFocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 10),
      locale: const Locale('ar'),
    );
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  String? _amountError;

  Future<void> _add() async {
    final amount = _amount.text.replaceAll(',', '').trim();
    if (widget.saving) return;
    // An empty or zero amount says so instead of doing nothing.
    if ((int.tryParse(amount) ?? 0) <= 0) {
      setState(
        () => _amountError = context.say('اكتب كم الدفعة', 'اكتبي كم الدفعة'),
      );
      return;
    }
    if (await widget.onAdd(amount, _dueDate) && mounted) {
      _amount.clear();
      setState(() => _dueDate = null);
    }
  }

  String _line(LoanRepayment repayment, DateTime today) {
    if (repayment.isPaid) {
      final paidAt = repayment.paidAt;
      final paid = context.say('دفعتها', 'دفعتيها');
      return paidAt == null ? paid : '${formatArabicDayMonth(paidAt)} · $paid';
    }
    final due = repayment.dueDate;
    if (due == null) return 'بدون موعد';
    final days = DateUtils.dateOnly(due).difference(today).inDays;
    final date = formatArabicDayMonth(due);
    if (days < 0) return '$date · متأخرة';
    if (days == 0) return '$date · اليوم';
    if (days <= 30) {
      return '$date · بعد ${arabicCount(days, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم')}';
    }
    return date;
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final today = DateUtils.dateOnly(DateTime.now());
    final repayments = [
      for (final repayment in loan.repayments)
        if (!repayment.isCancelled) repayment,
    ];
    final paidCount = repayments.where((item) => item.isPaid).length;
    final nextIndex = repayments.indexWhere((item) => !item.isPaid);
    final dueDates = [
      for (final repayment in repayments)
        if (repayment.dueDate != null) repayment.dueDate!,
    ]..sort();
    final allDated =
        repayments.isNotEmpty && dueDates.length == repayments.length;
    final owed = moneyValue(loan.outstandingAmount ?? loan.amount);

    return JourneySheetBody(
      title: 'سلفة ${loan.sourceName}',
      subtitle: 'خاصة بك',
      trailing: JourneyRoundButton(
        icon: LucideIcons.pencil,
        tooltip: 'تعديل السلفة',
        onPressed: widget.onEdit,
      ),
      children: [
        JourneyBox(
          key: const ValueKey('loan-owed'),
          color: context.accent.primary,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                owed > 0 ? 'باقي عليك' : context.say('خلصت منها', 'خلصتِ منها'),
                style: JourneyType.of(
                  JourneyType.small,
                  color: context.accent.onPrimaryMuted,
                ),
              ),
              if (owed > 0)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    shownMoney(
                      context,
                      '${formatMoneyInputValue(owed.round())} ${currencyLabelAr(widget.currency)}',
                    ),
                    style: JourneyType.of(
                      JourneyType.display,
                      weight: JourneyType.bold,
                      color: AarastV3Color.onPrimary,
                    ),
                  ),
                ),
              if (repayments.isNotEmpty) ...[
                const SizedBox(height: 12),
                JourneySegments(
                  total: repayments.length,
                  done: paidCount,
                  filled: AarastV3Color.onPrimary,
                  current: AarastV3Color.saffron,
                  empty: context.accent.onPrimaryMuted,
                ),
              ],
              if (allDated && owed > 0) ...[
                const SizedBox(height: 10),
                Text(
                  '${context.say('تخلص', 'تخلصين')} منها في ${arabicMonthName(dueDates.last.month)} إن شاء الله',
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                    color: AarastV3Color.onPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        const JourneySectionTitle('السداد'),
        if (repayments.isEmpty)
          Text(
            'قسّم السداد على دفعات بمواعيد، ونذكّرك فيها.',
            style: JourneyType.of(
              JourneyType.body,
              color: AarastV3Color.textMuted,
            ),
          )
        else
          JourneyBox(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              children: [
                for (var index = 0; index < repayments.length; index++)
                  _RepaymentRow(
                    key: ValueKey('loan-repayment-${repayments[index].id}'),
                    number: index + 1,
                    line: _line(repayments[index], today),
                    amount: _plain(repayments[index].amount),
                    paid: repayments[index].isPaid,
                    current: index == nextIndex,
                    onToggle: widget.saving
                        ? null
                        : () => widget.onTogglePaid(
                            repayments[index],
                            !repayments[index].isPaid,
                          ),
                    onDelete: widget.saving || repayments[index].isPaid
                        ? null
                        : () => widget.onDelete(repayments[index]),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: JourneyTextField(
                key: const ValueKey('loan-repayment-amount'),
                label: context.say('أضف دفعة سداد', 'أضيفي دفعة سداد'),
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: const [MoneyInputFormatter()],
                suffix: currencyLabelAr(widget.currency),
                errorText: _amountError,
                onChanged: (_) {
                  if (_amountError != null) {
                    setState(() => _amountError = null);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 22),
              child: JourneyRoundButton(
                icon: LucideIcons.calendarDays,
                tooltip: _dueDate == null
                    ? 'موعدها'
                    : formatArabicDayMonth(_dueDate!),
                onPressed: _pickDate,
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 22),
              child: JourneyRoundButton(
                key: const ValueKey('loan-repayment-add'),
                icon: LucideIcons.plus,
                tooltip: context.say('أضف دفعة السداد', 'أضيفي دفعة السداد'),
                onPressed: widget.saving ? null : _add,
              ),
            ),
          ],
        ),
        if (_dueDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'موعدها ${formatArabicDayMonth(_dueDate!)}',
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
        if (widget.errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorMessage!,
            style: JourneyType.of(
              JourneyType.small,
              weight: JourneyType.bold,
              color: AarastV3Color.danger,
            ),
          ),
        ],
        if (nextIndex >= 0) ...[
          const SizedBox(height: 16),
          JourneyButton(
            key: const ValueKey('loan-pay-next'),
            label:
                '${context.say('سجّل', 'سجّلي')} الدفعة ${arabicOrdinal(nextIndex)}',
            expand: true,
            large: true,
            loading: widget.saving,
            onPressed: widget.saving
                ? null
                : () => widget.onTogglePaid(repayments[nextIndex], true),
          ),
        ],
      ],
    );
  }
}

class _RepaymentRow extends StatelessWidget {
  const _RepaymentRow({
    required this.number,
    required this.line,
    required this.amount,
    required this.paid,
    required this.current,
    required this.onToggle,
    required this.onDelete,
    super.key,
  });

  final int number;
  final String line;
  final String amount;
  final bool paid;
  final bool current;
  final VoidCallback? onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onToggle != null,
      checked: paid,
      label: '$line، $amount',
      onTap: onToggle,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onToggle ?? () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: paid
                      ? AarastV3Color.mint
                      : current
                      ? AarastV3Color.brandAccentSoft
                      : AarastV3Color.paperQuiet,
                  border: current && !paid
                      ? Border.all(color: AarastV3Color.saffron, width: 2)
                      : null,
                ),
                child: paid
                    ? const Icon(
                        LucideIcons.check,
                        size: 16,
                        color: AarastV3Color.onPrimary,
                      )
                    : Text(
                        '$number',
                        style: JourneyType.of(
                          JourneyType.small,
                          weight: JourneyType.bold,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  line,
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                    color: paid ? AarastV3Color.textMuted : AarastV3Color.ink,
                  ),
                ),
              ),
              Text(
                amount,
                style: JourneyType.of(
                  JourneyType.body,
                  weight: JourneyType.bold,
                  color: paid ? AarastV3Color.textMuted : AarastV3Color.ink,
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: context.say('شيل دفعة السداد', 'شيلي دفعة السداد'),
                  onPressed: onDelete,
                  icon: const Icon(
                    LucideIcons.trash2,
                    size: 18,
                    color: AarastV3Color.textFaint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the person answered about promised money.
enum PledgeAnswer { arrived, notYet, notComing, edit }

/// x08 «وصلت فلوس …؟»: promised money arrived, not yet, or is not coming.
/// There is no partial arrival (the server keeps one amount per source).
class PledgeCheckSheet extends StatefulWidget {
  const PledgeCheckSheet({
    required this.source,
    required this.currency,
    this.availableCash,
    super.key,
  });

  final FundingSource source;
  final String currency;

  /// What the owner has in hand now, from the money summary; null hides the
  /// before and after.
  final Object? availableCash;

  @override
  State<PledgeCheckSheet> createState() => _PledgeCheckSheetState();
}

class _PledgeCheckSheetState extends State<PledgeCheckSheet> {
  PledgeAnswer _answer = PledgeAnswer.arrived;

  String _plain(num value) => shownMoney(
    context,
    compactMoneyParts(value, currencyCode: widget.currency).plainText,
  );

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final amount = moneyValue(source.amount);
    final cash = widget.availableCash == null
        ? null
        : moneyValue(widget.availableCash);
    return JourneySheetBody(
      title: 'وصلت فلوس ${source.sourceName}؟',
      subtitle: 'وعدك بـ ${_plain(amount)}',
      children: [
        for (final (answer, title, line, icon, color) in const [
          (
            PledgeAnswer.arrived,
            'وصلت كلها',
            'تنتقل من موعود إلى معك',
            LucideIcons.checkCircle2,
            AarastV3Color.mint,
          ),
          (
            PledgeAnswer.notYet,
            'لسا',
            'تبقى موعودة',
            LucideIcons.clock,
            AarastV3Color.brandAccentStrong,
          ),
          (
            PledgeAnswer.notComing,
            'ما بتوصل',
            'تنشال من الموعود',
            LucideIcons.xCircle,
            AarastV3Color.danger,
          ),
        ]) ...[
          JourneyChoiceCard(
            key: ValueKey('pledge-${answer.name}'),
            title: title,
            subtitle: line,
            leading: Icon(icon, color: color),
            selected: _answer == answer,
            onTap: () => setState(() => _answer = answer),
          ),
          const SizedBox(height: 8),
        ],
        if (_answer == PledgeAnswer.arrived && cash != null) ...[
          JourneyBox(
            key: const ValueKey('pledge-cash-after'),
            color: context.accent.primarySoft,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'معك يصير',
                    style: JourneyType.of(
                      JourneyType.body,
                      color: context.accent.primary,
                    ),
                  ),
                ),
                // Two amounts in a narrow box: each shrinks to fit (320,
                // large text) instead of overflowing the row.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _plain(cash),
                      style: JourneyType.of(
                        JourneyType.body,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    LucideIcons.arrowLeft,
                    size: 16,
                    color: context.accent.primary,
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _plain(cash + amount),
                      style: JourneyType.of(
                        JourneyType.bodyLarge,
                        weight: JourneyType.bold,
                        color: context.accent.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        JourneyButton(
          key: const ValueKey('pledge-confirm'),
          label: 'تمام',
          expand: true,
          large: true,
          onPressed: () => Navigator.pop(context, _answer),
        ),
        Center(
          child: JourneyTextAction(
            key: const ValueKey('pledge-edit'),
            label: context.say('عدّل المصدر', 'عدّلي المصدر'),
            color: context.accent.primary,
            onPressed: () => Navigator.pop(context, PledgeAnswer.edit),
          ),
        ),
      ],
    );
  }
}
