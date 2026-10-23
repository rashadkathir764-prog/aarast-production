import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/amount_words.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/utils/month_math.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/funding_source.dart';
import 'money_input_formatter.dart';

class FundingFormResult {
  const FundingFormResult({
    required this.kind,
    required this.sourceName,
    required this.amount,
    required this.status,
    this.sourcePhone,
    this.note,
    this.repayments = const [],
    this.delete = false,
  });

  const FundingFormResult.delete()
    : kind = '',
      sourceName = '',
      amount = '',
      status = '',
      sourcePhone = null,
      note = null,
      repayments = const [],
      delete = true;

  final String kind;
  final String sourceName;
  final String amount;
  final String status;
  final String? sourcePhone;
  final String? note;

  /// A new loan's repayments, added after it is saved.
  final List<({String amount, DateTime dueDate})> repayments;
  final bool delete;
}

/// The words a groom uses for each kind of money.
String fundingKindChoice(String kind) => switch (kind) {
  FundingKind.savings => 'مدخراتي',
  FundingKind.familySupport => 'دعم من الأهل',
  FundingKind.gift => 'رفد ونقوط',
  FundingKind.loan => 'سلفة',
  _ => 'غيره',
};

IconData fundingKindIcon(String kind) => switch (kind) {
  FundingKind.savings => LucideIcons.piggyBank,
  FundingKind.familySupport => LucideIcons.heartHandshake,
  FundingKind.gift => LucideIcons.gift,
  FundingKind.loan => LucideIcons.calendarClock,
  _ => LucideIcons.wallet,
};

/// c12 «مصدر فلوس»: what kind, from whom, how much, whether it arrived,
/// and, for a new loan, how it will be paid back. Tracking only: nothing is
/// moved.
class FundingSourceFormSheet extends StatefulWidget {
  const FundingSourceFormSheet({this.source, this.currency = 'YER', super.key});

  final FundingSource? source;
  final String currency;

  @override
  State<FundingSourceFormSheet> createState() => _FundingSourceFormSheetState();
}

class _FundingSourceFormSheetState extends State<FundingSourceFormSheet> {
  late final _name = TextEditingController(text: widget.source?.sourceName);
  late final _phone = TextEditingController(text: widget.source?.sourcePhone);
  late final _amount = TextEditingController(
    text: formatMoneyInputValue(widget.source?.amount),
  );
  late final _note = TextEditingController(text: widget.source?.note);
  late String _kind = widget.source?.kind ?? FundingKind.familySupport;
  late bool _pledged = widget.source?.isPledged ?? false;
  late bool _showMore =
      (widget.source?.sourcePhone ?? '').isNotEmpty ||
      (widget.source?.note ?? '').isNotEmpty;

  /// How many payments a new loan is paid back in; 0 is «بعدين».
  int _repaymentCount = 0;
  DateTime _firstRepayment = addMonthsClamped(
    DateUtils.dateOnly(DateTime.now()),
    1,
  );
  String? _nameError;
  String? _amountError;

  bool get _editing => widget.source != null;
  bool get _isLoan => _kind == FundingKind.loan;
  int get _typedAmount =>
      int.tryParse(_amount.text.replaceAll(',', '').trim()) ?? 0;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  List<({String amount, DateTime dueDate})> get _repayments {
    final total = _typedAmount;
    final count = _repaymentCount;
    if (_editing || !_isLoan || count <= 0 || total <= 0) return const [];
    final each = total ~/ count;
    return [
      for (var index = 0; index < count; index++)
        (
          // The last payment carries what does not divide evenly.
          amount: '${index == count - 1 ? total - each * (count - 1) : each}',
          dueDate: addMonthsClamped(_firstRepayment, index),
        ),
    ];
  }

  String _plain(num value) =>
      compactMoneyParts(value, currencyCode: widget.currency).plainText;

