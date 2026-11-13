part of 'cost_form_screen.dart';

// c10 «كيف بتدفع؟»: what is paid now and which payment dates the new
// agreement gets. The dates are created one by one after the agreement is
// saved (the server has no single call for both), and «الباقي يوم العرس»
// is saved as the wedding's fixed date (C3).

enum _PayPlan { later, full, depositRest, instalments }

extension on _PayPlan {
  String labelFor(JourneyProfile profile) => switch (this) {
    _PayPlan.later => 'بعدين',
    _PayPlan.full => profile.say('دفعتها كاملة', 'دفعتيها كاملة'),
    _PayPlan.depositRest => 'عربون والباقي يوم العرس',
    _PayPlan.instalments => 'على دفعات',
  };
}

/// One payment the plan makes: paid today, or a date still to pay.
class _PlannedLine {
  const _PlannedLine({required this.amount, required this.label, this.dueDate});

  final int amount;
  final String label;

  /// Null for what is paid today.
  final DateTime? dueDate;

  bool get paidNow => dueDate == null;
}

/// The lines of [plan] for [total], or none when something is missing.
List<_PlannedLine> _planLines({
  required _PayPlan plan,
  required int total,
  required int deposit,
  required int count,
  required DateTime? restDue,
  required DateTime firstDue,
  DateTime? paidOn,
}) {
  if (total <= 0) return const [];
  // RA-MO-174: the payment made with the agreement is dated by the server on
  // the agreement's day when it has one; the preview said «اليوم» anyway.
  final today = DateUtils.dateOnly(appNow());
  final paidDay = paidOn == null || DateUtils.isSameDay(paidOn, today)
      ? 'اليوم'
      : formatArabicDayMonth(paidOn);
  switch (plan) {
    case _PayPlan.later:
      return const [];
    case _PayPlan.full:
      return [_PlannedLine(amount: total, label: 'كاملة · $paidDay')];
    case _PayPlan.depositRest:
      if (deposit <= 0 || deposit >= total || restDue == null) return const [];
      return [
        _PlannedLine(amount: deposit, label: 'العربون · $paidDay'),
        _PlannedLine(
          amount: total - deposit,
          label: 'الباقي · ${formatArabicDayMonth(restDue)}',
          dueDate: restDue,
        ),
      ];
    case _PayPlan.instalments:
      if (deposit < 0 || deposit >= total || count < 2) return const [];
      final rest = total - deposit;
      final each = rest ~/ count;
      return [
        if (deposit > 0)
          _PlannedLine(amount: deposit, label: 'العربون · $paidDay'),
        for (var index = 0; index < count; index++)
          _PlannedLine(
            // The last payment carries what does not divide evenly.
            amount: index == count - 1 ? rest - each * (count - 1) : each,
            label:
                'الدفعة ${index + 1} · ${formatArabicDayMonth(addMonthsClamped(firstDue, index))}',
            dueDate: addMonthsClamped(firstDue, index),
          ),
      ];
  }
}

/// Why the deposit cannot be saved with [plan], or null.
String? _depositProblem(
  _PayPlan plan,
  int deposit,
  int total,
  JourneyProfile profile,
) {
  switch (plan) {
    case _PayPlan.depositRest:
      if (deposit <= 0) {
        return profile.say('اكتب كم العربون', 'اكتبي كم العربون');
      }
      if (total > 0 && deposit >= total) return 'العربون أقل من الاتفاق';
      return null;
    case _PayPlan.instalments:
      if (total > 0 && deposit >= total) return 'العربون أقل من الاتفاق';
      return null;
    case _PayPlan.later:
    case _PayPlan.full:
      return null;
  }
}

/// The plan's choices and, below them, the payments it will make.
class _PlanSection extends StatelessWidget {
  const _PlanSection({
    required this.plan,
    required this.onPlan,
    required this.depositController,
    required this.depositError,
    required this.count,
    required this.onCount,
    required this.restDue,
    required this.weddingDateKnown,
    required this.onPickRestDue,
    required this.firstDue,
    required this.onPickFirstDue,
    required this.lines,
    required this.currency,
  });

