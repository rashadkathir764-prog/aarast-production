part of 'plan_management_screen.dart';

extension _PlanCenterPlanEdit on _PlanCenterScreenState {
  /// w10 «حفظ»: the name and a first day go to the plan, the budget to the
  /// plan's money. A plan kept on this phone saves to its draft.
  Future<bool> _saveDetails(
    WeddingPlan plan, {
    String? title,
    DateTime? firstDay,
    String? budgetTotal,
    String? city,
    bool? budgetIncludesMahr,
  }) async {
    if (_isLocalPlan && (title != null || firstDay != null)) {
      final saved = await _saveLocalDetails(title: title, firstDay: firstDay);
      if (!saved || !mounted) return false;
    } else if (title != null || firstDay != null || city != null) {
      final provider = context.read<WeddingPlansProvider>();
      final updated = await provider.updateWeddingPlan(plan.id, {
        'title': ?title,
        if (firstDay != null) 'weddingDate': planDayToJson(firstDay),
        // RA-MO-155: a plan made without a city sets it here.
        'city': ?city,
      });
      if (!mounted) return false;
      if (updated == null) {
        _showError(
          provider.errorMessage ??
              context.say(
                'ما قدرنا نحفظ. جرّب مرة ثانية.',
                'ما قدرنا نحفظ. جرّبي مرة ثانية.',
              ),
        );
        return false;
      }
    }
    if (budgetTotal != null) {
      final finance = context.read<FinanceProvider>();
      if (finance.loadedPlanId != plan.id || !finance.hasLoadedMoney) {
        await finance.loadMoney(plan.id);
        if (!mounted) return false;
      }
      final saved = await finance.setTotalBudget(
        planId: plan.id,
        totalBudget: budgetTotal.isEmpty ? null : budgetTotal,
      );
      if (!mounted) return false;
      if (!saved) {
        _showError(
          finance.errorMessage ??
              context.say(
                'ما قدرنا نحفظ الميزانية. جرّب مرة ثانية.',
                'ما قدرنا نحفظ الميزانية. جرّبي مرة ثانية.',
              ),
        );
        return false;
      }
    }
    // D114: the mahr's place is saved after the budget, on its own: a
    // refusal of it (a plan that does not pay the mahr, a server that does
    // not know the choice yet) never takes the budget with it.
    if (budgetIncludesMahr != null) {
      final finance = context.read<FinanceProvider>();
      if (finance.loadedPlanId != plan.id || !finance.hasLoadedMoney) {
        await finance.loadMoney(plan.id);
        if (!mounted) return false;
      }
      final saved = await finance.saveBudget(
        planId: plan.id,
        totalBudget: finance.summary.budget.total,
        currency: finance.summary.currency,
        categories: [
          for (final item in finance.budgetItems)
            (
              id: item.id,
              name: item.name,
              allocatedAmount: item.allocatedAmount,
            ),
        ],
        budgetIncludesMahr: budgetIncludesMahr,
      );
      if (!mounted) return false;
      if (!saved) {
        final reason =
            finance.errorMessage ??
            context.say('جرّب مرة ثانية بعد شوي.', 'جرّبي مرة ثانية بعد شوي.');
        _showError(
          budgetTotal != null
              ? 'انحفظت الميزانية، بس ما انحفظ مكان المهر منها. $reason'
              : 'ما انحفظ مكان المهر من الميزانية. $reason',
        );
        return false;
      }
    }
    if (!_isLocalPlan) {
      await context.read<DashboardSummaryProvider>().loadDashboard(
        plan.id,
        sharedMember: widget.sharedMember,
      );
    }
    if (mounted) _showSuccess('انحفظت بيانات الخطة.');
    return true;
  }

  Future<bool> _saveLocalDetails({String? title, DateTime? firstDay}) async {
    final storage = context.read<GuestOnboardingStorage>();
    final draft = await storage.loadGuestPlan();
    if (draft == null) {
      if (mounted) _showError('ما لقينا الخطة على هذا الجوال.');
      return false;
    }
    await storage.saveDraft(
      draft.copyWith(
        planName: title ?? draft.planName,
        weddingDate: firstDay ?? draft.weddingDate,
        weddingDateUnknown: firstDay == null ? draft.weddingDateUnknown : false,
      ),
    );
    await _loadLocalPlan();
    return true;
  }

  /// g03 for a plan with a day: the sheet moves the day and the tasks.
  Future<void> _postpone(WeddingPlan plan) async {
    final day = plan.weddingDate;
    if (day == null) return;
    final moved = await showPostponeSheet(
      context,
      planId: plan.id,
      weddingDate: day,
    );
    if (moved && mounted) await _load();
  }