  Future<void> _pickFirstRepayment() async {
    releaseFieldFocus();
    final now = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstRepayment,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
      locale: const Locale('ar'),
    );
    if (picked != null && mounted) setState(() => _firstRepayment = picked);
  }

  void _submit() {
    setState(() {
      _nameError = _name.text.trim().isEmpty ? 'اكتب من مين' : null;
      _amountError = _typedAmount <= 0 ? 'اكتب كم' : null;
    });
    if (_nameError != null || _amountError != null) return;
    Navigator.pop(
      context,
      FundingFormResult(
        kind: _kind,
        sourceName: _name.text.trim(),
        amount: '$_typedAmount',
        status: _pledged && !_isLoan
            ? FundingStatus.pledged
            : FundingStatus.received,
        sourcePhone: _phone.text,
        note: _note.text,
        repayments: _repayments,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = _typedAmount;
    final currencyLabel = currencyLabelAr(widget.currency);
    final repayments = _repayments;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              _editing ? 'تعديل المصدر' : 'مصدر فلوس',
              style: JourneyType.of(
                JourneyType.title,
                weight: JourneyType.bold,
              ),
            ),
          ),
          Text(
            'من وين بتجيب فلوس عرسك',
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in FundingKind.all)
                JourneyChip(
                  key: ValueKey('funding-kind-$kind'),
                  label: fundingKindChoice(kind),
                  icon: fundingKindIcon(kind),
                  selected: _kind == kind,
                  onTap: () => setState(() => _kind = kind),
                ),
            ],
          ),
          const SizedBox(height: 14),
          JourneyTextField(
            key: const ValueKey('funding-name'),
            label: _kind == FundingKind.savings ? 'اسمها' : 'من مين؟',
            hint: switch (_kind) {
              FundingKind.savings => 'مثلًا: مدخراتي',
              FundingKind.loan => 'مثلًا: خالي أحمد',
              _ => 'مثلًا: الوالد',
            },
            controller: _name,
            icon: LucideIcons.user,
            errorText: _nameError,
            onChanged: (_) => setState(() => _nameError = null),
          ),
          const SizedBox(height: 10),
          JourneyTextField(
            key: const ValueKey('funding-amount'),
            label: 'كم؟',
            controller: _amount,
            large: true,
            keyboardType: TextInputType.number,
            inputFormatters: const [MoneyInputFormatter()],
            suffix: currencyLabel,
            errorText: _amountError,
            helper: amount <= 0
                ? null
                : amountInWords(amount, currency: currencyLabel),
            onChanged: (_) => setState(() => _amountError = null),
          ),
          if (!_isLoan) ...[
            const SizedBox(height: 14),
            _label('وصلت ولا موعود؟'),
            Row(
              children: [
                Expanded(
                  child: JourneyChip(
                    key: const ValueKey('funding-received'),
                    label: 'وصلت',
                    selected: !_pledged,
                    onTap: () => setState(() => _pledged = false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: JourneyChip(
                    key: const ValueKey('funding-pledged'),
                    label: 'موعود',
                    selected: _pledged,
                    onTap: () => setState(() => _pledged = true),
                  ),
                ),
              ],
            ),
          ],
          if (_isLoan && !_editing) ...[
            const SizedBox(height: 14),
            _label('كيف بترجعها؟'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final count in const [0, 1, 2, 3, 4, 6])
                  JourneyChip(
                    key: ValueKey('funding-repayments-$count'),
                    label: count == 0
                        ? 'بعدين'
                        : arabicCount(
                            count,
                            one: 'دفعة وحدة',
                            two: 'دفعتين',
                            few: 'دفعات',
                            many: 'دفعة',
                          ),
                    selected: _repaymentCount == count,
                    onTap: () => setState(() => _repaymentCount = count),
                  ),
              ],
            ),
            if (_repaymentCount > 0) ...[
              const SizedBox(height: 10),
              JourneyPickerField(
                key: const ValueKey('funding-first-repayment'),
                label: _repaymentCount == 1 ? 'متى ترجعها؟' : 'أول دفعة',
                value: formatArabicDayMonth(_firstRepayment),
                icon: LucideIcons.calendarDays,
                helper: _repaymentCount == 1 ? null : 'وبعدها كل شهر',
                onTap: _pickFirstRepayment,
              ),
            ],
            if (repayments.length > 1) ...[
              const SizedBox(height: 10),
              JourneyBox(
                key: const ValueKey('funding-repayment-summary'),
                padding: const EdgeInsets.all(14),
                child: Text(
                  '${_plain(int.parse(repayments.first.amount))} كل شهر · تبدأ ${arabicMonthName(_firstRepayment.month)}',
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: JourneyTextAction(
              label: _showMore ? 'أقل' : 'تفاصيل أكثر',
              icon: _showMore ? LucideIcons.chevronUp : LucideIcons.chevronDown,
              color: AarastV3Color.primary,
              onPressed: () => setState(() => _showMore = !_showMore),
            ),
          ),
          if (_showMore) ...[
            JourneyTextField(
              label: 'رقمه (لو تبي)',
              controller: _phone,
              icon: LucideIcons.phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 10),
            JourneyTextField(label: 'ملاحظة', controller: _note),
          ],
          const SizedBox(height: 16),
          JourneyButton(
            key: const ValueKey('funding-save'),
            label: 'حفظ',
            expand: true,
            large: true,
            onPressed: _submit,
          ),
          if (_editing) ...[
            const SizedBox(height: 4),
            Center(
              child: JourneyTextAction(
                key: const ValueKey('funding-delete'),
                label: 'شيل المصدر',
                color: AarastV3Color.danger,
                onPressed: () =>
                    Navigator.pop(context, const FundingFormResult.delete()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: JourneyType.of(
        JourneyType.small,
        weight: JourneyType.bold,
        color: AarastV3Color.textMuted,
      ),
    ),
  );
}
