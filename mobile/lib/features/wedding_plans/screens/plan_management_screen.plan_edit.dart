part of 'plan_management_screen.dart';

extension _PlanCenterPlanEdit on _PlanCenterScreenState {
  Future<void> _showEditPlan(
    WeddingPlan plan, {
    bool requireCompleteLocation = false,
  }) async {
    final result = await showAarastBottomSheet<PlanEditResult>(
      context: context,
      isScrollControlled: true,
      // A tall sheet must stay below the status bar (F09).
      useSafeArea: true,
      backgroundColor: AppTheme.canvas,
      builder: (_) => _PlanEditSheet(
        plan: plan,
        requireCompleteLocation: requireCompleteLocation,
        canChangeCurrency: _isLocalPlan,
      ),
    );
    if (result == null || !mounted) return;

    if (_isLocalPlan) {
      await _saveLocalEdit(result);
      return;
    }

    final provider = context.read<WeddingPlansProvider>();
    final updated = await provider.updateWeddingPlan(
      plan.id,
      result.toUpdateJson(),
    );
    if (!mounted) return;
    if (updated == null) {
      _showError(provider.errorMessage ?? 'تعذر تحديث الخطة.');
      return;
    }
    await context.read<DashboardSummaryProvider>().loadDashboard(
      plan.id,
      sharedMember: widget.sharedMember,
    );
    if (!mounted) return;
    _showSuccess('تم تحديث بيانات الخطة.');
    final moved = weddingDateShiftDays(plan.weddingDate, updated.weddingDate);
    if (moved != null && widget.sharedMember == null) {
      await _offerTaskDateShift(plan.id, moved);
    }
    final oldDay = plan.weddingDate;
    if (moved != null && oldDay != null && mounted) {
      await _warnOldDayBookings(plan.id, oldDay);
    }
  }

  /// The wedding moved (V1 checklist 4.13): name the bookings made with
  /// providers for the old day, which do not move on their own.
  Future<void> _warnOldDayBookings(String planId, DateTime oldDay) async {
    final List<PlanBookingDay> onOldDay;
    try {
      onOldDay = bookingsOnDay(
        await PlanBookingsLookup(context.read<ApiClient>()).list(planId),
        oldDay,
      );
    } on Object {
      // Offline or unavailable: the date change itself is saved.
      return;
    }
    if (onOldDay.isEmpty || !mounted) return;
    final openProviders = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AarastDialog(
        key: const ValueKey('old-day-bookings'),
        title: const Text('حجوزات على يوم العرس القديم'),
        content: Text(
          [
            for (final booking in onOldDay)
              '• ${booking.providerName} (${booking.confirmed ? 'حجز مؤكد' : 'طلب حجز'})',
            '',
            'هذه الحجوزات لا تنتقل وحدها. اطلب من كل مزوّد اليوم الجديد أو ألغِ '
                'الحجز من صفحة الطلب، حتى لا يبقى اليوم القديم محجوزًا لك.',
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('لاحقًا'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('فتح المزوّدين'),
          ),
        ],
      ),
    );
    if (openProviders == true && mounted) {
      context.go(AppRouter.planProviders(planId));
    }
  }

  /// The wedding moved (V1 checklist 4.13): offer to move the open dated
  /// tasks by the same days. Nothing moves unless the owner says so.
  Future<void> _offerTaskDateShift(String planId, int days) async {
    final direction = days > 0 ? 'تأخّر' : 'تقدّم';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AarastDialog(
        title: const Text('نقل مواعيد المهام؟'),
        content: Text(
          'موعد العرس $direction ${days.abs()} يومًا. ننقل مواعيد المهام غير '
          'المنجزة بنفس المدة؟ مواعيد الدفعات لا تتغير لأنها اتفاق مع المزوّد، '
          'وحجوزات المزوّدين ليوم العرس القديم تحتاج طلب اليوم الجديد منهم.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('لا، أبقِها'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('نعم، انقلها'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final shifted = await context.read<TaskTimelineApi>().shiftOpenDueDates(
        planId,
        days,
      );
      if (mounted) _showSuccess('نُقلت مواعيد $shifted مهمة.');
    } on Object {
      if (mounted) _showError('تعذر نقل مواعيد المهام. حاول مرة أخرى من الإعدادات لاحقًا.');
    }
  }

  Future<void> _saveLocalEdit(PlanEditResult result) async {
    final storage = context.read<GuestOnboardingStorage>();
    final draft = await storage.loadGuestPlan();
    if (draft == null) {
      if (mounted) _showError('تعذر العثور على الخطة المحلية.');
      return;
    }
    final location = result.location;
    final updated = draft.copyWith(
      planName: result.title,
      weddingDate: result.weddingDate,
      weddingDateUnknown: false,
      currency: result.currency,
      priorities: result.priorities,
      governorate: location?.governorate,
      city: location?.cityOrDistrict,
      district: location?.areaOrNeighborhood,
      street: location?.street,
      addressNote: location?.detailedAddress,
    );
    await storage.saveDraft(updated);
    await _loadLocalPlan();
    if (mounted) _showSuccess('تم تحديث الخطة على هذا الجهاز.');
  }

