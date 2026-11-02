part of 'smart_welcome_screen.dart';

/// «ايش اسمك، ومتى العرس؟»: the name, and the day inside one of the next
/// six months (later ones in a sheet). «ما حددنا الموعد بعد» is a full
/// answer under the main action.
class _NameDateStep extends StatelessWidget {
  const _NameDateStep({
    required this.controller,
    required this.date,
    required this.nameError,
    required this.onNameChanged,
    required this.onPickMonth,
    required this.onLaterMonths,
    required this.onNext,
    required this.onSkipDate,
    required this.onBack,
  });

  final TextEditingController controller;
  final DateTime? date;
  final String? nameError;
  final VoidCallback onNameChanged;
  final ValueChanged<DateTime> onPickMonth;
  final VoidCallback onLaterMonths;
  final VoidCallback? onNext;
  final VoidCallback? onSkipDate;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final name = controller.text.trim();
    final today = DateUtils.dateOnly(appNow());
    final months = [
      for (var i = 0; i < _monthsOnScreen; i++)
        DateTime(today.year, today.month + i),
    ];
    final date = this.date;
    final hijri = date == null ? null : HijriDate.fromGregorian(date);
    final note = date == null
        ? null
        : _ramadanNote(date, context.journeyProfile);
    final last = months.last;
    final later = date != null && DateTime(date.year, date.month).isAfter(last);
    return JourneyQuestionPage(
      step: 0,
      total: _questionCount,
      question: 'ايش اسمك، ومتى العرس؟',
      help: 'نناديك باسمك، ونرتب المهام والدفعات على الموعد.',
      primaryLabel: 'التالي',
      onPrimary: onNext,
      onBack: onBack,
      skipLabel: 'ما حددنا الموعد بعد',
      onSkip: onSkipDate,
      children: [
        JourneyTextField(
          label: 'اسمك',
          controller: controller,
          hint: context.say('محمد', 'سلمى'),
          errorText: nameError,
          textInputAction: TextInputAction.done,
          onChanged: (_) => onNameChanged(),
        ),
        if (name.isNotEmpty) ...[
          const SizedBox(height: AarastV3Space.x2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x1),
            child: Row(
              children: [
                Icon(
                  LucideIcons.check,
                  color: context.accent.primary,
                  size: AarastV3Icon.sm,
                ),
                const SizedBox(width: AarastV3Space.x1),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'خطتك بتكون: ',
                      style: JourneyType.of(
                        JourneyType.body,
                        color: AarastV3Color.textMuted,
                      ),
                      children: [
                        TextSpan(
                          text: 'عرس $name',
                          style: JourneyType.of(
                            JourneyType.body,
                            weight: JourneyType.bold,
                            color: context.accent.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AarastV3Space.x5),
        Padding(
          padding: const EdgeInsets.only(bottom: AarastV3Space.x2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'شهر العرس',
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
                    weight: JourneyType.bold,
                  ),
                ),
              ),
              Text(
                '${arabicMonthName(months.first.month)} ${months.first.year}'
                ' – ${arabicMonthName(last.month)} ${last.year}',
                style: JourneyType.of(
                  JourneyType.bodySmall,
                  color: AarastV3Color.textMuted,
                ),
              ),
            ],
          ),
        ),
        Builder(
          builder: (context) {
            // Three months a row, two when large text would cut a name. The
            // tiles of a row share one height, whatever their Hijri line.
            final columns = MediaQuery.textScalerOf(context).scale(100) > 130
                ? 2
                : 3;
            return Column(
              children: [
                for (var start = 0; start < months.length; start += columns)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AarastV3Space.x2),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = start; i < start + columns; i++) ...[
                            if (i > start)
                              const SizedBox(width: AarastV3Space.x2),
                            Expanded(
                              child: i < months.length
                                  ? _MonthTile(
                                      month: months[i],
                                      selected:
                                          date != null &&
                                          date.year == months[i].year &&
                                          date.month == months[i].month,
                                      onTap: () => onPickMonth(months[i]),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        _LaterMonthsCell(
          lastOnScreen: last,
          chosen: later ? date : null,
          onTap: onLaterMonths,
        ),
        if (date != null) ...[
          const SizedBox(height: AarastV3Space.x3),
          JourneyPickerField(
            label: 'يوم العرس',
            value: '${formatArabicWeekdayDayMonth(date)} ${date.year}',
            helper: hijri?.full,
            icon: LucideIcons.calendarDays,
            iconAtEnd: true,
            onTap: () => onPickMonth(DateTime(date.year, date.month)),
          ),
        ],
        if (note != null) ...[
          const SizedBox(height: AarastV3Space.x3),
          JourneyEntryNote(text: note, icon: LucideIcons.moon),
        ],
      ],
    );
  }

  /// A word about Ramadan when the wedding falls inside it or within 60
  /// days before it.
  static String? _ramadanNote(DateTime date, JourneyProfile profile) {
    final ramadan = HijriDate.ramadanOnOrAfter(date);
    if (ramadan == null) return null;
    final day = DateTime.utc(date.year, date.month, date.day);
    if (!day.isBefore(ramadan.$1)) {
      return 'هذا اليوم في رمضان، والأعراس فيه قليلة. '
          '${profile.say('تأكد', 'تأكدي')} من الموعد مع الأهل.';
    }
    final days = ramadan.$1.difference(day).inDays;
    if (days > 60) return null;
    return 'عرسك قبل رمضان بـ${arabicDays(days)}، والحجوزات تكثر قبله. '
        '${profile.say('احجز', 'احجزي')} القاعة بدري.';
  }
}

/// A month with the Hijri months it spans.
class _MonthTile extends StatelessWidget {
  const _MonthTile({
    required this.month,
    required this.selected,
    required this.onTap,
    this.withYear = false,
  });

  final DateTime month;
  final bool selected;
  final VoidCallback onTap;

  /// In the later months' sheet, where the year changes.
  final bool withYear;

  @override
  Widget build(BuildContext context) {
    final first = HijriDate.fromGregorian(month);
    final last = HijriDate.fromGregorian(
      DateTime(month.year, month.month + 1, 0),
    );
    final hijri = first == null || last == null
        ? ''
        : first.month == last.month
        ? first.monthName
        : '${first.monthName} · ${_secondMonth(first.monthName, last.monthName)}';
    final fg = selected ? AarastV3Color.onPrimary : AarastV3Color.ink;
    final name = withYear
        ? '${arabicMonthName(month.month)} ${month.year}'
        : arabicMonthName(month.month);
    return Semantics(
      button: true,
      selected: selected,
      label: '${arabicMonthName(month.month)} ${month.year}، $hijri',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        selected: selected,
        borderRadius: BorderRadius.circular(AarastV3Radius.control),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            vertical: AarastV3Space.x2,
            horizontal: AarastV3Space.x1,
          ),
          decoration: BoxDecoration(
            color: selected ? context.accent.primary : AarastV3Color.paper,
            borderRadius: BorderRadius.circular(AarastV3Radius.control),
            border: selected ? null : Border.all(color: AarastV3Color.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    Icon(LucideIcons.check, size: AarastV3Icon.sm, color: fg),
                    const SizedBox(width: AarastV3Space.x1),
                  ],
                  Flexible(
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: JourneyType.of(
                        JourneyType.bodyLarge,
                        weight: JourneyType.bold,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AarastV3Space.half),
              Text(
                hijri,
                textAlign: TextAlign.center,
                style: JourneyType.of(
                  JourneyType.label,
                  color: selected
                      ? AarastV3Color.onPrimary
                      : AarastV3Color.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The second Hijri month of a tile without the word the first one already
/// said: «جمادى الأولى · الآخرة», «ربيع الأول · الآخر».
String _secondMonth(String first, String second) {
  final head = first.split(' ').first;
  return second.startsWith('$head ')
      ? second.substring(head.length + 1)
      : second;
}

/// «موعدنا بعد أبريل»: the way to a month past the six on the screen. Once
/// such a month is chosen it shows that month.
class _LaterMonthsCell extends StatelessWidget {
  const _LaterMonthsCell({
    required this.lastOnScreen,
    required this.chosen,
    required this.onTap,
  });

  final DateTime lastOnScreen;
  final DateTime? chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final chosen = this.chosen;
    final selected = chosen != null;
    final label = selected
        ? '${arabicMonthName(chosen.month)} ${chosen.year}'
        : 'موعدنا بعد ${arabicMonthName(lastOnScreen.month)}';
    final fg = selected ? AarastV3Color.onPrimary : context.accent.primaryDark;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        selected: selected,
        borderRadius: BorderRadius.circular(AarastV3Radius.control),
        child: Container(
          constraints: const BoxConstraints(minHeight: AarastV3Space.x12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? context.accent.primary : AarastV3Color.paper,
            borderRadius: BorderRadius.circular(AarastV3Radius.control),
            border: selected ? null : Border.all(color: AarastV3Color.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(LucideIcons.check, size: AarastV3Icon.sm, color: fg),
                const SizedBox(width: AarastV3Space.x1),
              ],
              Text(
                label,
                style: JourneyType.of(
                  JourneyType.body,
                  weight: JourneyType.bold,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The eighteen months after the six on the screen, three a row.
class _LaterMonthsSheet extends StatelessWidget {
  const _LaterMonthsSheet({required this.first, required this.selected});

  final DateTime first;
  final DateTime? selected;

  @override
  Widget build(BuildContext context) {
    final months = [
      for (var i = 0; i < 18; i++) DateTime(first.year, first.month + i),
    ];
    final selected = this.selected;
    return JourneySheetBody(
      title: context.say('اختر شهر العرس', 'اختاري شهر العرس'),
      children: [
        for (var start = 0; start < months.length; start += 3)
          Padding(
            padding: const EdgeInsets.only(bottom: AarastV3Space.x2),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = start; i < start + 3; i++) ...[
                    if (i > start) const SizedBox(width: AarastV3Space.x2),
                    Expanded(
                      child: _MonthTile(
                        month: months[i],
                        withYear: true,
                        selected:
                            selected != null &&
                            selected.year == months[i].year &&
                            selected.month == months[i].month,
                        onTap: () => Navigator.of(context).pop(months[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// «وين العرس، وكم ميزانيتك تقريبًا؟»: the city (the provider directory's
/// cities, or another) and a rough budget, spelled out in words. The city
/// is needed; the budget can wait (the line under the main action).
class _PlaceBudgetStep extends StatelessWidget {
  const _PlaceBudgetStep({
    required this.cities,
    required this.city,
    required this.budgetController,
    required this.cityError,
    required this.onCity,
    required this.onMoreCities,
    required this.onBudgetChanged,
    required this.onNext,
    required this.onSkipBudget,
    required this.onBack,
  });

  final List<String> cities;
  final String? city;
  final TextEditingController budgetController;
  final String? cityError;
  final ValueChanged<String> onCity;
  final VoidCallback onMoreCities;
  final VoidCallback onBudgetChanged;
  final VoidCallback? onNext;
  final VoidCallback? onSkipBudget;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final shown = cities.take(6).toList();
    final extra = city != null && !shown.contains(city) ? city : null;
    final digits = budgetController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(digits);
    return JourneyQuestionPage(
      step: 1,
      total: _questionCount,
      question: 'وين العرس، وكم ميزانيتك تقريبًا؟',
      help: 'نعرض لك مزودين مدينتك، ونقول لك كم باقي من الميزانية.',
      primaryLabel: 'التالي',
      onPrimary: onNext,
      onBack: onBack,
      skipLabel: context.say('أكمل بدون ميزانية', 'أكملي بدون ميزانية'),
      onSkip: onSkipBudget,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AarastV3Space.x2),
          child: Text(
            'المدينة',
            style: JourneyType.of(
              JourneyType.bodyLarge,
              weight: JourneyType.bold,
            ),
          ),
        ),
        Wrap(
          spacing: AarastV3Space.x2,
          runSpacing: AarastV3Space.x2,
          children: [
            for (final name in [...shown, ?extra])
              JourneyChip(
                label: name,
                selected: name == city,
                icon: name == city ? LucideIcons.check : null,
                fontSize: JourneyType.body,
                large: true,
                onTap: () => onCity(name),
              ),
            JourneyChip(
              label: 'مدينة ثانية',
              icon: LucideIcons.plus,
              fontSize: JourneyType.body,
              large: true,
              onTap: onMoreCities,
            ),
          ],
        ),
        if (cityError != null) ...[
          const SizedBox(height: AarastV3Space.x2),
          Text(
            cityError!,
            style: JourneyType.of(
              JourneyType.small,
              weight: JourneyType.bold,
              color: AarastV3Color.danger,
            ),
          ),
        ],
        const SizedBox(height: AarastV3Space.x5),
        JourneyTextField(
          label: 'ميزانية عرسك',
          controller: budgetController,
          large: true,
          hint: '7,000,000',
          suffix: 'ر.ي',
          keyboardType: TextInputType.number,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          // Whole riyals, grouped as typed: 7,000,000.
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'[.٫]')),
            const MoneyInputFormatter(),
          ],
          helper: amount == null || amount <= 0 ? null : amountInWords(amount),
          helperColor: context.accent.primaryDark,
          onChanged: (_) => onBudgetChanged(),
        ),
        const SizedBox(height: AarastV3Space.x3),
        JourneyEntryNote(
          // C1: the budget is the wedding only; the mahr is its own
          // question next, outside the budget.
          text: context.say(
            'الميزانية لعرسك بس، والمهر مش منها. وتقدر تغيّرها بعدين من صفحة المال.',
            'الميزانية لعرسك بس، والمهر مش منها. وتقدرين تغيّرينها بعدين من صفحة المال.',
          ),
          icon: LucideIcons.info,
        ),
      ],
    );
  }
}

/// How far the sky reaches down «خطتك جاهزة».
const _readySkyHeight = 160.0;

/// «خطتك جاهزة يا X»: only what the plan starts with (the items and tasks
/// from the catalogues, the city's real number of providers), then save it
/// with the phone number or look around first, and what looking first risks.
class _ReadyStep extends StatelessWidget {
  const _ReadyStep({
    required this.name,
    required this.subtitle,
    required this.moneyLine,
    required this.city,
    required this.providerCount,
    required this.hasDate,
    required this.catalogs,
    required this.signedIn,
    required this.saving,
    required this.error,
    required this.onSaveWithPhone,
    required this.onLookFirst,
    required this.onOpenPlan,
    required this.onBack,
  });

  final String name;
  final String subtitle;
  final String? moneyLine;
  final String city;

  /// The directory's count for the city; null when it is not known.
  final int? providerCount;

  /// Without a date nothing is placed on one yet, so nothing says so.
  final bool hasDate;
  final ReferenceCatalogData catalogs;
  final bool signedIn;
  final bool saving;
  final String? error;
  final VoidCallback onSaveWithPhone;
  final VoidCallback onLookFirst;
  final VoidCallback onOpenPlan;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final items = catalogs.items;
    final itemsLine = items.isEmpty
        ? context.say('تضيف بنودك بنفسك', 'تضيفين بنودك بنفسك')
        : items.length <= 4
        ? items.join(' و')
        : '${items.take(4).join(' و')} وغيرها';
    final count = providerCount;
    final error = this.error;
    return ColoredBox(
      color: AarastV3Color.canvas,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Stack(
                  children: [
                    const JourneySkyBand(height: _readySkyHeight),
                    PositionedDirectional(
                      top: AarastV3Space.x2,
                      start: AarastV3Space.x3,
                      child: SafeArea(
                        bottom: false,
                        child: JourneyRoundButton(
                          icon: LucideIcons.arrowRight,
                          tooltip: 'رجوع',
                          onPressed: onBack,
                          onArt: true,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AarastV3Space.x4,
                    AarastV3Space.x2,
                    AarastV3Space.x4,
                    AarastV3Space.x5,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'خطتك جاهزة يا $name',
                          style: JourneyType.of(
                            JourneyType.question,
                            weight: JourneyType.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: AarastV3Space.x1),
                      Text(
                        subtitle,
                        style: JourneyType.of(
                          JourneyType.body,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                      if (moneyLine != null)
                        Text(
                          moneyLine!,
                          style: JourneyType.of(
                            JourneyType.body,
                            color: AarastV3Color.textMuted,
                          ),
                        ),
                      const SizedBox(height: AarastV3Space.x4),
                      JourneyBox(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            JourneyEntryRow(
                              icon: LucideIcons.wallet,
                              title:
                                  '${arabicCount(items.length, one: 'بند واحد', two: 'بندين', few: 'بنود', many: 'بند')} لعرسك',
                              subtitle: itemsLine,
                            ),
                            if (catalogs.taskCount > 0)
                              JourneyEntryRow(
                                icon: LucideIcons.listChecks,
                                title:
                                    '${arabicCount(catalogs.taskCount, one: 'مهمة واحدة', two: 'مهمتين', few: 'مهام', many: 'مهمة')} مقترحة${hasDate ? ' على موعدك' : ''}',
                                subtitle: hasDate
                                    ? context.say(
                                        'تختار منها اللي يناسبك',
                                        'تختارين منها اللي يناسبك',
                                      )
                                    : context.say(
                                        'تختار منها اللي يناسبك، وترتبها لما تحدد الموعد',
                                        'تختارين منها اللي يناسبك، وترتبينها لما تحددين الموعد',
                                      ),
                              ),
                            JourneyEntryRow(
                              icon: LucideIcons.store,
                              divider: false,
                              title: count != null && count > 0
                                  ? '${arabicCount(count, one: 'مزود واحد', two: 'مزودين', few: 'مزودين', many: 'مزود')} في $city'
                                  : 'مزودين $city',
                              // Only what the directory said: a number, or
                              // none; nothing is promised when it is unknown.
                              subtitle: count == null
                                  ? 'نعرف كم مزود في $city أول ما يرجع النت'
                                  : count == 0
                                  ? 'ما في مزودين في $city بعد. نضيفهم أول ما ينضمون.'
                                  : context.say(
                                      'قاعات ومصورين ومنشدين',
                                      'صالات ومصورات ومنشدات',
                                    ),
                            ),
                          ],
                        ),
                      ),
                      if (!signedIn) ...[
                        const SizedBox(height: AarastV3Space.x4),
                        JourneyEntryNote(
                          text: context.say(
                            'خطتك الحين على هذا الجوال بس: لو حذفت التطبيق أو ضاع الجوال تضيع. وطلب العروض ودعوة الأهل تحتاج رقمك.',
                            'خطتك الحين على هذا الجوال بس: لو حذفتي التطبيق أو ضاع الجوال تضيع. وطلب العروض ودعوة الأهل تحتاج رقمك.',
                          ),
                          icon: LucideIcons.smartphone,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: AarastV3Density.actionInsets,
              child: JourneyEntryActions(
                above: error == null
                    ? null
                    : JourneyNote(
                        text: error,
                        icon: LucideIcons.alertCircle,
                        color: AarastV3Color.danger,
                        soft: AarastV3Color.dangerSoft,
                      ),
                primary: signedIn
                    ? JourneyButton(
                        label: 'افتح خطتي',
                        onPressed: saving ? null : onOpenPlan,
                        loading: saving,
                        expand: true,
                        large: true,
                      )
                    : JourneyButton(
                        key: const ValueKey('ready-save'),
                        label: 'احفظ خطتي برقم جوالي',
                        icon: LucideIcons.smartphone,
                        onPressed: saving ? null : onSaveWithPhone,
                        loading: saving,
                        expand: true,
                        large: true,
                      ),
                secondary: signedIn
                    ? null
                    : JourneyEntryLink(
                        key: const ValueKey('ready-later'),
                        label: context.say(
                          'بعدين، خلني أشوف أول',
                          'بعدين، خليني أشوف أول',
                        ),
                        onPressed: saving ? null : onLookFirst,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// «مدينة ثانية»: every city of the directory, or any city typed by name,
/// so a wedding outside the list (or offline) still has its city.
class _CitySheet extends StatefulWidget {
  const _CitySheet({required this.cities, required this.selected});

  final List<String> cities;
  final String? selected;

  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  final _typed = TextEditingController();

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _useTyped() {
    final name = _typed.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return JourneySheetBody(
      title: context.say('اختر المدينة', 'اختاري المدينة'),
      children: [
        Wrap(
          spacing: AarastV3Space.x2,
          runSpacing: AarastV3Space.x2,
          children: [
            for (final name in widget.cities)
              JourneyChip(
                label: name,
                selected: name == widget.selected,
                fontSize: JourneyType.body,
                large: true,
                onTap: () => Navigator.of(context).pop(name),
              ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x4),
        JourneyTextField(
          label: context.say(
            'مدينتك مش في القائمة؟ اكتبها',
            'مدينتك مش في القائمة؟ اكتبيها',
          ),
          controller: _typed,
          hint: 'ذمار',
          icon: LucideIcons.mapPin,
          maxLength: 40,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _useTyped(),
        ),
        const SizedBox(height: AarastV3Space.x3),
        JourneyButton(
          label: context.say('اختر هذي المدينة', 'اختاري هذي المدينة'),
          onPressed: _typed.text.trim().isEmpty ? null : _useTyped,
          expand: true,
        ),
      ],
    );
  }
}
