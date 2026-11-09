part of 'budget_category_details_screen.dart';

// c07's pieces (D102, D105, D109): the item at a glance and its actions, a
// row per agreement, date still to pay and payment, where its offers are,
// and the estimate sheet.

typedef _Money = String Function(Object? value);

/// The item at a glance: its estimate, what was agreed, paid and left on it,
/// how the agreement stands against the estimate; then what to do next.
class _ItemGlance extends StatelessWidget {
  const _ItemGlance({
    required this.category,
    required this.item,
    required this.agreements,
    required this.money,
    required this.onPay,
    required this.onAgreement,
    required this.onOffers,
    required this.onExpense,
    required this.onEstimate,
  });

  final BudgetCategory category;
  final MoneyCategorySummary? item;
  final int agreements;
  final _Money money;
  final VoidCallback? onPay;
  final VoidCallback? onAgreement;

  /// Offers wait for an answer, and nothing is agreed yet.
  final VoidCallback? onOffers;
  final VoidCallback? onExpense;
  final VoidCallback? onEstimate;

  @override
  Widget build(BuildContext context) {
    final mahr = category.isMahr;
    final estimate = item?.estimate;
    final fromShare = item?.estimateFromAllocation ?? false;
    final own = estimate != null && !fromShare;
    final agreed = moneyValue(item?.confirmedCost ?? category.confirmedCost);
    final paid = item?.paid ?? category.paid;
    final left = item?.outstanding ?? category.outstanding;
    final estimateWord = fromShare
        ? 'المخصص له'
        : context.ownerDid(
            'تقديرك',
            'تقديرك',
            groom: 'التقدير',
            bride: 'التقدير',
          );
    Widget stat(String label, String value, {Key? key, bool strong = false}) =>
        Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
            Text(
              value,
              style: JourneyType.of(
                strong ? JourneyType.bodyLarge : JourneyType.body,
                weight: JourneyType.bold,
              ),
            ),
          ],
        );
    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: AarastV3Space.x3),
        Expanded(child: b),
      ],
    );
    // D105: how the agreements stand against his own estimate, and whether
    // what is left of it still counts.
    String? against;
    Color? againstColour;
    if (own && !mahr && agreements > 0) {
      final gap = agreed - moneyValue(estimate);
      final word = context.ownerDid(
        'تقديرك',
        'تقديرك',
        groom: 'التقدير',
        bride: 'التقدير',
      );
      final rest = moneyValue(item?.estimateLeft);
      if (gap == 0) {
        against = 'على قد $word';
      } else if (gap > 0) {
        against = 'أكثر من $word بـ${money(gap)}';
        againstColour = AarastV3Color.danger;
      } else {
        against = [
          'أقل من $word بـ${money(-gap)}.',
          if (rest > 0)
            'باقي التقدير (${money(rest)}) محسوب في تكلفة العرس، ${context.ownerDid('ولو خلص البند عدّل التقدير.', 'ولو خلص البند عدّلي التقدير.', groom: 'لين يخلص البند.', bride: 'لين يخلص البند.')}',
        ].join(' ');
      }
    }
    final primary = onPay != null
        ? JourneyButton(
            key: const ValueKey('item-pay'),
            label: mahr
                ? context.say('سلّم من الباقي', 'سلّمي من الباقي')
                : context.say('سجّل دفعة', 'سجّلي دفعة'),
            onPressed: onPay,
          )
        : agreements == 0 && onOffers != null
        ? JourneyButton(
            key: const ValueKey('item-offers'),
            label: context.say('قارن العروض', 'قارني العروض'),
            onPressed: onOffers,
          )
        : agreements == 0 && onAgreement != null
        ? JourneyButton(
            key: const ValueKey('item-agreement'),
            label: context.say('سجّل اتفاق', 'سجّلي اتفاق'),
            onPressed: onAgreement,
          )
        : null;
    final more = <Widget>[
      if (agreements == 0 && onOffers != null && onAgreement != null)
        JourneyTextAction(
          key: const ValueKey('item-agreement'),
          label: context.say('سجّل اتفاق', 'سجّلي اتفاق'),
          icon: LucideIcons.plus,
          color: context.accent.primary,
          onPressed: onAgreement,
        ),
      if (onExpense != null)
        JourneyTextAction(
          key: const ValueKey('item-expense'),
          label: context.say('مصروف دفعته', 'مصروف دفعتيه'),
          icon: LucideIcons.plus,
          color: context.accent.primary,
          onPressed: onExpense,
        ),
      if (onEstimate != null)
        JourneyTextAction(
          key: const ValueKey('item-estimate'),
          label: own
              ? context.say('عدّل التقدير', 'عدّلي التقدير')
              : context.say('حط تقدير', 'حطي تقدير'),
          icon: LucideIcons.pencil,
          color: context.accent.primary,
          onPressed: onEstimate,
        ),
    ];
    return JourneyBox(
      key: const ValueKey('item-glance'),
      padding: const EdgeInsets.all(AarastV3Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (agreements > 0 || agreed > 0) ...[
            pair(
              mahr
                  ? stat('المهر', money(agreed), strong: true)
                  : stat(
                      estimateWord,
                      estimate == null ? '—' : money(estimate),
                      key: const ValueKey('item-estimate-figure'),
                    ),
              mahr
                  ? stat(
                      context.ownerDid(
                        'سلّمت',
                        'سلّمتِ',
                        groom: 'انسلّم',
                        bride: 'انسلّم',
                      ),
                      money(paid),
                    )
                  : stat(
                      context.ownerDid(
                        'اتفقت',
                        'اتفقتِ',
                        groom: 'الاتفاق',
                        bride: 'الاتفاق',
                      ),
                      money(agreed),
                    ),
            ),
            const SizedBox(height: AarastV3Space.x3),
            pair(
              mahr
                  ? stat('باقي', money(left), strong: true)
                  : stat('اندفع', money(paid)),
              mahr
                  ? const SizedBox.shrink()
                  : stat(
                      'باقي',
                      money(left),
                      key: const ValueKey('item-left'),
                      strong: true,
                    ),
            ),
            // Its share of the budget, when it has one besides its own
            // estimate (D109: the two are apart).
            if (own && category.allocatedAmount != null) ...[
              const SizedBox(height: AarastV3Space.x2),
              Text(
                'المخصص له من الميزانية ${money(category.allocatedAmount)}',
                key: const ValueKey('item-share'),
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.textMuted,
                ),
              ),
            ],
            if (against != null) ...[
              const SizedBox(height: AarastV3Space.x3),
              Text(
                against,
                key: const ValueKey('item-against-estimate'),
                style: JourneyType.of(
                  JourneyType.small,
                  weight: againstColour == null
                      ? FontWeight.w400
                      : JourneyType.bold,
                  color: againstColour ?? AarastV3Color.textMuted,
                ),
              ),
            ],
          ] else ...[
            Text(
              estimateWord,
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
            Text(
              estimate == null ? '—' : money(estimate),
              key: const ValueKey('item-estimate-figure'),
              style: JourneyType.of(
                JourneyType.figure,
                weight: JourneyType.bold,
              ),
            ),
            const SizedBox(height: AarastV3Space.x1),
            Text(
              estimate == null
                  ? context.ownerDid(
                      'ما اتفقت مع أحد بعد، وما له تقدير، فما دخل في تكلفة العرس.',
                      'ما اتفقتِ مع أحد بعد، وما له تقدير، فما دخل في تكلفة العرس.',
                      groom:
                          'ما في اتفاق بعد، وما له تقدير، فما دخل في تكلفة العرس.',
                      bride:
                          'ما في اتفاق بعد، وما له تقدير، فما دخل في تكلفة العرس.',
                    )
                  : context.ownerDid(
                      'ما اتفقت مع أحد بعد. التقدير يدخل في تكلفة العرس ومقابل الميزانية، وما ينحسب عليك.',
                      'ما اتفقتِ مع أحد بعد. التقدير يدخل في تكلفة العرس ومقابل الميزانية، وما ينحسب عليكِ.',
                      groom:
                          'ما في اتفاق بعد. التقدير يدخل في تكلفة العرس ومقابل الميزانية.',
                      bride:
                          'ما في اتفاق بعد. التقدير يدخل في تكلفة العرس ومقابل الميزانية.',
                    ),
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          ],
          if (primary != null) ...[
            const SizedBox(height: AarastV3Space.x4),
            primary,
          ],
          if (more.isNotEmpty) ...[
            const SizedBox(height: AarastV3Space.x2),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AarastV3Space.x2,
              children: more,
            ),
          ],
        ],
      ),
    );
  }
}

