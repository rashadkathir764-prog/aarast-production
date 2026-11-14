import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/amount_words.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../finance/finance_api.dart'
    show
        MahrBudgetChoice,
        MoneyInputFormatter,
        formatMoneyInputValue,
        mahrChoiceOnScreen,
        revealMahrChoice;
import '../models/wedding_plan.dart';

/// w10 «بيانات الخطة»: the plan's name, its day and the wedding budget.
/// A set day changes only through g03 «تأجيل العرس»; a plan without one
/// picks it here. The place and the currency stay as they were made (D27);
/// a plan made without a city sets it here, as a plan without a day does
/// (RA-MO-155: «أكمل موقع الزفاف» opened this page and it had no field).
/// A typed or stored amount: «7,000,000» or «7000000.00».
num _amount(String text) => num.tryParse(text.replaceAll(',', '').trim()) ?? 0;

class PlanDetailsView extends StatefulWidget {
  const PlanDetailsView({
    required this.plan,
    required this.budgetTotal,
    required this.onBack,
    required this.onSave,
    this.onChangeDate,
    this.repickStoredDay = false,
    this.onArchive,
    this.budgetIncludesMahr,
    this.mahrTotal,
    super.key,
  });

  final WeddingPlan plan;

  /// The budget as stored, or null before it is known.
  final String? budgetTotal;
  final VoidCallback onBack;

  /// D114: whether the groom's budget holds his mahr, as saved; null where
  /// it is not asked (a bride's plan, a reader who may not change it, or
  /// before the money is read).
  final bool? budgetIncludesMahr;

  /// The groom's recorded mahr, so the choice speaks in his numbers.
  final num? mahrTotal;

  /// Saves what changed: a new name, a first day, a new budget, the mahr's
  /// place in it (null for what did not change). True once everything saved.
  final Future<bool> Function({
    String? title,
    DateTime? firstDay,
    String? budgetTotal,
    String? city,
    bool? budgetIncludesMahr,
  })
  onSave;

  /// Opens g03 for a plan that has a day.
  final VoidCallback? onChangeDate;

  /// A plan kept on the phone has no g03: its day is picked again here and
  /// saved with the rest. Without g03 or this, a stored day only reads.
  final bool repickStoredDay;
  final VoidCallback? onArchive;

  @override
  State<PlanDetailsView> createState() => _PlanDetailsViewState();
}

class _PlanDetailsViewState extends State<PlanDetailsView> {
  late final TextEditingController _title;
  late final TextEditingController _budget;
  final _city = TextEditingController();

  /// The plan was made without a city: it is set here once.
  bool get _cityMissing => (widget.plan.city ?? '').trim().isEmpty;

