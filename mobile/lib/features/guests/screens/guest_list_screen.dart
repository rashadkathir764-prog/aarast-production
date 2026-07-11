import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:provider/provider.dart';

import '../../../core/contacts/contact_duplicate_utils.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../shared/widgets/contact_phone_field.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../models/guest.dart';
import '../providers/guests_provider.dart';
import '../utils/guest_display.dart';
import '../widgets/premium/guest_meter_hero.dart';
import '../widgets/premium/smart_guest_card.dart';

class GuestListScreen extends StatefulWidget {
  const GuestListScreen({
    required this.weddingPlanId,
    this.showLocalFab = true,
    this.openAddOnStart = false,
    this.openAddRequest = 0,
    super.key,
  });

  final String weddingPlanId;
  final bool showLocalFab;
  final bool openAddOnStart;
  final int openAddRequest;

  @override
  State<GuestListScreen> createState() => _GuestListScreenState();
}

class _GuestListScreenState extends State<GuestListScreen> {
  _GuestFilter _filter = _GuestFilter.all;

  bool get _isLocalExploration =>
      AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
      unawaited(_openAddSheetIfRequested());
    });
  }

  @override
  void didUpdateWidget(covariant GuestListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _load();
      });
    }
    if ((!oldWidget.openAddOnStart && widget.openAddOnStart) ||
        oldWidget.openAddRequest != widget.openAddRequest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_openAddSheetIfRequested());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuestsProvider>();
    final planIdReady = widget.weddingPlanId.trim().isNotEmpty;

    return AarastScreenFrame(
      maxWidth: 520,
      floatingActionButton: widget.showLocalFab
          ? FloatingActionButton(
              backgroundColor: AppTheme.gold,
              foregroundColor: Colors.white,
              onPressed: planIdReady && !provider.isSubmitting
                  ? () => _showGuestSheet(provider: provider)
                  : null,
              child: const Icon(LucideIcons.plus),
            )
          : null,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: _GuestsHeader(guestCount: provider.guests.length),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.burgundy,
              onRefresh: _isLocalExploration ? () async {} : _load,
              child: _GuestsContent(
                provider: provider,
                weddingPlanId: widget.weddingPlanId,
                planIdReady: planIdReady,
                isLocalPlan: _isLocalExploration,
                filter: _filter,
                onFilterChanged: (filter) => setState(() => _filter = filter),
                onAddGuest: () => _showGuestSheet(provider: provider),
                onEditGuest: (guest) =>
                    _showGuestSheet(provider: provider, guest: guest),
                onStatus: _updateStatus,
                onDelete: _confirmDelete,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _load() {
    return context.read<GuestsProvider>().loadGuests(widget.weddingPlanId);
  }

  Future<void> _openAddSheetIfRequested() async {
    if ((!widget.openAddOnStart && widget.openAddRequest <= 0) ||
        widget.weddingPlanId.trim().isEmpty) {
      return;
    }
    await _showGuestSheet(provider: context.read<GuestsProvider>());
    if (!mounted) return;
    if (widget.openAddOnStart) {
      context.go(AppRouter.guestList(widget.weddingPlanId));
    }
  }

  Future<void> _showGuestSheet({
    required GuestsProvider provider,
    Guest? guest,
  }) async {
    final result = await showModalBottomSheet<_GuestSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GuestFormSheet(
        guest: guest,
        existingGuests: provider.guests,
        groups: provider.groups,
        blockDuplicatePhone: !_isLocalExploration,
      ),
    );

    if (result == null || !mounted) return;
    if (await AuthActionGuard.blockCloudSubmitForNonLocalPlanning(
      context,
      weddingPlanId: widget.weddingPlanId,
    )) {
      return;
    }
    if (!mounted) return;

    final ok = guest == null
        ? await provider.createGuest(
            weddingPlanId: widget.weddingPlanId,
            name: result.name,
            phone: result.phone,
            groupId: result.groupId,
            side: result.side,
            status: result.status,
            attendanceStatus: _attendanceFromStatus(result.status),
            seatsCount: result.seatsCount,
            companionsCount: result.companionsCount,
            notes: result.notes,
          )
        : await provider.updateGuest(
            guest: guest,
            name: result.name,
            phone: result.phone ?? '',
            groupId: result.groupId ?? '',
            side: result.side,
            status: result.status,
            attendanceStatus: _attendanceFromStatus(result.status),
            seatsCount: result.seatsCount,
            companionsCount: result.companionsCount,
            notes: result.notes,
          );
    if (!mounted) return;
    if (ok) {
      final message = provider.noticeMessage ?? 'تم حفظ الضيف.';
      AarastToast.showSuccess(context, message);
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'تعذر حفظ الضيف.',
      );
    }
  }

  Future<void> _updateStatus(Guest guest, String status) async {
    await context.read<GuestsProvider>().updateGuest(
      guest: guest,
      status: status,
      attendanceStatus: _attendanceFromStatus(status),
    );
  }

  Future<void> _confirmDelete(Guest guest) async {
    final provider = context.read<GuestsProvider>();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SheetHandle(),
                  const SizedBox(height: 20),
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppTheme.dangerSoft,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: const Icon(
                      LucideIcons.trash2,
                      color: AppTheme.danger,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'حذف الضيف؟',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    guest.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(sheetContext).textTheme.bodyMedium
                        ?.copyWith(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: AarastButton(
                          label: 'إلغاء',
                          variant: AarastButtonVariant.secondary,
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AarastButton(
                          label: 'حذف',
                          icon: LucideIcons.trash2,
                          variant: AarastButtonVariant.danger,
                          onPressed: () => Navigator.of(sheetContext).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      final ok = await provider.deleteGuest(guest);
      if (ok && mounted) {
        AarastToast.showSuccess(context, 'تم حذف الضيف.');
      }
    }
  }
}

class _GuestsHeader extends StatelessWidget {
  const _GuestsHeader({required this.guestCount});

  final int guestCount;

  @override
  Widget build(BuildContext context) {
    // ترويسة مضغوطة: عنوان + عداد حي — لا شارة زخرفية ثابتة.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            'الضيوف',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppTheme.title),
          ),
        ),
        const SizedBox(width: 10),
        if (guestCount > 0)
          AarastStatusPill(
            label: '$guestCount ضيف',
            color: AppTheme.burgundy,
            backgroundColor: AppTheme.burgundySoft,
            icon: LucideIcons.users,
          ),
      ],
    );
  }
}

