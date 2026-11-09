import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/amount_words.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/utils/month_math.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/funding_source.dart';
import 'money_input_formatter.dart';
import 'money_widgets.dart' show shownMoney;

class FundingFormResult {
  const FundingFormResult({
    required this.kind,
    required this.sourceName,
    required this.amount,
    required this.status,
    this.sourcePhone,
    this.note,
    this.expectedAt,
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
      expectedAt = null,
      repayments = const [],
      delete = true;

  final String kind;
  final String sourceName;
  final String amount;
  final String status;
  final String? sourcePhone;
  final String? note;

  /// Promised money: the day it should arrive (D59: reminded the day
  /// before and on the day, «متأخر» once it passed); null for none.
  final DateTime? expectedAt;

  /// A new loan's repayments, added after it is saved.
  final List<({String amount, DateTime dueDate})> repayments;
  final bool delete;
}

/// The words the plan's owner uses for each kind of money: the groom's rafd
/// is the bride's gifts (JOURNEY_PROFILE.md).
String fundingKindChoice(String kind, JourneyProfile profile) => switch (kind) {
  FundingKind.savings => 'مدخراتي',
  FundingKind.familySupport => 'دعم من الأهل',
  FundingKind.gift => profile.plan('رفد ونقوط', 'هدايا ونقوط'),
  FundingKind.loan => 'سلفة',
  FundingKind.mahr => 'المهر',
  _ => 'غيره',
};

IconData fundingKindIcon(String kind) => switch (kind) {
  FundingKind.savings => LucideIcons.piggyBank,
  FundingKind.familySupport => LucideIcons.heartHandshake,
  FundingKind.gift => LucideIcons.gift,
  FundingKind.loan => LucideIcons.calendarClock,
  FundingKind.mahr => LucideIcons.heartHandshake,
  _ => LucideIcons.wallet,
};

/// A source's state as c05 tags it: «وصل», «موعود», or (D59, the server's
/// `isOverdue`) «متأخر» once a promise's day passed without it arriving.
Widget fundingStateTag(FundingSource source) {
  if (!source.isPledged) {
    return const JourneyTag(
      label: 'وصل',
      color: AarastV3Color.mint,
      soft: AarastV3Color.mintSoft,
    );
  }
  if (source.isOverdue) {
    return const JourneyTag(
      key: ValueKey('funding-overdue'),
      label: 'متأخر',
      color: AarastV3Color.danger,
      soft: AarastV3Color.dangerSoft,
    );
  }
  return const JourneyTag(
    label: 'موعود',
    color: AarastV3Color.lilac,
    soft: AarastV3Color.lilacSoft,
  );
}

/// c12 «مصدر فلوس»: what kind, from whom, how much, whether it arrived,
/// and, for a new loan, how it will be paid back. Tracking only: nothing is
/// moved.
class FundingSourceFormSheet extends StatefulWidget {
  const FundingSourceFormSheet({
    this.source,
    this.currency = 'YER',
    this.onSave,
    this.knownPeople = const [],
    super.key,
  });

  final FundingSource? source;
  final String currency;

  /// D108: names already in the plan (the family, who pays agreements),
  /// offered for family support and gifts so one person is written one
  /// way, and their money and their agreements are one line.
  final List<String> knownPeople;

  /// Saves what was typed: null once saved, or why not. The sheet closes
  /// only once it is saved, so a failure keeps everything typed. Without
  /// it the sheet only returns what was typed.
  final Future<String?> Function(FundingFormResult result)? onSave;

  @override
  State<FundingSourceFormSheet> createState() => _FundingSourceFormSheetState();
}

class _FundingSourceFormSheetState extends State<FundingSourceFormSheet> {
  // D108: a family source opens on who it is from, the name it is saved as.
  late final _name = TextEditingController(text: _nameOf(widget.source));

  static String? _nameOf(FundingSource? source) {
    if (source == null) return null;
    final person = source.contributorName?.trim();
    return FundingKind.namesPerson(source.kind) &&
            person != null &&
            person.isNotEmpty
        ? person
        : source.sourceName;
  }

  late final _phone = TextEditingController(text: widget.source?.sourcePhone);
  late final _amount = TextEditingController(
    text: formatMoneyInputValue(widget.source?.amount),
  );
  late final _note = TextEditingController(text: widget.source?.note);
  late String _kind = widget.source?.kind ?? FundingKind.familySupport;
  late bool _pledged = widget.source?.isPledged ?? false;

  /// Promised money's day (D59); kept when it arrives, as the record of
  /// when it was due.
  late DateTime? _expectedAt = widget.source?.expectedAt;
  late bool _showMore =
      (widget.source?.sourcePhone ?? '').isNotEmpty ||
      (widget.source?.note ?? '').isNotEmpty;

  /// How many payments a new loan is paid back in; 0 is «بعدين».
  int _repaymentCount = 0;
  DateTime _firstRepayment = addMonthsClamped(DateUtils.dateOnly(appNow()), 1);
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

  String _plain(num value) => shownMoney(
    context,
    compactMoneyParts(value, currencyCode: widget.currency).plainText,
  );

  Future<void> _pickFirstRepayment() async {
    releaseFieldFocus();
    final now = DateUtils.dateOnly(appNow());
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstRepayment,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
      locale: const Locale('ar'),
    );
    if (picked != null && mounted) setState(() => _firstRepayment = picked);
  }

  Future<void> _pickExpectedAt() async {
    releaseFieldFocus();
    final now = DateUtils.dateOnly(appNow());
    final current = _expectedAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: current == null || current.isBefore(now) ? now : current,
      // A promise already late keeps its day; a new one is today or later.
      firstDate: current != null && current.isBefore(now) ? current : now,
      lastDate: now.add(const Duration(days: 3650)),
      locale: const Locale('ar'),
    );
    if (picked != null && mounted) setState(() => _expectedAt = picked);
  }

