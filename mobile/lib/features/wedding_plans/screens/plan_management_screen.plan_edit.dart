part of 'plan_management_screen.dart';

extension _PlanCenterPlanEdit on _PlanCenterScreenState {
  /// w10 «حفظ»: the name and a first day go to the plan, the budget to the
  /// plan's money. A plan kept on this phone saves to its draft.
  Future<bool> _saveDetails(
    WeddingPlan plan, {
    String? title,
    DateTime? firstDay,
    String? budgetTotal,
  }) async {
    if (_isLocalPlan && (title != null || firstDay != null)) {
      final saved = await _saveLocalDetails(title: title, firstDay: firstDay);
      if (!saved || !mounted) return false;
    } else if (title != null || firstDay != null) {
      final provider = context.read<WeddingPlansProvider>();
      final updated = await provider.updateWeddingPlan(plan.id, {
        'title': ?title,
        if (firstDay != null) 'weddingDate': planDayToJson(firstDay),
      });
      if (!mounted) return false;
      if (updated == null) {
        _showError(provider.errorMessage ?? 'ما قدرنا نحفظ. جرّب مرة ثانية.');
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
          finance.errorMessage ?? 'ما قدرنا نحفظ الميزانية. جرّب مرة ثانية.',
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
    final owed = moneyKnown
        ? moneyValue(money.costs.outstanding) +
              moneyValue(money.funding?.loanOutstanding)
        : 0;
    // In the reader's words; the amount follows «أخفِ المبالغ» (G17).
    final owedLine = !moneyKnown
        ? '\n\nما قدرنا نقرأ مالك الحين، فما نعرف إذا باقي عليك شي. '
              'التذكير بمواعيد الدفعات والسلف يستمر بعدها.'
        : owed > 0
        ? '\n\nباقي عليك ${finance.shownAmount(formatCompactMoney(owed, currencyCode: money.currency))} من '
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
}