class _GuestsContent extends StatelessWidget {
  const _GuestsContent({
    required this.provider,
    required this.weddingPlanId,
    required this.planIdReady,
    required this.isLocalPlan,
    required this.filter,
    required this.onFilterChanged,
    required this.onAddGuest,
    required this.onEditGuest,
    required this.onStatus,
    required this.onDelete,
  });

  final GuestsProvider provider;
  final String weddingPlanId;
  final bool planIdReady;
  final bool isLocalPlan;
  final _GuestFilter filter;
  final ValueChanged<_GuestFilter> onFilterChanged;
  final VoidCallback onAddGuest;
  final ValueChanged<Guest> onEditGuest;
  final void Function(Guest guest, String status) onStatus;
  final ValueChanged<Guest> onDelete;

  @override
  Widget build(BuildContext context) {
    if (!planIdReady) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 70, 16, 120),
        children: const [
          AarastEmptyState(
            icon: LucideIcons.calendarX,
            title: 'اختر خطة أولاً',
            message: 'لا يمكن إدارة الضيوف بدون خطة زفاف محددة.',
          ),
        ],
      );
    }

    if (provider.isLoading && provider.guests.isEmpty) {
      return const _GuestLoadingState();
    }

    if (provider.errorMessage != null && provider.guests.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 70, 16, 120),
        children: [
          AarastEmptyState(
            icon: LucideIcons.alertCircle,
            title: 'تعذر تحميل الضيوف',
            message: provider.errorMessage!,
            action: OutlinedButton.icon(
              onPressed: () => provider.loadGuests(weddingPlanId),
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }

    final guests = provider.guests;
    final summary = provider.summary.weddingPlanId.isEmpty
        ? GuestSummary.fromGuests(
            weddingPlanId: weddingPlanId,
            guests: guests,
            groups: provider.groups,
          )
        : provider.summary;
    final duplicates = _duplicateGuests(guests);
    final importantIssues = _importantIssues(summary, duplicates);
    final visibleGuests = _filteredGuests(guests, filter);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 132),
      children: [
        if (provider.errorMessage != null) ...[
          _InlineError(message: provider.errorMessage!),
          const SizedBox(height: 14),
        ],
        GuestMeterHero(summary: summary, isLocalPlan: isLocalPlan),
        const SizedBox(height: 12),
        _ImportantGuestsCard(
          issues: importantIssues,
          onOpenFilter: onFilterChanged,
        ),
        const SizedBox(height: 14),
        _GuestFilterBar(selected: filter, onChanged: onFilterChanged),
        const SizedBox(height: 20),
        AarastSectionHeader(
          title: _listTitle(filter),
          icon: LucideIcons.users,
        ),
        const SizedBox(height: 12),
        if (visibleGuests.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              _emptyGuestsMessage(filter),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          for (var i = 0; i < visibleGuests.length; i++) ...[
            _staggeredGuest(
              SmartGuestCard(
                guest: visibleGuests[i],
                groupLabel: _groupLabel(visibleGuests[i], provider.groups),
                isDuplicate: duplicates.contains(visibleGuests[i].id),
                isBusy: provider.isSubmitting,
                onEdit: () => onEditGuest(visibleGuests[i]),
                onStatus: (status) => onStatus(visibleGuests[i], status),
                onDelete: () => onDelete(visibleGuests[i]),
              ),
              i,
              MediaQuery.of(context).disableAnimations,
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _ImportantGuestsCard extends StatelessWidget {
  const _ImportantGuestsCard({
    required this.issues,
    required this.onOpenFilter,
  });

  final List<_GuestIssue> issues;
  final ValueChanged<_GuestFilter> onOpenFilter;

  @override
  Widget build(BuildContext context) {
    // كل شيء مكتمل؟ شريط نجاح هادئ بسطر واحد — لا كرت عنوانه أكبر من خبره.
    if (issues.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.successBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.badgeCheck,
              color: AppTheme.success,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'كل بيانات الضيوف مكتملة',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.ink,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AarastCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.alertTriangle,
                color: AppTheme.burgundy,
                size: 17,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'يحتاج متابعة',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final issue in issues) ...[
            _IssueRow(issue: issue, onTap: () => onOpenFilter(issue.filter)),
            if (issue != issues.last) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue, required this.onTap});

  final _GuestIssue issue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: issue.color.withAlpha(11),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            Icon(issue.icon, color: issue.color, size: 15),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                issue.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${issue.count}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: issue.color,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.chevronLeft,
              size: 14,
              color: AppTheme.muted.withAlpha(180),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestFilterBar extends StatelessWidget {
  const _GuestFilterBar({required this.selected, required this.onChanged});

  final _GuestFilter selected;
  final ValueChanged<_GuestFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filterItems.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _filterItems[index];
          final isSelected = item.filter == selected;
          return InkWell(
            key: ValueKey('guest-filter-${item.filter.name}'),
            onTap: () => onChanged(item.filter),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: AppTheme.motionFast,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.burgundy : AppTheme.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? AppTheme.burgundy : AppTheme.border,
                ),
                boxShadow: isSelected ? AppTheme.cardShadow() : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    size: 16,
                    color: isSelected ? Colors.white : AppTheme.burgundy,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isSelected ? Colors.white : AppTheme.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GuestFormSheet extends StatefulWidget {
  const _GuestFormSheet({
    required this.existingGuests,
    required this.groups,
    required this.blockDuplicatePhone,
    this.guest,
  });

  final Guest? guest;
  final List<Guest> existingGuests;
  final List<GuestGroup> groups;
  final bool blockDuplicatePhone;

  @override
  State<_GuestFormSheet> createState() => _GuestFormSheetState();
}

class _GuestFormSheetState extends State<_GuestFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;
  late String _side;
  late String _status;
  late String? _groupId;
  late int _seatsCount;
  late int _companionsCount;
  String? _sheetError;

  @override
  void initState() {
    super.initState();
    final guest = widget.guest;
    _nameController = TextEditingController(text: guest?.name ?? '');
    _phoneController = TextEditingController(text: guest?.phone ?? '');
    _notesController = TextEditingController(text: guest?.notes ?? '');
    _nameController.addListener(_handleContactChanged);
    _phoneController.addListener(_handleContactChanged);
    _side = _supportedSide(guest?.side);
    _status = guest?.status ?? 'INVITED';
    _groupId =
        widget.groups.isEmpty ||
            widget.groups.any((group) => group.id == guest?.groupId)
        ? guest?.groupId
        : null;
    _seatsCount = guest?.seatsCount ?? 1;
    _companionsCount = guest?.companionsCount ?? 0;
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleContactChanged)
      ..dispose();
    _phoneController
      ..removeListener(_handleContactChanged)
      ..dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleContactChanged() {
    if (mounted) setState(() {});
  }

  Guest? get _duplicatePhoneGuest {
    return ContactDuplicateUtils.findByPhone(
      widget.existingGuests,
      candidatePhone: _phoneController.text,
      phoneOf: (guest) => guest.phone,
      exclude: (guest) => guest.id == widget.guest?.id,
    );
  }

  bool get _hasSoftNameDuplicate {
    if (_phoneController.text.trim().isNotEmpty) return false;
    return widget.existingGuests.any(
      (guest) =>
          guest.id != widget.guest?.id &&
          ContactDuplicateUtils.sameName(guest.name, _nameController.text),
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _sheetError = 'اسم الضيف مطلوب');
      return;
    }

    if (_duplicatePhoneGuest != null && widget.blockDuplicatePhone) {
      setState(() => _sheetError = 'هذا الضيف موجود مسبقًا');
      return;
    }

    String? phone;
    try {
      phone = PhoneNumberUtils.normalizeOptional(_phoneController.text);
    } on FormatException {
      setState(() => _sheetError = PhoneNumberUtils.invalidMessage);
      return;
    }

    setState(() => _sheetError = null);
    Navigator.of(context).pop(
      _GuestSheetResult(
        name: name,
        phone: phone,
        groupId: _groupId,
        side: _side,
        status: _status,
        seatsCount: _seatsCount,
        companionsCount: _companionsCount,
        notes: _notesController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guest = widget.guest;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 18),
                Text(
                  guest == null ? 'إضافة ضيف' : 'تعديل ضيف',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الضيف',
                    prefixIcon: Icon(LucideIcons.user),
                  ),
                ),
                const SizedBox(height: 12),
                ContactPhoneField(
                  nameController: _nameController,
                  phoneController: _phoneController,
                  label: 'رقم الجوال (اختياري)',
                  duplicateMessage: _duplicatePhoneGuest == null
                      ? null
                      : 'هذا الضيف موجود مسبقًا',
                  onDraftChanged: (_) {
                    if (!mounted) return;
                    setState(() => _sheetError = null);
                  },
                ),
                if (_hasSoftNameDuplicate) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'يوجد ضيف بنفس الاسم دون رقم. يمكنك المتابعة إذا كان شخصًا آخر.',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // رقائق بدل القوائم المنسدلة — نفس نمط أدوار المشاركة:
                // كل الخيارات مرئية بنقرة واحدة.
                _ChipPickerRow(
                  label: 'الطرف',
                  options: [
                    for (final item in _sideValues)
                      _ChipOption(value: item, label: _sideLabel(item)),
                  ],
                  selected: _side,
                  onSelected: (value) => setState(() => _side = value),
                ),
                const SizedBox(height: 12),
                if (widget.groups.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _groupId,
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('بدون مجموعة'),
                      ),
                      for (final group in widget.groups)
                        DropdownMenuItem(
                          value: group.id,
                          child: Text(group.name),
                        ),
                    ],
                    onChanged: (value) {
                      setState(
                        () => _groupId = value?.isEmpty == true ? null : value,
                      );
                    },
                    decoration: const InputDecoration(
                      labelText: 'المجموعة',
                      prefixIcon: Icon(LucideIcons.folderOpen),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _ChipPickerRow(
                  label: 'حالة الرد',
                  options: [
                    for (final item in _statusValues)
                      _ChipOption(value: item, label: _statusLabel(item)),
                  ],
                  selected: _status,
                  onSelected: (value) => setState(() => _status = value),
                ),
                const SizedBox(height: 12),
                _StepperRow(
                  label: 'الحضور المتوقع: $_seatsCount',
                  onMinus: _seatsCount > 1
                      ? () => setState(() {
                          _seatsCount--;
                          if (_companionsCount >= _seatsCount) {
                            _companionsCount = _seatsCount - 1;
                          }
                        })
                      : null,
                  onPlus: _seatsCount < 20
                      ? () => setState(() => _seatsCount++)
                      : null,
                ),
                const SizedBox(height: 8),
                _StepperRow(
                  label: 'عدد المرافقين: $_companionsCount',
                  onMinus: _companionsCount > 0
                      ? () => setState(() => _companionsCount--)
                      : null,
                  onPlus: _companionsCount < 20
                      ? () => setState(() {
                          _companionsCount++;
                          if (_seatsCount < _companionsCount + 1) {
                            _seatsCount = _companionsCount + 1;
                          }
                        })
                      : null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    prefixIcon: Icon(LucideIcons.stickyNote),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(LucideIcons.check, size: 18),
                  label: Text(guest == null ? 'إضافة ضيف' : 'حفظ التعديل'),
                ),
                if (_sheetError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _sheetError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipOption {
  const _ChipOption({required this.value, required this.label});

  final String value;
  final String label;
}

class _ChipPickerRow extends StatelessWidget {
  const _ChipPickerRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<_ChipOption> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelMedium?.copyWith(color: AppTheme.muted),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelected(option.value),
                  borderRadius: BorderRadius.circular(999),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: option.value == selected
                          ? AppTheme.burgundy
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: option.value == selected
                            ? AppTheme.burgundy
                            : AppTheme.border,
                      ),
                    ),
                    child: Text(
                      option.label,
                      style: textTheme.labelMedium?.copyWith(
                        color: option.value == selected
                            ? Colors.white
                            : AppTheme.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            onPressed: onMinus,
            icon: const Icon(LucideIcons.minusCircle),
            tooltip: 'تقليل العدد',
          ),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(LucideIcons.plusCircle),
            tooltip: 'زيادة العدد',
          ),
        ],
      ),
    );
  }
}

class _GuestSheetResult {
  const _GuestSheetResult({
    required this.name,
    required this.side,
    required this.status,
    required this.seatsCount,
    required this.companionsCount,
    this.phone,
    this.groupId,
    this.notes,
  });

  final String name;
  final String? phone;
  final String? groupId;
  final String side;
  final String status;
  final int seatsCount;
  final int companionsCount;
  final String? notes;
}

class _GuestLoadingState extends StatelessWidget {
  const _GuestLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 120),
      children: const [
        _SkeletonBox(height: 250),
        SizedBox(height: 14),
        _SkeletonBox(height: 180),
        SizedBox(height: 14),
        _SkeletonBox(height: 104),
        SizedBox(height: 12),
        _SkeletonBox(height: 104),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dangerSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dangerSoft),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle, color: AppTheme.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

enum _GuestFilter {
  all,
  confirmed,
  pending,
  declined,
  incomplete,
  groom,
  bride,
}

class _FilterItem {
  const _FilterItem(this.filter, this.label, this.icon);

  final _GuestFilter filter;
  final String label;
  final IconData icon;
}

const _filterItems = [
  _FilterItem(_GuestFilter.all, 'الكل', LucideIcons.layoutGrid),
  _FilterItem(_GuestFilter.confirmed, 'مؤكد', LucideIcons.checkCircle),
  _FilterItem(_GuestFilter.pending, 'بانتظار الرد', LucideIcons.hourglass),
  _FilterItem(_GuestFilter.declined, 'لن يحضر', LucideIcons.xCircle),
  _FilterItem(_GuestFilter.incomplete, 'ناقص بيانات', LucideIcons.info),
  _FilterItem(_GuestFilter.groom, 'طرف العريس', LucideIcons.user),
  _FilterItem(_GuestFilter.bride, 'طرف العروسة', LucideIcons.user),
];

const _sideValues = ['GROOM', 'BRIDE', 'OTHER'];
const _statusValues = ['INVITED', 'CONFIRMED', 'PENDING', 'DECLINED'];

List<Guest> _filteredGuests(List<Guest> guests, _GuestFilter filter) {
  return switch (filter) {
    _GuestFilter.all => guests,
    _GuestFilter.confirmed =>
      guests.where((guest) => guest.isConfirmed).toList(),
    _GuestFilter.pending => guests.where((guest) => guest.isPending).toList(),
    _GuestFilter.declined => guests.where((guest) => guest.isDeclined).toList(),
    _GuestFilter.incomplete =>
      guests.where((guest) => guest.hasMissingData).toList(),
    _GuestFilter.groom =>
      guests.where((guest) => guest.side == 'GROOM').toList(),
    _GuestFilter.bride =>
      guests.where((guest) => guest.side == 'BRIDE').toList(),
  };
}

List<_GuestIssue> _importantIssues(
  GuestSummary summary,
  Set<String> duplicates,
) {
  final issues = <_GuestIssue>[];
  if (summary.incompleteGuestsCount > 0) {
    issues.add(
      _GuestIssue(
        label: 'ضيوف يحتاجون إكمال بيانات',
        count: summary.incompleteGuestsCount,
        filter: _GuestFilter.incomplete,
        icon: LucideIcons.info,
        color: AppTheme.warning,
      ),
    );
  }
  if (summary.missingPhoneCount > 0) {
    issues.add(
      _GuestIssue(
        label: 'ضيوف بدون رقم جوال',
        count: summary.missingPhoneCount,
        filter: _GuestFilter.incomplete,
        icon: LucideIcons.phoneOff,
        color: AppTheme.gold,
      ),
    );
  }
  if (duplicates.isNotEmpty) {
    issues.add(
      _GuestIssue(
        label: 'تكرار محتمل في أرقام الضيوف',
        count: duplicates.length,
        filter: _GuestFilter.all,
        icon: LucideIcons.copy,
        color: AppTheme.danger,
      ),
    );
  }
  if (summary.pending > 0) {
    issues.add(
      _GuestIssue(
        label: 'ضيوف بانتظار الرد',
        count: summary.pending,
        filter: _GuestFilter.pending,
        icon: LucideIcons.hourglass,
        color: AppTheme.burgundy,
      ),
    );
  }
  if (summary.totalGuests > 0 && (summary.bySideForSuper['groom'] ?? 0) == 0) {
    issues.add(
      const _GuestIssue(
        label: 'لا يوجد ضيوف من طرف العريس',
        count: 0,
        filter: _GuestFilter.groom,
        icon: LucideIcons.user,
        color: AppTheme.ink,
      ),
    );
  }
  if (summary.totalGuests > 0 && (summary.bySideForSuper['bride'] ?? 0) == 0) {
    issues.add(
      const _GuestIssue(
        label: 'لا يوجد ضيوف من طرف العروسة',
        count: 0,
        filter: _GuestFilter.bride,
        icon: LucideIcons.user,
        color: AppTheme.ink,
      ),
    );
  }
  return issues.take(4).toList();
}

Set<String> _duplicateGuests(List<Guest> guests) {
  final firstByPhone = <String, String>{};
  final duplicates = <String>{};
  for (final guest in guests) {
    final key = PhoneNumberUtils.comparisonKey(guest.phone);
    if (key == null) continue;
    final first = firstByPhone[key];
    if (first == null) {
      firstByPhone[key] = guest.id;
    } else {
      duplicates.add(first);
      duplicates.add(guest.id);
    }
  }
  return duplicates;
}

String _groupLabel(Guest guest, List<GuestGroup> groups) {
  final groupId = guest.groupId;
  if (groupId == null || groupId.trim().isEmpty) return 'بدون مجموعة';
  for (final group in groups) {
    if (group.id == groupId) return group.name;
  }
  return 'ضمن مجموعة';
}

String _supportedSide(String? side) {
  return _sideValues.contains(side) ? side! : 'OTHER';
}

Widget _staggeredGuest(Widget card, int index, bool reduceMotion) {
  if (reduceMotion) return card;
  return card
      .animate()
      .fadeIn(delay: (45 * index).ms, duration: 340.ms)
      .slideY(
        begin: 0.08,
        end: 0,
        delay: (45 * index).ms,
        duration: 340.ms,
        curve: Curves.easeOutCubic,
      );
}

String _sideLabel(String side) => guestSideLabel(side);

String _statusLabel(String status) {
  return switch (status) {
    'CONFIRMED' => 'مؤكد',
    'DECLINED' => 'لن يحضر',
    'PENDING' => 'بانتظار الرد',
    _ => 'مدعو',
  };
}

String _attendanceFromStatus(String status) {
  return switch (status) {
    'CONFIRMED' => 'CONFIRMED',
    'DECLINED' => 'DECLINED',
    _ => 'PENDING',
  };
}

String _listTitle(_GuestFilter filter) {
  return switch (filter) {
    _GuestFilter.all => 'قائمة الضيوف',
    _GuestFilter.confirmed => 'الضيوف المؤكدون',
    _GuestFilter.pending => 'بانتظار الرد',
    _GuestFilter.declined => 'لن يحضر',
    _GuestFilter.incomplete => 'ناقص بيانات',
    _GuestFilter.groom => 'طرف العريس',
    _GuestFilter.bride => 'طرف العروسة',
  };
}

String _emptyGuestsMessage(_GuestFilter filter) {
  return switch (filter) {
    _GuestFilter.all =>
      'لا يوجد ضيوف بعد. أضف ضيفًا عندما تكون لديك بيانات حضور فعلية.',
    _GuestFilter.confirmed => 'لا يوجد ضيوف مؤكدون بعد.',
    _GuestFilter.pending => 'لا يوجد ضيوف بانتظار الرد الآن.',
    _GuestFilter.declined => 'لا يوجد ضيوف اعتذروا عن الحضور.',
    _GuestFilter.incomplete => 'لا يوجد ضيوف ناقصو البيانات الآن.',
    _GuestFilter.groom => 'لا يوجد ضيوف من طرف العريس بعد.',
    _GuestFilter.bride => 'لا يوجد ضيوف من طرف العروسة بعد.',
  };
}

class _GuestIssue {
  const _GuestIssue({
    required this.label,
    required this.count,
    required this.filter,
    required this.icon,
    required this.color,
  });

  final String label;
  final int count;
  final _GuestFilter filter;
  final IconData icon;
  final Color color;
}