  bool _saving = false;
  String? _failure;

  Future<void> _submit() async {
    if (_saving) return;
    setState(() {
      _nameError = _name.text.trim().isEmpty
          ? context.say('اكتب من مين', 'اكتبي من مين')
          : null;
      _amountError = _typedAmount <= 0
          ? context.say('اكتب كم', 'اكتبي كم')
          : null;
    });
    if (_nameError != null || _amountError != null) return;
    final result = FundingFormResult(
      kind: _kind,
      sourceName: _name.text.trim(),
      amount: '$_typedAmount',
      status: _pledged && !_isLoan
          ? FundingStatus.pledged
          : FundingStatus.received,
      sourcePhone: _phone.text,
      note: _note.text,
      expectedAt: _pledged && !_isLoan
          ? _expectedAt
          : widget.source?.expectedAt,
      repayments: _repayments,
    );
    final save = widget.onSave;
    if (save == null) {
      Navigator.pop(context, result);
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    final failure = await save(result);
    if (!mounted) return;
    if (failure == null) {
      Navigator.pop(context, result);
      return;
    }
    setState(() {
      _saving = false;
      _failure = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final amount = _typedAmount;
    final currencyLabel = currencyLabelAr(widget.currency);
    final repayments = _repayments;
    return JourneySheetBody(
      title: _editing ? 'تعديل المصدر' : 'مصدر فلوس',
      subtitle: context.say(
        'من وين بتجيب فلوس عرسك',
        'من وين بتجيبين فلوس عرسك',
      ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // The mahr is recorded by a06 and a mahr source keeps its kind
            // (D59, as the server rules): editing one shows only its kind.
            for (final kind
                in widget.source?.isMahr == true
                    ? const [FundingKind.mahr]
                    : FundingKind.all)
              JourneyChip(
                key: ValueKey('funding-kind-$kind'),
                label: fundingKindChoice(kind, context.journeyProfile),
                icon: fundingKindIcon(kind),
                selected: _kind == kind,
                onTap: () => setState(() => _kind = kind),
              ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x3),
        JourneyTextField(
          key: const ValueKey('funding-name'),
          label: _kind == FundingKind.savings ? 'اسمها' : 'من مين؟',
          hint: switch (_kind) {
            FundingKind.savings => 'مثلًا: مدخراتي',
            FundingKind.loan => 'مثلًا: خالي أحمد',
            _ => context.planWord('مثلًا: الوالد', 'مثلًا: الوالدة'),
          },
          controller: _name,
          icon: LucideIcons.user,
          errorText: _nameError,
          onChanged: (_) => setState(() => _nameError = null),
        ),
        if ((_kind == FundingKind.familySupport || _kind == FundingKind.gift) &&
            widget.knownPeople.isNotEmpty) ...[
          const SizedBox(height: AarastV3Space.x2),
          Wrap(
            spacing: AarastV3Space.x2,
            runSpacing: AarastV3Space.x2,
            children: [
              for (final (index, name) in widget.knownPeople.indexed)
                JourneyChip(
                  key: ValueKey('funding-person-$index'),
                  label: name,
                  icon: LucideIcons.user,
                  selected: _name.text.trim() == name,
                  onTap: () => setState(() {
                    _name.text = name;
                    _nameError = null;
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: AarastV3Space.x2),
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
          const SizedBox(height: AarastV3Space.x3),
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
              const SizedBox(width: AarastV3Space.x2),
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
          if (_pledged) ...[
            const SizedBox(height: AarastV3Space.x2),
            // D59: the day it should arrive; we remind the day before and
            // on the day, and it reads «متأخر» once the day passes.
            JourneyPickerField(
              key: const ValueKey('funding-expected-at'),
              label: 'متى توصل؟',
              value: _expectedAt == null
                  ? 'ما تحدد'
                  : formatArabicDayMonth(_expectedAt!),
              icon: LucideIcons.calendarDays,
              helper: 'نذكّرك قبلها بيوم ويومها',
              onTap: _pickExpectedAt,
            ),
          ],
        ],
        if (_isLoan && !_editing) ...[
          const SizedBox(height: AarastV3Space.x3),
          _label(context.say('كيف بترجعها؟', 'كيف بترجعينها؟')),
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
            const SizedBox(height: AarastV3Space.x2),
            JourneyPickerField(
              key: const ValueKey('funding-first-repayment'),
              label: _repaymentCount == 1
                  ? context.say('متى ترجعها؟', 'متى ترجعينها؟')
                  : 'أول دفعة',
              value: formatArabicDayMonth(_firstRepayment),
              icon: LucideIcons.calendarDays,
              helper: _repaymentCount == 1 ? null : 'وبعدها كل شهر',
              onTap: _pickFirstRepayment,
            ),
          ],
          if (repayments.length > 1) ...[
            const SizedBox(height: AarastV3Space.x2),
            JourneyBox(
              key: const ValueKey('funding-repayment-summary'),
              padding: const EdgeInsets.all(AarastV3Space.x3),
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
        const SizedBox(height: AarastV3Space.x2),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: JourneyTextAction(
            label: _showMore ? 'أقل' : 'تفاصيل أكثر',
            icon: _showMore ? LucideIcons.chevronUp : LucideIcons.chevronDown,
            color: context.accent.primary,
            onPressed: () => setState(() => _showMore = !_showMore),
          ),
        ),
        if (_showMore) ...[
          JourneyTextField(
            label: context.say('رقمه (لو تبي)', 'رقمه (لو تبين)'),
            controller: _phone,
            icon: LucideIcons.phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyTextField(label: 'ملاحظة', controller: _note),
        ],
        if (_failure != null) ...[
          const SizedBox(height: AarastV3Space.x3),
          JourneyNote(
            key: const ValueKey('funding-save-failure'),
            text: _failure!,
            icon: LucideIcons.alertCircle,
            color: AarastV3Color.danger,
            soft: AarastV3Color.dangerSoft,
          ),
        ],
        const SizedBox(height: AarastV3Space.x4),
        JourneyButton(
          key: const ValueKey('funding-save'),
          label: 'حفظ',
          expand: true,
          large: true,
          loading: _saving,
          onPressed: _saving ? null : _submit,
        ),
        if (_editing) ...[
          const SizedBox(height: AarastV3Space.x1),
          Center(
            child: JourneyTextAction(
              key: const ValueKey('funding-delete'),
              label: context.say('شيل المصدر', 'شيلي المصدر'),
              color: AarastV3Color.danger,
              onPressed: () =>
                  Navigator.pop(context, const FundingFormResult.delete()),
            ),
          ),
        ],
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AarastV3Space.x2),
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