/// One agreement of the item: with whom, its kind, who pays, what is left.
class _AgreementRow extends StatelessWidget {
  const _AgreementRow({
    required this.cost,
    required this.summary,
    required this.money,
    required this.onTap,
    super.key,
  });

  final WeddingCost cost;
  final MoneySummary summary;
  final _Money money;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final profile = context.journeyProfile;
    final group = summary.payers
        .where(
          (group) =>
              payerKey(group.payer, group.payerName) ==
              payerKey(cost.payer, cost.payerName),
        )
        .firstOrNull;
    final left = moneyValue(cost.remainingAmount);
    return JourneyListRow(
      icon: cost.isExpense ? LucideIcons.banknote : LucideIcons.fileSignature,
      color: context.accent.primary,
      soft: context.accent.primarySoft,
      title: cost.partyLabel ?? cost.title,
      subtitle: [
        // V1 checklist 4.10: only the reader sees it.
        if (cost.isPrivate) 'خاص بك',
        if (cost.isExpense) 'مصروف',
        if (cost.agreementDate case final day?)
          '${cost.isExpense ? 'اندفع' : 'من'} ${formatArabicDayMonth(day)}',
        if (group != null && !group.ownerMoney)
          'على ${payerLabel(group.payer, group.payerName, bridePlan: profile.isBride, owner: profile.readerIsOwner)}',
        left <= 0 ? 'خالص' : 'باقي ${money(left)}',
      ].join(' · '),
      subtitleMaxLines: 2,
      trailing: Text(
        money(cost.totalAmount),
        textAlign: TextAlign.end,
        style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
      ),
      onTap: onTap,
    );
  }
}

