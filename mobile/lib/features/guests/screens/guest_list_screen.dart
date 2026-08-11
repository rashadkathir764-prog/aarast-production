import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/forms/aarast_form_success.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../../wedding_plans/utils/plan_pulse_sync.dart';
import '../../wedding_plans/models/wedding_plan_stage.dart';
import '../../wedding_plans/models/wedding_stage_domain_guidance.dart';
import '../../wedding_plans/providers/dashboard_summary_provider.dart';
import '../../wedding_plans/widgets/wedding_stage_context_line.dart';
import '../models/guest.dart';
import '../providers/guests_provider.dart';
import '../widgets/guest_form_sheet.dart';
import '../widgets/guest_attendance_brief.dart';
import '../widgets/guest_list_row.dart';

part 'guest_list_screen_helpers.dart';

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
    final dashboardSummary = context
        .watch<DashboardSummaryProvider?>()
        ?.summary;
    final stage = dashboardSummary?.planId == widget.weddingPlanId
        ? resolveWeddingPlanStage(dashboardSummary?.weddingDate)
        : null;

    return AarastScreenFrame(
      maxWidth: 520,
      floatingActionButton: widget.showLocalFab
          ? FloatingActionButton(
              backgroundColor: AppTheme.brand,
              foregroundColor: AppTheme.onBrand,
              onPressed: planIdReady && !provider.isSubmitting
                  ? () => _showGuestSheet(provider: provider)
                  : null,
              child: const Icon(LucideIcons.plus),
            )
          : null,
      child: RefreshIndicator(
        color: AppTheme.brand,
        onRefresh: _isLocalExploration ? () async {} : _load,
        child: _GuestsContent(
          provider: provider,
          weddingPlanId: widget.weddingPlanId,
          planIdReady: planIdReady,
          isLocalPlan: _isLocalExploration,
          stage: stage,
          filter: _filter,
          onFilterChanged: (filter) => setState(() => _filter = filter),
          onEditGuest: (guest) =>
              _showGuestSheet(provider: provider, guest: guest),
          onStatus: _updateStatus,
          onDelete: _confirmDelete,
        ),
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
    final result = await showAarastBottomSheet<GuestFormResult>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => GuestFormSheet(
        guest: guest,
        draftScope: _guestDraftScope(guest),
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
      _publishPulse(provider);
      await context.read<AarastFormDraftStore?>()?.clear(
        _guestDraftScope(guest),
      );
      if (!mounted) return;
      final message = provider.noticeMessage ?? 'تم حفظ الضيف.';
      AarastFormSuccess.show(
        context,
        message: message,
        nextLabel: guest == null ? 'إضافة آخر' : null,
        onNext: guest == null
            ? () => _showGuestSheet(provider: provider)
            : null,
      );
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'تعذر حفظ الضيف.',
      );
    }
  }

  String _guestDraftScope(Guest? guest) {
    return 'guest:${widget.weddingPlanId}:${guest?.id ?? 'new'}';
  }

  Future<void> _updateStatus(Guest guest, String status) async {
    final provider = context.read<GuestsProvider>();
    final previousStatus = guest.status;
    final previousAttendance = guest.attendanceStatus;
    final ok = await provider.updateGuest(
      guest: guest,
      status: status,
      attendanceStatus: _attendanceFromStatus(status),
    );
    if (!mounted) return;
    if (!ok) {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'تعذر تحديث رد الضيف.',
      );
      return;
    }
    _publishPulse(provider);
    AarastToast.showSuccess(
      context,
      'تم تحديث رد الضيف',
      action: SnackBarAction(
        label: 'تراجع',
        textColor: Colors.white,
        onPressed: () {
          unawaited(
            _undoGuestStatus(
              provider,
              guest,
              previousStatus,
              previousAttendance,
            ),
          );
        },
      ),
    );
  }

  Future<void> _undoGuestStatus(
    GuestsProvider provider,
    Guest guest,
    String previousStatus,
    String previousAttendance,
  ) async {
    final restored = await provider.updateGuest(
      guest: guest,
      status: previousStatus,
      attendanceStatus: previousAttendance,
    );
    if (restored && mounted) _publishPulse(provider);
  }

  Future<void> _confirmDelete(Guest guest) async {
    final provider = context.read<GuestsProvider>();
    final confirmed = await showAarastBottomSheet<bool>(
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
                  const GuestSheetHandle(),
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
                          color: AppTheme.textPrimary,
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
                          color: AppTheme.textSecondary,
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
        _publishPulse(provider);
        AarastToast.showSuccess(context, 'تم حذف الضيف.');
      } else if (mounted) {
        AarastToast.showError(
          context,
          provider.errorMessage ?? 'تعذر حذف الضيف.',
        );
      }
    }
  }

  void _publishPulse(GuestsProvider provider) {
    publishGuestPlanPulse(
      context,
      weddingPlanId: widget.weddingPlanId,
      summary: provider.summary,
    );
  }
}

class _GuestsContent extends StatelessWidget {
  const _GuestsContent({
    required this.provider,
    required this.weddingPlanId,
    required this.planIdReady,
    required this.isLocalPlan,
    required this.stage,
    required this.filter,
    required this.onFilterChanged,
    required this.onEditGuest,
    required this.onStatus,
    required this.onDelete,
  });

