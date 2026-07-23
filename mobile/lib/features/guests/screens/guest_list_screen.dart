import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:provider/provider.dart';

import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../models/guest.dart';
import '../providers/guests_provider.dart';
import '../widgets/guest_form_sheet.dart';
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
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
    final result = await showAarastBottomSheet<GuestFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => GuestFormSheet(
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final status = _invitationCountLabel(guestCount);
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AarastFeatureHeader(
                title: 'الضيوف',
                subtitle: 'حضور مرتب من أول دعوة',
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AarastStatusPill(
                  label: status,
                  color: AppTheme.burgundy,
                  backgroundColor: AppTheme.burgundySoft,
                  icon: LucideIcons.mail,
                ),
              ),
            ],
          );
        }
        return AarastFeatureHeader(
          title: 'الضيوف',
          subtitle: 'حضور مرتب من أول دعوة',
          statusLabel: status,
          statusColor: AppTheme.burgundy,
          statusIcon: LucideIcons.mail,
        );
      },
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
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 132),
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
        const SizedBox(height: 17),
        _GuestListSectionHeader(
          title: _listTitle(filter),
          selected: filter,
          onChanged: onFilterChanged,
        ),
        const SizedBox(height: 8),
        if (visibleGuests.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: AppTheme.border),
              ),
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
          Column(
            children: [
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
                if (i != visibleGuests.length - 1) const SizedBox(height: 10),
              ],
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
      return AarastCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        color: AppTheme.successSoft,
        border: Border.all(color: AppTheme.success.withValues(alpha: .16)),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: AppTheme.successBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.badgeCheck,
                color: AppTheme.success,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'كل بيانات الضيوف مكتملة',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppTheme.ink),
              ),
            ),
          ],
        ),
      );
    }

    final issue = issues.first;
    return AarastCard(
      onTap: () => onOpenFilter(issue.filter),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: Border.all(color: issue.color.withValues(alpha: .2)),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: issue.color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(issue.icon, color: issue.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  issue.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.goldSoft,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Text(
              'متابعة',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.warning,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
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
            color: AppTheme.ink,
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
                          ? AppTheme.burgundySoft
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      border: Border.all(
                        color: item.filter == selected
                            ? AppTheme.burgundy.withValues(alpha: .2)
                            : AppTheme.border,
                      ),
                    ),
                    child: Text(
                      item.label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: item.filter == selected
                            ? AppTheme.burgundy
                            : AppTheme.muted,
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

enum _GuestFilter {
  all,
  confirmed,
  pending,
  declined,
  incomplete,
  groom,
  bride,
}

String _invitationCountLabel(int count) {
  return switch (count) {
    0 => 'لا توجد دعوات',
    1 => 'دعوة واحدة',
    2 => 'دعوتان',
    >= 3 && <= 10 => '$count دعوات',
    _ => '$count دعوة',
  };
}

class _FilterItem {
  const _FilterItem(this.filter, this.label);

  final _GuestFilter filter;
  final String label;
}

const _filterItems = [
  _FilterItem(_GuestFilter.all, 'الكل'),
  _FilterItem(_GuestFilter.confirmed, 'مؤكد'),
  _FilterItem(_GuestFilter.pending, 'بانتظار الرد'),
  _FilterItem(_GuestFilter.declined, 'لن يحضر'),
  _FilterItem(_GuestFilter.incomplete, 'ناقص بيانات'),
  _FilterItem(_GuestFilter.groom, 'طرف العريس'),
  _FilterItem(_GuestFilter.bride, 'طرف العروسة'),
];

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
  if (summary.incompleteGuestsCount > 0) {
    return [
      _GuestIssue(
        label: _incompleteGuestsLabel(summary.incompleteGuestsCount),
        detail: _incompleteGuestsDetail(summary),
        filter: _GuestFilter.incomplete,
        icon: LucideIcons.alertTriangle,
        color: AppTheme.warning,
      ),
    ];
  }
  if (duplicates.isNotEmpty) {
    return [
      _GuestIssue(
        label: duplicates.length == 1
            ? 'تكرار محتمل يحتاج مراجعة'
            : '${duplicates.length} تكرارات محتملة تحتاج مراجعة',
        detail: 'راجع أرقام الجوال قبل متابعة الدعوات',
        filter: _GuestFilter.all,
        icon: LucideIcons.copy,
        color: AppTheme.danger,
      ),
    ];
  }
  if (summary.pending > 0) {
    return [
      _GuestIssue(
        label: _pendingGuestsLabel(summary.pending),
        detail: 'راجع الدعوات التي لم يصل ردها بعد',
        filter: _GuestFilter.pending,
        icon: LucideIcons.hourglass,
        color: AppTheme.gold,
      ),
    ];
  }
  return const [];
}

String _incompleteGuestsLabel(int count) {
  return switch (count) {
    1 => 'ضيف واحد يحتاج إكمال بياناته',
    2 => 'ضيفان يحتاجان إكمال بياناتهما',
    >= 3 && <= 10 => '$count ضيوف يحتاجون إكمال بياناتهم',
    _ => '$count ضيفًا يحتاجون إكمال بياناتهم',
  };
}

String _incompleteGuestsDetail(GuestSummary summary) {
  if (summary.missingPhoneCount == 1 && summary.incompleteGuestsCount == 1) {
    return 'رقم الجوال غير مضاف بعد';
  }
  if (summary.missingPhoneCount > 0) {
    return '${summary.missingPhoneCount} بدون رقم جوال';
  }
  return 'راجع الاسم وبيانات التواصل';
}

String _pendingGuestsLabel(int count) {
  return switch (count) {
    1 => 'ضيف واحد بانتظار الرد',
    2 => 'ضيفان بانتظار الرد',
    >= 3 && <= 10 => '$count ضيوف بانتظار الرد',
    _ => '$count ضيفًا بانتظار الرد',
  };
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
    required this.detail,
    required this.filter,
    required this.icon,
    required this.color,
  });

  final String label;
  final String detail;
  final _GuestFilter filter;
  final IconData icon;
  final Color color;
}