/// A date still to pay on the item, or what has no date yet.
class _DueRow extends StatelessWidget {
  const _DueRow({
    required this.line,
    required this.money,
    required this.onTap,
    super.key,
  });

  final MoneyObligation line;
  final _Money money;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final day = line.dueDate;
    final late = line.isOverdue;
    final days = day == null ? null : daysUntilPlanDay(day);
    final when = day == null
        ? 'بدون موعد'
        : late
        ? 'متأخرة ${arabicCount(-days!, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم')}'
        : days == 0
        ? 'اليوم'
        : days == 1
        ? 'بكرة'
        : '${formatArabicDayMonth(day)} · بعد ${arabicCount(days!, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم')}';
    return JourneyListRow(
      icon: day == null ? LucideIcons.calendarX : LucideIcons.calendarClock,
      color: late
          ? AarastV3Color.danger
          : day == null
          ? AarastV3Color.amber
          : context.accent.primary,
      soft: late
          ? AarastV3Color.dangerSoft
          : day == null
          ? AarastV3Color.amberSoft
          : context.accent.primarySoft,
      title: line.title,
      subtitle: [
        when,
        if (line.isPartlyPaid)
          'اندفع ${money(line.paidTowards)} من ${money(line.scheduledAmount)}',
      ].join(' · '),
      subtitleMaxLines: 2,
      trailing: Text(
        money(line.amount),
        textAlign: TextAlign.end,
        style: JourneyType.of(
          JourneyType.body,
          weight: JourneyType.bold,
          color: late ? AarastV3Color.danger : AarastV3Color.ink,
        ),
      ),
      onTap: onTap,
    );
  }
}

/// A payment made on the item; a reversed one is struck through.
class _PaidRow extends StatelessWidget {
  const _PaidRow({
    required this.payment,
    required this.money,
    required this.onTap,
    super.key,
  });

  final CostPayment payment;
  final _Money money;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reversed = payment.isReversed;
    return JourneyListRow(
      icon: LucideIcons.checkCircle2,
      color: reversed ? AarastV3Color.textFaint : AarastV3Color.mint,
      soft: reversed ? AarastV3Color.line : AarastV3Color.mintSoft,
      title: payment.note?.trim().isNotEmpty == true
          ? payment.note!.trim()
          : 'دفعة',
      subtitle: [
        formatArabicDayMonth(payment.paidAt),
        ?payment.costTitle,
        if (reversed) 'انعكست',
      ].join(' · '),
      trailing: Text(
        money(payment.amount),
        textAlign: TextAlign.end,
        style: JourneyType.of(
          JourneyType.body,
          weight: JourneyType.bold,
          color: reversed ? AarastV3Color.textFaint : AarastV3Color.ink,
        ).copyWith(decoration: reversed ? TextDecoration.lineThrough : null),
      ),
      onTap: onTap,
    );
  }
}

/// Where the item's service is on the providers tab (f01), in that tab's
/// words; before any request, where to look for one.
class _ItemMarketRow extends StatelessWidget {
  const _ItemMarketRow({
    required this.row,
    required this.itemName,
    required this.onTap,
  });