  bool get _cityChanged => _cityMissing && _city.text.trim().isNotEmpty;
  DateTime? _firstDay;
  bool _saving = false;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.plan.title);
    _budget = TextEditingController(text: _budgetText(widget.budgetTotal));
  }

  @override
  void didUpdateWidget(covariant PlanDetailsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The stored budget arrives after the screen opens.
    if (oldWidget.budgetTotal != widget.budgetTotal &&
        _amount(_budget.text) == _amount(oldWidget.budgetTotal ?? '')) {
      _budget.text = _budgetText(widget.budgetTotal);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _budget.dispose();
    _city.dispose();
    super.dispose();
  }

  static String _budgetText(String? total) {
    final value = _amount(total ?? '');
    return value > 0 ? formatMoneyInputValue(value.round().toString()) : '';
  }

  String get _cleanBudget => _budget.text.replaceAll(',', '').trim();

  bool get _titleChanged => _title.text.trim() != widget.plan.title.trim();

  bool get _budgetChanged =>
      _amount(_cleanBudget) != _amount(widget.budgetTotal ?? '');

  /// D114: the answer picked here; null until he picks one.
  bool? _inside;

  bool get _insideChanged =>
      _inside != null &&
      widget.budgetIncludesMahr != null &&
      _inside != widget.budgetIncludesMahr;

  bool get _dirty =>
      _titleChanged ||
      _budgetChanged ||
      _firstDay != null ||
      _cityChanged ||
      _insideChanged;

  Future<void> _pickFirstDay() async {
    releaseFieldFocus();
    final now = appNow();
    final today = DateTime(now.year, now.month, now.day);
    final current = _firstDay ?? widget.plan.weddingDate;
    final picked = await showDatePicker(
      context: context,
      // A day already gone cannot open the picker; it starts from today.
      initialDate: current == null
          ? now.add(const Duration(days: 90))
          : (current.isBefore(today) ? today : current),
      firstDate: today,
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null || !mounted) return;
    setState(() => _firstDay = picked);
  }

  /// The choice under the budget is seen once before a new budget is
  /// saved: with the keyboard up on a small phone it sat under it. Only
  /// then: a save of the name or the day has nothing to do with it and
  /// goes through at the first press. A press spent on showing it says so
  /// ([_choiceAsked]).
  final _choiceKey = GlobalKey();
  final _budgetKey = GlobalKey();
  bool _choiceSeen = false;
  bool _choiceAsked = false;

  Future<void> _save() async {
    if (widget.budgetIncludesMahr != null &&
        _budgetChanged &&
        _inside == null &&
        !_choiceSeen) {
      _choiceSeen = true;
      if (!mahrChoiceOnScreen(_choiceKey)) {
        setState(() => _choiceAsked = true);
        revealMahrChoice(_choiceKey, near: _budgetKey);
        return;
      }
    }
    releaseFieldFocus();
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(
        () => _titleError = context.say('اكتب اسم للخطة', 'اكتبي اسم للخطة'),
      );
      return;
    }
    setState(() => _saving = true);
    final saved = await widget.onSave(
      title: _titleChanged ? title : null,
      firstDay: _firstDay,
      budgetTotal: _budgetChanged
          ? (_cleanBudget.isEmpty ? '' : '${_amount(_cleanBudget).round()}')
          : null,
      city: _cityChanged ? _city.text.trim() : null,
      budgetIncludesMahr: _insideChanged ? _inside : null,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (saved) {
        _firstDay = null;
        _inside = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final day = _firstDay ?? plan.weddingDate;
    final hasStoredDay = plan.weddingDate != null;
    final currency = currencyLabelAr(plan.currency);
    final total = _amount(_cleanBudget);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: AarastV3Density.pageInsets,
            children: [
              JourneySubHeader(title: 'بيانات الخطة', onBack: widget.onBack),
              JourneyTextField(
                key: const ValueKey('plan-details-title'),
                label: 'اسم الخطة',
                controller: _title,
                maxLength: 80,
                errorText: _titleError,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() => _titleError = null),
              ),
              const SizedBox(height: AarastV3Space.x3),
              JourneyPickerField(
                key: const ValueKey('plan-details-day'),
                label: 'موعد العرس',
                icon: LucideIcons.calendarDays,
                // w10 «الخميس 21 يناير 2027», without the comma.
                value: day == null
                    ? null
                    : '${formatArabicWeekday(day)} '
                          '${formatArabicDate(day, includeWeekday: false)}',
                placeholder: context.say('اختر اليوم', 'اختاري اليوم'),
                onTap: !hasStoredDay
                    ? _pickFirstDay
                    : widget.onChangeDate ??
                          (widget.repickStoredDay ? _pickFirstDay : null),
              ),
              if (hasStoredDay && widget.onChangeDate != null) ...[
                const SizedBox(height: AarastV3Space.x2),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: JourneyChip(
                    key: const ValueKey('plan-details-change-day'),
                    label: context.say('غيّر الموعد', 'غيّري الموعد'),
                    selected: true,
                    onTap: widget.onChangeDate,
                  ),
                ),
              ],
              if (_cityMissing) ...[
                const SizedBox(height: AarastV3Space.x3),
                JourneyTextField(
                  key: const ValueKey('plan-details-city'),
                  label: 'مدينة العرس',
                  hint: 'مثلًا: صنعاء',
                  controller: _city,
                  maxLength: 80,
                  icon: LucideIcons.mapPin,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: AarastV3Space.x3),
              // D114: the mahr's place in it is his choice, under the field.
              KeyedSubtree(
                key: _budgetKey,
                child: JourneyTextField(
                  key: const ValueKey('plan-details-budget'),
                  label: 'ميزانيتك',
                  hint: 'مثلًا: 3,000,000',
                  controller: _budget,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyInputFormatter()],
                  suffix: currency,
                  helper: total > 0
                      ? amountInWords(total.round(), currency: currency)
                      : null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (widget.budgetIncludesMahr case final saved?) ...[
                const SizedBox(height: AarastV3Space.x4),
                MahrBudgetChoice(
                  key: _choiceKey,
                  inside: _inside ?? saved,
                  budget: total,
                  mahr: widget.mahrTotal,
                  currency: plan.currency,
                  asksBeforeGoingOn: _choiceAsked,
                  onChanged: _saving
                      ? null
                      : (inside) => setState(() {
                          _inside = inside;
                          _choiceAsked = false;
                        }),
                ),
              ],
              if (hasStoredDay) ...[
                const SizedBox(height: AarastV3Space.x4),
                JourneyNote(
                  icon: LucideIcons.calendarClock,
                  text:
                      'لو ${context.say('غيّرت', 'غيّرتِ')} الموعد، المهام '
                      'تنتقل معه، والدفعات تبقى على مواعيدها.',
                ),
              ],
              if (widget.onArchive != null) ...[
                const SizedBox(height: AarastV3Space.x4),
                Center(
                  child: JourneyTextAction(
                    key: const ValueKey('plan-details-archive'),
                    label: context.say(
                      'حط الخطة في الذكريات',
                      'حطي الخطة في الذكريات',
                    ),
                    color: AarastV3Color.textMuted,
                    onPressed: widget.onArchive,
                  ),
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AarastV3Space.x4,
              AarastV3Space.x2,
              AarastV3Space.x4,
              AarastV3Space.x4,
            ),
            child: JourneyButton(
              key: const ValueKey('plan-details-save'),
              label: 'حفظ',
              large: true,
              expand: true,
              loading: _saving,
              onPressed: _dirty && !_saving ? _save : null,
            ),
          ),
        ),
      ],
    );
  }
}
