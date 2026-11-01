part of 'smart_welcome_screen.dart';

/// a03: the name and the wedding day. A month opens a day picker inside it;
/// «ما حددنا الموعد بعد» is a full answer (the date can be set later).
class _NameDateStep extends StatelessWidget {
  const _NameDateStep({
    required this.controller,
    required this.date,
    required this.dateUnknown,
    required this.onNameChanged,
    required this.onPickMonth,
    required this.onDateUnknown,
    required this.onNext,
    required this.onBack,
  });

  final TextEditingController controller;
  final DateTime? date;
  final bool dateUnknown;
  final VoidCallback onNameChanged;
  final ValueChanged<DateTime> onPickMonth;
  final VoidCallback onDateUnknown;
  final VoidCallback? onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final name = controller.text.trim();
    final today = DateUtils.dateOnly(appNow());
    final months = [
      for (var i = 0; i < 6; i++) DateTime(today.year, today.month + i),
    ];
    final hijri = date == null ? null : HijriDate.fromGregorian(date!);
    final note = date == null
        ? null
        : _ramadanNote(date!, context.journeyProfile);
    return JourneyQuestionPage(
      step: 0,
      total: _questionCount,
      question: 'ايش اسمك، ومتى العرس؟',
      help: 'نناديك باسمك، ونرتب المهام والدفعات على الموعد.',
      primaryLabel: 'التالي',
      onPrimary: onNext,
      onBack: onBack,
      children: [
        JourneyTextField(
          label: 'اسمك',
          controller: controller,
          large: true,
          hint: context.say('محمد', 'سلمى'),
          textInputAction: TextInputAction.done,
          onChanged: (_) => onNameChanged(),
        ),
        if (name.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    LucideIcons.sparkles,
                    color: context.accent.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'خطتك بتكون: ',
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                      children: [
                        TextSpan(
                          text: 'عرس $name',
                          style: JourneyType.of(
                            JourneyType.small,
                            weight: JourneyType.bold,
                            color: context.accent.primary,
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
        const SizedBox(height: 20),
        const _FieldLabel('شهر العرس'),
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
                    padding: EdgeInsets.only(top: start == 0 ? 0 : 8),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = start; i < start + columns; i++) ...[
                            if (i > start) const SizedBox(width: 8),
                            Expanded(
                              child: i < months.length
                                  ? _MonthTile(
                                      month: months[i],
                                      selected:
                                          !dateUnknown &&
                                          date != null &&
                                          date!.year == months[i].year &&
                                          date!.month == months[i].month,
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
        if (date != null && !dateUnknown) ...[
          const SizedBox(height: 10),
          JourneyPickerField(
            label: 'اليوم',
            value: formatArabicWeekdayDayMonth(date!),
            helper: hijri?.full,
            icon: LucideIcons.calendarDays,
            onTap: () => onPickMonth(DateTime(date!.year, date!.month)),
          ),
        ],
        if (note != null && !dateUnknown) ...[
          const SizedBox(height: 10),
          JourneyNote(
            text: note,
            icon: LucideIcons.moon,
            color: AarastV3Color.brandAccentStrong,
            soft: AarastV3Color.brandAccentSoft,
          ),
        ],
        const SizedBox(height: 6),
        _RadioLine(
          label: 'ما حددنا الموعد بعد',
          selected: dateUnknown,
          onTap: onDateUnknown,
        ),
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
    return 'باقي على رمضان ${arabicDays(days)}، والحجوزات تكثر قبله. '
        '${profile.say('احجز', 'احجزي')} القاعة بدري.';
  }
}

/// A month with the Hijri months it spans.
class _MonthTile extends StatelessWidget {
  const _MonthTile({
    required this.month,
    required this.selected,
    required this.onTap,
  });

  final DateTime month;
  final bool selected;
  final VoidCallback onTap;

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
        : '${first.monthName} · ${last.monthName}';
    final fg = selected ? AarastV3Color.onPrimary : AarastV3Color.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: '${arabicMonthName(month.month)} ${month.year}، $hijri',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        selected: selected,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? context.accent.primary : AarastV3Color.paper,
            borderRadius: BorderRadius.circular(14),
            border: selected ? null : Border.all(color: AarastV3Color.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                arabicMonthName(month.month),
                style: JourneyType.of(
                  JourneyType.bodyLarge,
                  weight: JourneyType.bold,
                  color: fg,
                ),
              ),
              Text(
                hijri,
                textAlign: TextAlign.center,
                style: JourneyType.of(
                  JourneyType.caption,
                  color: selected
                      ? AarastV3Color.onPrimaryMuted
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

/// a05: the city (the provider directory's cities) and a rough budget,
/// typed and spelled out in words.
class _PlaceBudgetStep extends StatelessWidget {
  const _PlaceBudgetStep({
    required this.cities,
    required this.city,
    required this.budgetController,
    required this.budgetSkipped,
    required this.onCity,
    required this.onMoreCities,
    required this.onBudgetChanged,
    required this.onSkipBudget,
    required this.onNext,
    required this.onBack,
  });

  final List<String> cities;
  final String? city;
  final TextEditingController budgetController;
  final bool budgetSkipped;
  final ValueChanged<String> onCity;
  final VoidCallback onMoreCities;
  final VoidCallback onBudgetChanged;
  final VoidCallback onSkipBudget;
  final VoidCallback? onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final shown = cities.take(7).toList();
    final extra = city != null && !shown.contains(city) ? city : null;
    final digits = budgetController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = int.tryParse(digits);
    return JourneyQuestionPage(
      step: 1,
      total: _questionCount,
      question: 'وين العرس، وكم ميزانيتك تقريبًا؟',
      help: 'نعرض لك مزودين وأسعار من مدينتك. رقم تقريبي يكفي.',
      // a06 (the mahr) follows.
      primaryLabel: 'التالي',
      onPrimary: onNext,
      onBack: onBack,
      children: [
        const _FieldLabel('المدينة'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in [...shown, ?extra])
              // a05 draws the cities a step larger than other chips.
              JourneyChip(
                label: name,
                selected: name == city,
                icon: name == city ? LucideIcons.mapPin : null,
                fontSize: JourneyType.body,
                onTap: () => onCity(name),
              ),
            JourneyChip(
              label: 'مدينة ثانية',
              icon: LucideIcons.plus,
              fontSize: JourneyType.body,
              onTap: onMoreCities,
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _FieldLabel('ميزانية عرسك تقريبًا (بالريال اليمني)'),
        JourneyTextField(
          label: 'المبلغ',
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
          onChanged: (_) => onBudgetChanged(),
        ),
        const SizedBox(height: 6),
        _RadioLine(
          label: context.say('أكمل بدون ميزانية', 'أكملي بدون ميزانية'),
          selected: budgetSkipped,
          onTap: onSkipBudget,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            // C1: the budget is the wedding only; the mahr is its own
            // question next (a06), outside the budget.
            context.say(
              'الميزانية لعرسك بس، والمهر مش منها. وتقدر تغيّرها بعدين من المال.',
              'الميزانية لعرسك بس، والمهر مش منها. وتقدرين تغيّرينها بعدين من المال.',
            ),
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// a08 «خطتك جاهزة»: what the plan starts with, then save it with the
/// phone number or look around first.
class _ReadyStep extends StatelessWidget {
  const _ReadyStep({
    required this.name,
    required this.subtitle,
    required this.city,
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
  final String city;

  /// x01: without a date nothing is placed on one yet, so nothing says so.
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
        ? items.join('، ')
        : '${items.take(4).join(' و')} وغيرها';
    return JourneyPage(
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error != null) ...[
            JourneyNote(
              text: error!,
              icon: LucideIcons.alertCircle,
              color: AarastV3Color.danger,
              soft: AarastV3Color.dangerSoft,
            ),
            const SizedBox(height: 10),
          ],
          if (signedIn)
            JourneyButton(
              label: 'افتح خطتي',
              onPressed: saving ? null : onOpenPlan,
              loading: saving,
              expand: true,
              large: true,
            )
          else ...[
            JourneyButton(
              label: 'احفظ خطتي برقم جوالي',
              icon: LucideIcons.phoneCall,
              onPressed: saving ? null : onSaveWithPhone,
              loading: saving,
              expand: true,
              large: true,
            ),
            const SizedBox(height: 6),
            JourneyTextAction(
              label: 'بعدين، خلني أشوف أول',
              onPressed: saving ? null : onLookFirst,
            ),
          ],
        ],
      ),
      children: [
        JourneySubHeader(title: '', onBack: onBack),
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: context.accent.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.partyPopper,
              size: 50,
              color: context.accent.primary,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Center(
          child: Semantics(
            header: true,
            child: Text(
              'خطتك جاهزة يا $name',
              textAlign: TextAlign.center,
              style: JourneyType.of(
                JourneyType.display,
                weight: JourneyType.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: JourneyType.of(
              JourneyType.body,
              color: AarastV3Color.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 20),
        JourneyList(
          dividers: false,
          children: [
            JourneyListRow(
              icon: LucideIcons.wallet,
              color: context.accent.primary,
              soft: context.accent.primarySoft,
              title:
                  '${arabicCount(items.length, one: 'بند واحد', two: 'بندين', few: 'بنود', many: 'بند')} لعرسك',
              subtitle: itemsLine,
            ),
            if (catalogs.taskCount > 0)
              JourneyListRow(
                icon: LucideIcons.listChecks,
                color: AarastV3Color.brandAccentStrong,
                soft: AarastV3Color.brandAccentSoft,
                title:
                    '${arabicCount(catalogs.taskCount, one: 'مهمة واحدة', two: 'مهمتين', few: 'مهام', many: 'مهمة')} مقترحة${hasDate ? ' على موعدك' : ''}',
                subtitle: hasDate
                    ? context.say(
                        'تختار منها اللي يناسبك بعد الحفظ',
                        'تختارين منها اللي يناسبك بعد الحفظ',
                      )
                    : context.say(
                        'تختار منها اللي يناسبك، وترتبها لما تحدد الموعد',
                        'تختارين منها اللي يناسبك، وترتبينها لما تحددين الموعد',
                      ),
              ),
            JourneyListRow(
              icon: LucideIcons.store,
              color: AarastV3Color.cobalt,
              soft: AarastV3Color.cobaltSoft,
              title: 'مزودين $city بأسعارهم',
              subtitle: context.say(
                'قاعات ومصورين ومنشدين',
                'صالات ومصورات ومنشدات',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            hasDate
                ? context.say(
                    'تشيل وتضيف براحتك، والمهام تمشي مع الموعد لو تغيّر.',
                    'تشيلين وتضيفين براحتك، والمهام تمشي مع الموعد لو تغيّر.',
                  )
                : context.say(
                    'تشيل وتضيف براحتك، وتحدد الموعد متى ما ثبت.',
                    'تشيلين وتضيفين براحتك، وتحددين الموعد متى ما ثبت.',
                  ),
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
        ),
      ],
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
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in widget.cities)
              JourneyChip(
                label: name,
                selected: name == widget.selected,
                onTap: () => Navigator.of(context).pop(name),
              ),
          ],
        ),
        const SizedBox(height: 18),
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
        const SizedBox(height: 12),
        JourneyButton(
          label: context.say('اختر هذي المدينة', 'اختاري هذي المدينة'),
          onPressed: _typed.text.trim().isEmpty ? null : _useTyped,
          expand: true,
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
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
}

/// A round radio with a label, for the «not yet» answers.
class _RadioLine extends StatelessWidget {
  const _RadioLine({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        selected: selected,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          // A 48 target (DESIGN_SYSTEM: touch ≥ 48).
          constraints: const BoxConstraints(minHeight: AarastV3Space.x12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? context.accent.primary
                          : AarastV3Color.line,
                      width: selected ? 7 : 2,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                      color: selected
                          ? AarastV3Color.ink
                          : AarastV3Color.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