  final ProviderBoardRow row;
  final String itemName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final started = row.stage > 0;
    return JourneyBox(
      key: const ValueKey('item-market'),
      padding: EdgeInsets.zero,
      child: JourneyListRow(
        icon: started ? LucideIcons.store : LucideIcons.search,
        color: started
            ? AarastV3Color.brandAccentStrong
            : context.accent.primary,
        soft: started
            ? AarastV3Color.brandAccentSoft
            : context.accent.primarySoft,
        title: started
            ? row.detail
            : context.say('دوّر على مزود', 'دوّري على مزود'),
        subtitle: started
            ? 'افتح الطلبات والعروض'
            : context.say(
                'اطلب عروض أسعار لـ$itemName وقارن',
                'اطلبي عروض أسعار لـ$itemName وقارني',
              ),
        subtitleMaxLines: 2,
        trailing: const Icon(
          LucideIcons.chevronLeft,
          size: 18,
          color: AarastV3Color.textMuted,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Which agreement a payment is for, when the item has more than one with
/// something left.
class _PickAgreementSheet extends StatelessWidget {
  const _PickAgreementSheet({required this.costs, required this.money});

  final List<WeddingCost> costs;
  final _Money money;

  @override
  Widget build(BuildContext context) {
    return JourneySheetBody(
      title: 'الدفعة لأي اتفاق؟',
      children: [
        JourneyList(
          children: [
            for (final cost in costs)
              JourneyListRow(
                key: ValueKey('item-pay-${cost.id}'),
                icon: LucideIcons.fileSignature,
                color: context.accent.primary,
                soft: context.accent.primarySoft,
                title: cost.partyLabel ?? cost.title,
                subtitle: 'باقي ${money(cost.remainingAmount)}',
                trailing: const Icon(
                  LucideIcons.chevronLeft,
                  size: 18,
                  color: AarastV3Color.textMuted,
                ),
                onTap: () => Navigator.of(context).pop(cost),
              ),
          ],
        ),
      ],
    );
  }
}

/// D109 «تقديرك»: one number, free. It may pass the budget: said under the
/// field, never refused. Zero is an answer («ما بيكلف شي»); clearing it goes
/// back to the item's share.
class _EstimateSheet extends StatefulWidget {
  const _EstimateSheet({
    required this.name,
    required this.current,
    required this.currency,
    required this.othersExpected,
    required this.budget,
    required this.onSave,
    required this.errorOf,
  });

  final String name;
  final String? current;
  final String currency;

  /// What the wedding's other items expect, when this one's expected cost
  /// is its estimate alone (nothing agreed on it); null otherwise.
  final num? othersExpected;
  final String? budget;
  final Future<bool> Function(String? value) onSave;
  final String? Function() errorOf;

  @override
  State<_EstimateSheet> createState() => _EstimateSheetState();
}

class _EstimateSheetState extends State<_EstimateSheet> {
  late final _controller = TextEditingController(
    text: widget.current == null
        ? ''
        : formatMoneyInputValue('${moneyValue(widget.current).round()}'),
  );
  bool _saving = false;
  String? _error;

  int? get _value {
    final text = _controller.text.replaceAll(',', '').trim();
    return text.isEmpty ? null : int.tryParse(text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(String? value) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await widget.onSave(value);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = widget.errorOf() ?? 'ما انحفظ التقدير. جرّب مرة ثانية.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    final typed = _controller.text.trim().isNotEmpty;
    final currency = currencyLabelAr(widget.currency);
    String plain(num amount) => keepCurrencyOnLine(
      compactMoneyParts(amount, currencyCode: widget.currency).plainText,
    );
    final budget = widget.budget == null ? null : moneyValue(widget.budget);
    final others = widget.othersExpected;
    final over = budget != null && others != null && value != null
        ? others + value - budget
        : 0;
    return JourneySheetBody(
      title: 'تقدير ${widget.name}',
      subtitle: context.say(
        'كم تتوقع يكلف؟ يدخل في التكلفة المتوقعة لين تتفق.',
        'كم تتوقعين يكلف؟ يدخل في التكلفة المتوقعة لين تتفقين.',
      ),
      children: [
        JourneyTextField(
          key: const ValueKey('item-estimate-field'),
          label: 'المبلغ',
          controller: _controller,
          large: true,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [MoneyInputFormatter()],
          suffix: currency,
          errorText: typed && value == null ? 'المبلغ مش صحيح' : _error,
          helper: over > 0
              ? 'بهذا التقدير تصير بنود العرس فوق الميزانية بـ${plain(over)}'
              : value != null && value > 0
              ? amountInWords(value, currency: currency)
              : null,
          helperColor: over > 0 ? AarastV3Color.danger : null,
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: AarastV3Space.x4),
        JourneyButton(
          key: const ValueKey('item-estimate-save'),
          label: 'احفظ',
          loading: _saving,
          onPressed: _saving || value == null ? null : () => _save('$value'),
        ),
        if (widget.current != null) ...[
          const SizedBox(height: AarastV3Space.x2),
          Center(
            child: JourneyTextAction(
              key: const ValueKey('item-estimate-clear'),
              label: context.say('شيل التقدير', 'شيلي التقدير'),
              color: AarastV3Color.textMuted,
              onPressed: _saving ? null : () => _save(null),
            ),
          ),
        ],
      ],
    );
  }
}