  final GuestsProvider provider;
  final String weddingPlanId;
  final bool planIdReady;
  final bool isLocalPlan;
  final WeddingPlanStageState? stage;
  final _GuestFilter filter;
  final ValueChanged<_GuestFilter> onFilterChanged;
  final ValueChanged<Guest> onEditGuest;
  final Future<void> Function(Guest guest, String status) onStatus;
  final ValueChanged<Guest> onDelete;

  @override
  Widget build(BuildContext context) {
    if (!planIdReady) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 70, 20, 120),
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
        padding: const EdgeInsets.fromLTRB(20, 70, 20, 120),
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
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        AarastV3Density.pageBottomWithQuickAction,
      ),
      children: [
        if (provider.errorMessage != null) ...[
          _InlineError(message: provider.errorMessage!),
          const SizedBox(height: 14),
        ],
        GuestAttendanceBrief(
          summary: summary,
          isLocalPlan: isLocalPlan,
          heroTag: 'plan-$weddingPlanId-guests',
        ),
        if (stage != null) ...[
          const SizedBox(height: 12),
          WeddingStageContextLine(
            stage: stage!,
            domain: WeddingStageDomain.guests,
          ),
        ],
        const SizedBox(height: 12),
        if (guests.isNotEmpty) ...[
          _ImportantGuestsCard(
            issues: importantIssues,
            onOpenFilter: onFilterChanged,
          ),
          const SizedBox(height: 17),
        ] else
          const SizedBox(height: AppTheme.space20),
        _GuestListSectionHeader(
          title: _listTitle(filter),
          selected: filter,
          onChanged: onFilterChanged,
        ),
        const SizedBox(height: 8),
        if (visibleGuests.isEmpty)
          AarastEmptyState(
            icon: filter == _GuestFilter.all
                ? LucideIcons.users
                : LucideIcons.search,
            title: _emptyGuestsTitle(filter),
            message: _emptyGuestsMessage(filter),
            action: filter == _GuestFilter.all
                ? null
                : AarastButton(
                    label: 'عرض كل الضيوف',
                    icon: LucideIcons.users,
                    expand: false,
                    onPressed: () => onFilterChanged(_GuestFilter.all),
                  ),
          )
        else
          AarastV3ContinuousSurface(
            children: [
              for (final guest in visibleGuests)
                AarastV3SwipeActions(
                  itemKey: ValueKey('guest-swipe-${guest.id}'),
                  primaryLabel: guest.isPending
                      ? 'تأكيد الحضور'
                      : 'إعادة للانتظار',
                  primaryIcon: guest.isPending
                      ? LucideIcons.userCheck
                      : LucideIcons.clock3,
                  primaryColor: guest.isPending
                      ? AppTheme.success
                      : AppTheme.warning,
                  onPrimary: () => onStatus(
                    guest,
                    guest.isPending ? 'CONFIRMED' : 'INVITED',
                  ),
                  secondaryLabel: 'تعديل البيانات',
                  secondaryIcon: LucideIcons.userCog,
                  onSecondary: () async => onEditGuest(guest),
                  child: GuestListRow(
                    guest: guest,
                    groupLabel: _groupLabel(guest, provider.groups),
                    isDuplicate: duplicates.contains(guest.id),
                    isBusy: provider.isSubmitting,
                    onEdit: () => onEditGuest(guest),
                    onStatus: (status) => onStatus(guest, status),
                    onDelete: () => onDelete(guest),
                  ),
                ),
            ],
          ),
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
    if (issues.isEmpty) {
      return const AarastV3TrustLine(
        icon: LucideIcons.badgeCheck,
        message: 'بيانات الضيوف مرتبة ولا تحتاج انتباهك الآن.',
        tone: AarastV3AttentionTone.success,
      );
    }

    final issue = issues.first;
    void openIssue() => onOpenFilter(issue.filter);
    return AarastV3AttentionSurface(
      eyebrow: 'يحتاج انتباهك',
      title: issue.label,
      reason: issue.detail,
      icon: issue.icon,
      actionLabel: 'مراجعة',
      onAction: openIssue,
      onTap: openIssue,
      tone: issue.tone,
    );
  }
}

class _GuestListSectionHeader extends StatelessWidget {
  const _GuestListSectionHeader({
    required this.title,
    required this.selected,
    required this.onChanged,
  });

  final String title;
  final _GuestFilter selected;
  final ValueChanged<_GuestFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        _GuestFilterBar(selected: selected, onChanged: onChanged),
      ],
    );
  }
}

class _GuestFilterBar extends StatelessWidget {
  const _GuestFilterBar({required this.selected, required this.onChanged});

  final _GuestFilter selected;
  final ValueChanged<_GuestFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in _filterItems) ...[
            InkWell(
              key: ValueKey('guest-filter-${item.filter.name}'),
              onTap: () => onChanged(item.filter),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: item.filter == selected
                          ? AppTheme.brandMuted
                          : AppTheme.surfaceRaised,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      border: Border.all(
                        color: item.filter == selected
                            ? AppTheme.brand.withValues(alpha: .2)
                            : AppTheme.border,
                      ),
                    ),
                    child: Text(
                      item.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: item.filter == selected
                            ? AppTheme.brand
                            : AppTheme.textSecondary,
                        fontWeight: item.filter == selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (item != _filterItems.last) const SizedBox(width: 7),
          ],
        ],
      ),
    );
  }
}

class _GuestLoadingState extends StatelessWidget {
  const _GuestLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 120),
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
        color: AppTheme.surfaceRaised,
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