  final _PayPlan plan;
  final ValueChanged<_PayPlan> onPlan;
  final TextEditingController depositController;
  final String? depositError;
  final int count;
  final ValueChanged<int> onCount;
  final DateTime? restDue;
  final bool weddingDateKnown;
  final VoidCallback onPickRestDue;
  final DateTime firstDue;
  final VoidCallback onPickFirstDue;
  final List<_PlannedLine> lines;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final needsDeposit =
        plan == _PayPlan.depositRest || plan == _PayPlan.instalments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldLabel(context.say('كيف بتدفع؟', 'كيف بتدفعين؟')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in _PayPlan.values)
              JourneyChip(
                key: ValueKey('cost-plan-${option.name}'),
                label: option.labelFor(context.journeyProfile),
                selected: plan == option,
                onTap: () => onPlan(option),
              ),
          ],
        ),
        if (needsDeposit) ...[
          const SizedBox(height: AarastV3Space.x3),
          JourneyTextField(
            key: const ValueKey('cost-plan-deposit'),
            label: plan == _PayPlan.instalments
                ? context.say(
                    'العربون (لو دفعت شي اليوم)',
                    'العربون (لو دفعتِ شي اليوم)',
                  )
                : 'العربون',
            controller: depositController,
            keyboardType: TextInputType.number,
            inputFormatters: [MoneyInputFormatter()],
            suffix: currencyLabelAr(currency),
            errorText: depositError,
          ),
        ],
        if (plan == _PayPlan.depositRest) ...[
          const SizedBox(height: AarastV3Space.x3),
          JourneyPickerField(
            key: const ValueKey('cost-plan-rest-due'),
            label: 'متى الباقي؟',
            value: restDue == null
                ? null
                : weddingDateKnown
                ? 'يوم العرس · ${formatArabicDayMonth(restDue!)}'
                : formatArabicDayMonth(restDue!),
            placeholder: context.say('اختر اليوم', 'اختاري اليوم'),
            icon: LucideIcons.calendarHeart,
            onTap: onPickRestDue,
          ),
        ],
        if (plan == _PayPlan.instalments) ...[
          const SizedBox(height: AarastV3Space.x3),
          _FieldLabel('كم دفعة؟'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in const [2, 3, 4, 6])
                JourneyChip(
                  key: ValueKey('cost-plan-count-$option'),
                  label: '$option',
                  selected: count == option,
                  onTap: () => onCount(option),
                ),
            ],
          ),
          const SizedBox(height: AarastV3Space.x3),
          JourneyPickerField(
            key: const ValueKey('cost-plan-first-due'),
            label: 'أول دفعة',
            value: formatArabicDayMonth(firstDue),
            icon: LucideIcons.calendarDays,
            helper: 'وبعده كل شهر',
            onTap: onPickFirstDue,
          ),
        ],
        if (lines.isNotEmpty) ...[
          const SizedBox(height: AarastV3Space.x3),
          JourneyBox(
            key: const ValueKey('cost-plan-preview'),
            padding: AarastV3Density.chipInsets,
            child: Column(
              children: [
                for (var index = 0; index < lines.length; index++)
                  _PlanRow(
                    number: index + 1,
                    line: lines[index],
                    currency: currency,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.number,
    required this.line,
    required this.currency,
  });

  final int number;
  final _PlannedLine line;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x1),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: line.paidNow
                  ? context.accent.primary
                  : context.accent.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: line.paidNow
                    ? AarastV3Color.onPrimary
                    : context.accent.primary,
              ),
            ),
          ),
          const SizedBox(width: AarastV3Space.x2),
          Expanded(
            child: Text(
              line.label,
              style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
            ),
          ),
          const SizedBox(width: AarastV3Space.x2),
          Text(
            compactMoneyParts(line.amount, currencyCode: currency).plainText,
            style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
          ),
        ],
      ),
    );
  }
}