  /// Archive stays reachable from w10 until the plan lifecycle screens
  /// (w12 to w15) ship (D27). D112 (Q-21): the archived plan is read by its
  /// owner and changed by no one; the sheet said it could not be opened
  /// again. RA-MO-159: one name for it, «الذكريات».
  Future<void> _confirmArchive(WeddingPlan plan) async {
    // G15: say what is still owed before the plan closes. The server keeps
    // reminding of payment dates and loan repayments after archiving.
    final finance = context.read<FinanceProvider>();
    // RA-MO-152: the money is this plan's, read now; another plan's (or a
    // read that failed and counted nothing) said nothing was owed.
    if (finance.loadedPlanId != plan.id || finance.loadErrorMessage != null) {
      await finance.loadMoney(plan.id);
      if (!mounted) return;
    }
    final moneyKnown =
        finance.loadedPlanId == plan.id && finance.loadErrorMessage == null;
    final money = finance.summary;
    // RA-MO-92 (D59, D102): «باقي عليك» is the owner's own remainder, not
    // what the family pays; every agreement's only from a server before it.
    final owed = moneyKnown
        ? moneyValue(money.outstanding?.owner ?? money.costs.outstanding) +
              moneyValue(money.funding?.loanOutstanding)
        : 0;
    // In the reader's words; the amount follows «أخفِ المبالغ» (G17).
    final owedLine = !moneyKnown
        ? '\n\nما قدرنا نقرأ مالك الحين، فما نعرف إذا باقي عليك شي. '
              'التذكير بمواعيد الدفعات والسلف يستمر بعدها.'
        : owed > 0
        ? '\n\nباقي عليك ${finance.shownAmount(formatFullMoney(owed, currencyCode: money.currency))} من '
              'الاتفاقات والسلف. التذكير بمواعيدها يستمر بعدها، '
              '${context.say('والأفضل تخليها مفتوحة لين تسدّد.', 'والأفضل تخلّينها مفتوحة لين تسدّدين.')}'
        : '';
    final confirmed = await showJourneySheet<bool>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title: context.say(
          'تحط الخطة في الذكريات؟',
          'تحطين الخطة في الذكريات؟',
        ),
        subtitle:
            '«${plan.title}» تنتقل للذكريات: تبقى محفوظة و'
            '${context.say('تقدر تقرأها', 'تقدرين تقرئينها')} من «خططك»، '
            'بس ما تنعدل بعدها.$owedLine',
        children: [
          JourneyButton(
            key: const ValueKey('plan-archive-confirm'),
            label: context.say('حطها في الذكريات', 'حطيها في الذكريات'),
            icon: LucideIcons.archive,
            background: AarastV3Color.danger,
            large: true,
            expand: true,
            onPressed: () => Navigator.pop(sheetContext, true),
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyButton(
            label: 'رجوع',
            background: AarastV3Color.paper,
            foreground: AarastV3Color.ink,
            expand: true,
            onPressed: () => Navigator.pop(sheetContext, false),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<WeddingPlansProvider>();
    final archived = await provider.archiveWeddingPlan(plan.id);
    if (!mounted) return;
    if (archived == null) {
      _showError(provider.errorMessage ?? 'ما قدرنا ننقل الخطة للذكريات.');
      return;
    }
    // RA-MO-143: the account's paths are read again, so the plan is a
    // memory on this phone from this moment (it stayed a live plan here,
    // and its home opened with buttons the server refused). The home then
    // shows it as its owner reads it.
    final router = GoRouter.of(context);
    await context.read<AccountContextController?>()?.refresh();
    router.go(AppRouter.home);
  }

  /// Q-45 (D124): deleting a plan has no way back after its 30 days, so it
  /// is asked twice: what goes and when, then the last word.
  Future<void> _confirmDelete(WeddingPlan plan) async {
    final goOn = await showJourneySheet<bool>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title: context.say('تحذف الخطة؟', 'تحذفين الخطة؟'),
        subtitle:
            '«${plan.title}» تنقفل من الحين عندك وعند المشاركين، وبعد 30 يوم '
            'تنحذف كلها: الضيوف والدعوات والمهام والمواعيد والمال والمحادثات '
            'والتنبيهات. لين ذاك اليوم '
            '${context.say('تقدر ترجعها', 'تقدرين ترجعينها')} من هنا.',
        children: [
          JourneyButton(
            key: const ValueKey('plan-delete-next'),
            label: context.say('كمّل', 'كمّلي'),
            icon: LucideIcons.trash2,
            background: AarastV3Color.danger,
            large: true,
            expand: true,
            onPressed: () => Navigator.pop(sheetContext, true),
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyButton(
            label: 'رجوع',
            background: AarastV3Color.paper,
            foreground: AarastV3Color.ink,
            expand: true,
            onPressed: () => Navigator.pop(sheetContext, false),
          ),
        ],
      ),
    );
    if (goOn != true || !mounted) return;
    final confirmed = await showJourneySheet<bool>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title: context.say('متأكد؟', 'متأكدة؟'),
        subtitle: 'بعد 30 يوم ما نقدر نرجّع منها شي أبدًا.',
        children: [
          JourneyButton(
            key: const ValueKey('plan-delete-confirm'),
            label: context.say('إيوه، احذفها', 'إيوه، احذفيها'),
            background: AarastV3Color.danger,
            large: true,
            expand: true,
            onPressed: () => Navigator.pop(sheetContext, true),
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyButton(
            key: const ValueKey('plan-delete-keep'),
            label: context.say('لا، خلّها', 'لا، خلّيها'),
            background: AarastV3Color.paper,
            foreground: AarastV3Color.ink,
            expand: true,
            onPressed: () => Navigator.pop(sheetContext, false),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _setDeletion(plan, restore: false);
  }

  /// Q-45 (D124): asks for the deletion, or takes it back, then reads the
  /// account's paths again (the plan closes to its members, or opens).
  Future<void> _setDeletion(WeddingPlan plan, {required bool restore}) async {
    final provider = context.read<WeddingPlansProvider>();
    final updated = await provider.setPlanDeletion(plan.id, restore: restore);
    if (!mounted) return;
    if (updated == null) {
      _showError(
        provider.errorMessage ??
            (restore ? 'ما قدرنا نرجّع الخطة.' : 'ما قدرنا نحذف الخطة.'),
      );
      return;
    }
    await context.read<AccountContextController?>()?.refresh();
    if (!mounted) return;
    _showSuccess(
      restore
          ? 'رجعت الخطة كما كانت.'
          : 'الخطة بتنحذف بعد 30 يوم، و${context.say('تقدر ترجعها', 'تقدرين ترجعينها')} قبلها.',
    );
    await _load();
  }
}