  Future<void> _confirmArchive(WeddingPlan plan) async {
    final confirmed = await showAarastBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.canvas,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  LucideIcons.archive,
                  color: AppTheme.danger,
                  size: 34,
                ),
                const SizedBox(height: 12),
                Text(
                  'أرشفة الخطة؟',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'سيتم نقل "${plan.title}" إلى الأرشيف دون حذف بياناتها.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.danger,
                        ),
                        onPressed: () => Navigator.pop(sheetContext, true),
                        icon: const Icon(LucideIcons.archive),
                        label: const Text('أرشفة'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<WeddingPlansProvider>();
    final archived = await provider.archiveWeddingPlan(plan.id);
    if (!mounted) return;
    if (archived == null) {
      _showError(provider.errorMessage ?? 'تعذر أرشفة الخطة.');
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

class _PlanEditSheet extends StatefulWidget {
  const _PlanEditSheet({
    required this.plan,
    required this.requireCompleteLocation,
    required this.canChangeCurrency,
  });

  final WeddingPlan plan;
  final bool requireCompleteLocation;

  /// Only a plan kept on this device can change currency; a server plan's
  /// currency is fixed at creation.
  final bool canChangeCurrency;

  @override
  State<_PlanEditSheet> createState() => _PlanEditSheetState();
}

class _PlanEditSheetState extends State<_PlanEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _governorate;
  late final TextEditingController _city;
  late final TextEditingController _area;
  late final TextEditingController _street;
  late final TextEditingController _details;
  late DateTime? _weddingDate;
  late String _currency;
  late Set<String> _priorities;
  String? _error;

  static const _priorityOptions = {
    'budget': 'الميزانية',
    'tasks': 'المهام',
    'guests': 'الضيوف',
    'providers': 'الموردون',
  };

  @override
  void initState() {
    super.initState();
    final location = widget.plan.weddingLocation;
    _title = TextEditingController(text: widget.plan.title);
    _governorate = TextEditingController(text: location.governorate ?? '');
    _city = TextEditingController(
      text: location.cityOrDistrict ?? widget.plan.city ?? '',
    );
    _area = TextEditingController(text: location.areaOrNeighborhood ?? '');
    _street = TextEditingController(text: location.street ?? '');
    _details = TextEditingController(text: location.detailedAddress ?? '');
    _weddingDate = widget.plan.weddingDate;
    _currency = _supportedCurrency(widget.plan.currency);
    _priorities = widget.plan.priorities.toSet();
  }

  @override
  void dispose() {
    _title.dispose();
    _governorate.dispose();
    _city.dispose();
    _area.dispose();
    _street.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    releaseFieldFocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _weddingDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _weddingDate = picked);
  }

  void _submit() {
    final title = _title.text.trim();
    final location = WeddingLocationDraft(
      governorate: _clean(_governorate.text),
      cityOrDistrict: _clean(_city.text),
      areaOrNeighborhood: _clean(_area.text),
      street: _clean(_street.text),
      detailedAddress: _clean(_details.text),
    );
    if (title.isEmpty) {
      setState(() => _error = 'اسم الخطة مطلوب.');
      return;
    }
    if (widget.requireCompleteLocation && !location.hasRequiredLocation) {
      setState(() => _error = 'المحافظة والمدينة مطلوبتان لتحديث الموقع.');
      return;
    }

    Navigator.pop(
      context,
      PlanEditResult(
        title: title,
        weddingDate: _weddingDate,
        currency: _currency,
        priorities: _priorities.toList(growable: false),
        location: location.hasRequiredLocation ? location : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPriorities = {..._priorityOptions.keys, ...widget.plan.priorities};
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'تعديل بيانات الخطة',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'اسم الخطة'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(LucideIcons.calendar),
                  label: Text(
                    _weddingDate == null
                        ? 'اختيار تاريخ الزواج'
                        : '${_weddingDate!.day}/${_weddingDate!.month}/${_weddingDate!.year}',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'العملة',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.canChangeCurrency)
                  AarastChoicePillRow<String>(
                    value: _currency,
                    options: weddingCurrencyOptions,
                    onChanged: (value) => setState(() => _currency = value),
                  )
                else
                  Text(
                    '${currencyLabelAr(_currency)} — تُحدَّد العملة عند إنشاء الخطة.',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                const SizedBox(height: 18),
                Text(
                  'موقع الزفاف',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _governorate,
                  decoration: const InputDecoration(labelText: 'المحافظة'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _city,
                  decoration: const InputDecoration(
                    labelText: 'المدينة / المديرية',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _area,
                  decoration: const InputDecoration(
                    labelText: 'الحي / المنطقة',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _street,
                  decoration: const InputDecoration(labelText: 'الشارع'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _details,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'العنوان التفصيلي',
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'الأولويات',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final priority in allPriorities)
                      FilterChip(
                        label: Text(_priorityOptions[priority] ?? priority),
                        selected: _priorities.contains(priority),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _priorities.add(priority);
                            } else {
                              _priorities.remove(priority);
                            }
                          });
                        },
                      ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(LucideIcons.save),
                  label: const Text('حفظ التعديلات'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _clean(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _supportedCurrency(String value) {
  final normalized = value.toUpperCase();
  return const {'YER', 'SAR', 'USD'}.contains(normalized) ? normalized : 'YER';
}
