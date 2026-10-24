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
  /// (w12 to w15) ship (D27). An archived plan cannot be opened again.
  Future<void> _confirmArchive(WeddingPlan plan) async {
    final confirmed = await showAarastBottomSheet<bool>(
      context: context,
      backgroundColor: AarastV3Color.canvas,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تحط الخطة في الأرشيف؟',
                style: JourneyType.of(
                  JourneyType.display,
                  weight: JourneyType.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '«${plan.title}» تنتقل للأرشيف وبياناتها تبقى محفوظة، بس ما '
                'تقدر تفتحها بعدها من التطبيق.',
                style: JourneyType.of(
                  JourneyType.body,
                  color: AarastV3Color.textMuted,
                ),
              ),
              const SizedBox(height: 18),
              JourneyButton(
                key: const ValueKey('plan-archive-confirm'),
                label: 'حطها في الأرشيف',
                icon: LucideIcons.archive,
                background: AarastV3Color.danger,
                large: true,
                expand: true,
                onPressed: () => Navigator.pop(sheetContext, true),
              ),
              const SizedBox(height: 10),
              JourneyButton(
                label: 'رجوع',
                background: AarastV3Color.paper,
                foreground: AarastV3Color.ink,
                expand: true,
                onPressed: () => Navigator.pop(sheetContext, false),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<WeddingPlansProvider>();
    final archived = await provider.archiveWeddingPlan(plan.id);
    if (!mounted) return;
    if (archived == null) {
      _showError(provider.errorMessage ?? 'ما قدرنا نأرشف الخطة.');
      return;
    }
    context.go(AppRouter.weddingPlans);
  }
}

String _newUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
