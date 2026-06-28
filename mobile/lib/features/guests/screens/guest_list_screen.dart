import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_duplicate_utils.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../shared/widgets/contact_phone_field.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../models/guest.dart';
import '../providers/guests_provider.dart';

class GuestListScreen extends StatefulWidget {
  const GuestListScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

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
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuestsProvider>();
    final planIdReady = widget.weddingPlanId.trim().isNotEmpty;

    return AarastScreenFrame(
      maxWidth: 520,
      floatingActionButton: FloatingActionButton(
        onPressed: planIdReady && !provider.isSubmitting
            ? () => _showGuestSheet(provider: provider)
            : null,
        child: const Icon(Icons.add_rounded),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  tooltip: 'رجوع',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الضيوف',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.dMaroonDeep,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'نظم قائمة الحضور والدعوات',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.dInkSoft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: planIdReady && !provider.isSubmitting
                      ? () => _showGuestSheet(provider: provider)
                      : null,
                  icon: const Icon(Icons.group_add_rounded),
                  tooltip: 'إضافة ضيف',
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.dMaroon,
                    foregroundColor: Colors.white,
                    side: BorderSide.none,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.dMaroon,
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

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/');
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(provider.errorMessage ?? 'تعذر حفظ الضيف.')),
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
                      color: AppTheme.danger.withAlpha(22),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.danger,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'حذف الضيف؟',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(
                          color: AppTheme.dInk,
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
                          color: AppTheme.dInkSoft,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.danger,
                          ),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('حذف'),
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
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('تم حذف الضيف.')));
      }
    }
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
            icon: Icons.event_busy_outlined,
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
            icon: Icons.error_outline_rounded,
            title: 'تعذر تحميل الضيوف',
            message: provider.errorMessage!,
            action: OutlinedButton.icon(
              onPressed: () => provider.loadGuests(weddingPlanId),
              icon: const Icon(Icons.refresh_rounded),
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
        _GuestsHero(summary: summary, isLocalPlan: isLocalPlan),
        const SizedBox(height: 12),
        _GuestStatusSummaryCard(summary: summary),
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
          icon: Icons.groups_2_rounded,
          actionLabel: 'إضافة',
          onAction: provider.isSubmitting ? null : onAddGuest,
        ),
        const SizedBox(height: 12),
        if (visibleGuests.isEmpty)
          AarastEmptyState(
            title: _emptyTitle(filter),
            message: _emptyMessage(filter),
            icon: Icons.people_outline_rounded,
            action: filter == _GuestFilter.all
                ? FilledButton.icon(
                    onPressed: onAddGuest,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('إضافة ضيف'),
                  )
                : null,
          )
        else
          for (final guest in visibleGuests) ...[
            _PremiumGuestCard(
              guest: guest,
              groupLabel: _groupLabel(guest, provider.groups),
              isDuplicate: duplicates.contains(guest.id),
              isBusy: provider.isSubmitting,
              onEdit: () => onEditGuest(guest),
              onStatus: (status) => onStatus(guest, status),
              onDelete: () => onDelete(guest),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _GuestsHero extends StatelessWidget {
  const _GuestsHero({required this.summary, required this.isLocalPlan});

  final GuestSummary summary;
  final bool isLocalPlan;

  @override
  Widget build(BuildContext context) {
    final completionLabel = summary.totalGuests == 0
        ? 'لم تضف أي ضيف بعد'
        : '${summary.completionPercent}% اكتمال بيانات الضيوف';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.heroDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(28),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: Colors.white.withAlpha(36)),
                ),
                child: const Icon(
                  Icons.groups_2_rounded,
                  color: AppTheme.dGold,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الضيوف',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'نظم قائمة الحضور والدعوات',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withAlpha(205),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _ProgressSeal(value: summary.completionRatio),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: summary.completionRatio,
              backgroundColor: Colors.white.withAlpha(35),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.dGold),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 245),
                child: Text(
                  completionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withAlpha(220),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              AarastStatusPill(
                label: isLocalPlan ? 'تخطيط محلي' : 'حساب محفوظ',
                color: AppTheme.dGold,
                backgroundColor: Colors.white.withAlpha(24),
                icon: isLocalPlan
                    ? Icons.phone_iphone_rounded
                    : Icons.verified_user_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroMetric(label: 'الدعوات', value: '${summary.totalGuests}'),
              _HeroMetric(
                label: 'الحضور المتوقع',
                value: '${summary.expectedSeatsCount}',
              ),
              _HeroMetric(label: 'مؤكد', value: '${summary.confirmed}'),
              _HeroMetric(label: 'بانتظار الرد', value: '${summary.pending}'),
              _HeroMetric(
                label: 'ناقص بيانات',
                value: '${summary.incompleteGuestsCount}',
              ),
              _HeroMetric(
                label: 'طرف العريس/العروسة',
                value:
                    '${summary.bySideForSuper['groom'] ?? 0}/${summary.bySideForSuper['bride'] ?? 0}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(22),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white.withAlpha(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withAlpha(198),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestStatusSummaryCard extends StatelessWidget {
  const _GuestStatusSummaryCard({required this.summary});

  final GuestSummary summary;

  @override
  Widget build(BuildContext context) {
    final groupEntries = summary.byGroup.entries
        .where((entry) => entry.value > 0)
        .take(3)
        .toList();

    return AarastCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.insights_rounded,
                color: AppTheme.dMaroon,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ملخص حالة الضيوف',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${summary.totalGuests} ضيف',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.dMaroon,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryTile(
                label: 'مؤكد',
                value: '${summary.confirmed}',
                color: AppTheme.dGreen,
                icon: Icons.check_circle_outline_rounded,
              ),
              _SummaryTile(
                label: 'بانتظار الرد',
                value: '${summary.pending}',
                color: AppTheme.dGoldDeep,
                icon: Icons.hourglass_bottom_rounded,
              ),
              _SummaryTile(
                label: 'لن يحضر',
                value: '${summary.declined}',
                color: AppTheme.danger,
                icon: Icons.cancel_outlined,
              ),
              _SummaryTile(
                label: 'ناقص هاتف',
                value: '${summary.missingPhoneCount}',
                color: AppTheme.dOrange,
                icon: Icons.phone_disabled_outlined,
              ),
              _SummaryTile(
                label: 'طرف العريس',
                value: '${summary.bySideForSuper['groom'] ?? 0}',
                color: AppTheme.dMaroon,
                icon: Icons.person_outline_rounded,
              ),
              _SummaryTile(
                label: 'طرف العروسة',
                value: '${summary.bySideForSuper['bride'] ?? 0}',
                color: AppTheme.dBlue,
                icon: Icons.person_2_outlined,
              ),
            ],
          ),
          if (summary.companionsExpectedCount > 0 || groupEntries.isNotEmpty)
            const SizedBox(height: 12),
          if (summary.companionsExpectedCount > 0)
            Text(
              'المرافقون المتوقعون: ${summary.companionsExpectedCount}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.dInkSoft,
                fontWeight: FontWeight.w800,
              ),
            ),
          if (groupEntries.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in groupEntries)
                  AarastStatusPill(
                    label: '${_groupSummaryLabel(entry.key)}: ${entry.value}',
                    color: AppTheme.dMaroon,
                    backgroundColor: AppTheme.dPinkBg.withAlpha(130),
                    icon: Icons.folder_open_rounded,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withAlpha(32)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.dInkSoft,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    return AarastCard(
      padding: const EdgeInsets.all(14),
      color: issues.isEmpty ? AppTheme.dCard2 : AppTheme.dCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                issues.isEmpty
                    ? Icons.verified_outlined
                    : Icons.priority_high_rounded,
                color: issues.isEmpty ? AppTheme.dGreen : AppTheme.dMaroon,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'أهم ما يحتاج متابعة في الضيوف',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (issues.isEmpty)
            Text(
              'كل بيانات الضيوف مكتملة',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.dInkSoft,
                fontWeight: FontWeight.w800,
              ),
            )
          else
            for (final issue in issues) ...[
              _IssueRow(issue: issue, onTap: () => onOpenFilter(issue.filter)),
              if (issue != issues.last) const SizedBox(height: 8),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: issue.color.withAlpha(11),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: issue.color.withAlpha(35)),
        ),
        child: Row(
          children: [
            Icon(issue.icon, color: issue.color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                issue.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.dInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${issue.count}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: issue.color,
                fontWeight: FontWeight.w900,
              ),
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
                color: isSelected ? AppTheme.dMaroon : AppTheme.dCard2,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? AppTheme.dMaroon : AppTheme.dLine,
                ),
                boxShadow: isSelected ? AppTheme.cardShadow() : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    size: 16,
                    color: isSelected ? Colors.white : AppTheme.dMaroon,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: isSelected ? Colors.white : AppTheme.dInk,
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

class _PremiumGuestCard extends StatelessWidget {
  const _PremiumGuestCard({
    required this.guest,
    required this.groupLabel,
    required this.isDuplicate,
    required this.isBusy,
    required this.onEdit,
    required this.onStatus,
    required this.onDelete,
  });

  final Guest guest;
  final String groupLabel;
  final bool isDuplicate;
  final bool isBusy;
  final VoidCallback onEdit;
  final ValueChanged<String> onStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(guest.status, guest.attendanceStatus);
    final phone = PhoneNumberUtils.display(guest.phone) ?? guest.phone?.trim();
    final missing = guest.hasMissingData;

    return AarastCard(
      padding: const EdgeInsets.all(14),
      border: Border.all(
        color: missing ? AppTheme.dOrange.withAlpha(80) : AppTheme.dLine,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: color.withAlpha(42)),
                ),
                child: Icon(Icons.person_outline_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guest.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.dInk,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _MiniMeta(
                          icon: Icons.people_outline_rounded,
                          label: _sideLabel(guest.side),
                        ),
                        _MiniMeta(
                          icon: Icons.folder_open_rounded,
                          label: groupLabel,
                        ),
                        _MiniMeta(
                          icon: Icons.event_seat_outlined,
                          label: '${guest.seatsCount} حضور',
                        ),
                        if (guest.companionsCount > 0)
                          _MiniMeta(
                            icon: Icons.group_add_outlined,
                            label: '${guest.companionsCount} مرافق',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                enabled: !isBusy,
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                  if (_statusValues.contains(value)) onStatus(value);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  for (final status in _statusValues)
                    PopupMenuItem(
                      value: status,
                      child: Text(_statusLabel(status)),
                    ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'delete', child: Text('حذف')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AarastStatusPill(
                label: _statusLabel(guest.status),
                color: color,
                backgroundColor: color.withAlpha(20),
                icon: _statusIcon(guest.status, guest.attendanceStatus),
              ),
              if (phone != null && phone.isNotEmpty)
                AarastStatusPill(
                  label: phone,
                  color: AppTheme.dInkSoft,
                  backgroundColor: AppTheme.dCreamBg.withAlpha(160),
                  icon: Icons.phone_iphone_rounded,
                ),
              if (missing)
                const AarastStatusPill(
                  label: 'ناقص بيانات',
                  color: AppTheme.dOrange,
                  icon: Icons.info_outline_rounded,
                ),
              if (isDuplicate)
                const AarastStatusPill(
                  label: 'تكرار محتمل',
                  color: AppTheme.danger,
                  icon: Icons.content_copy_rounded,
                ),
            ],
          ),
          if (guest.notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              guest.notes!.trim(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.dInkSoft,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniMeta extends StatelessWidget {
  const _MiniMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppTheme.dInkSoft),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
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
                    prefixIcon: Icon(Icons.person_outline_rounded),
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
                      color: AppTheme.dGoldDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _side,
                  items: _sideValues
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(_sideLabel(item)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _side = value);
                  },
                  decoration: const InputDecoration(
                    labelText: 'الطرف',
                    prefixIcon: Icon(Icons.people_outline_rounded),
                  ),
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
                      prefixIcon: Icon(Icons.folder_open_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  items: _statusValues
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(_statusLabel(item)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _status = value);
                  },
                  decoration: const InputDecoration(
                    labelText: 'حالة الرد',
                    prefixIcon: Icon(Icons.mark_email_read_outlined),
                  ),
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
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded),
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
        color: AppTheme.dCard2,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.dInk,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            onPressed: onMinus,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(Icons.add_circle_outline),
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

class _ProgressSeal extends StatelessWidget {
  const _ProgressSeal({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withAlpha(22),
        border: Border.all(color: AppTheme.dGold.withAlpha(150), width: 1.4),
      ),
      child: Center(
        child: Text(
          '$percent%',
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
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
        color: AppTheme.dCard2,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.dLine),
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
        color: AppTheme.danger.withAlpha(18),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.danger.withAlpha(45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.danger),
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
          color: AppTheme.dLine,
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
  _FilterItem(_GuestFilter.all, 'الكل', Icons.grid_view_rounded),
  _FilterItem(_GuestFilter.confirmed, 'مؤكد', Icons.check_circle_rounded),
  _FilterItem(
    _GuestFilter.pending,
    'بانتظار الرد',
    Icons.hourglass_bottom_rounded,
  ),
  _FilterItem(_GuestFilter.declined, 'لن يحضر', Icons.cancel_rounded),
  _FilterItem(
    _GuestFilter.incomplete,
    'ناقص بيانات',
    Icons.info_outline_rounded,
  ),
  _FilterItem(_GuestFilter.groom, 'طرف العريس', Icons.person_outline_rounded),
  _FilterItem(_GuestFilter.bride, 'طرف العروسة', Icons.person_2_outlined),
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
        icon: Icons.info_outline_rounded,
        color: AppTheme.dOrange,
      ),
    );
  }
  if (summary.missingPhoneCount > 0) {
    issues.add(
      _GuestIssue(
        label: 'ضيوف بدون رقم جوال',
        count: summary.missingPhoneCount,
        filter: _GuestFilter.incomplete,
        icon: Icons.phone_disabled_outlined,
        color: AppTheme.dGoldDeep,
      ),
    );
  }
  if (duplicates.isNotEmpty) {
    issues.add(
      _GuestIssue(
        label: 'تكرار محتمل في أرقام الضيوف',
        count: duplicates.length,
        filter: _GuestFilter.all,
        icon: Icons.content_copy_rounded,
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
        icon: Icons.hourglass_bottom_rounded,
        color: AppTheme.dMaroon,
      ),
    );
  }
  if (summary.totalGuests > 0 && (summary.bySideForSuper['groom'] ?? 0) == 0) {
    issues.add(
      const _GuestIssue(
        label: 'لا يوجد ضيوف من طرف العريس',
        count: 0,
        filter: _GuestFilter.groom,
        icon: Icons.person_outline_rounded,
        color: AppTheme.dBlue,
      ),
    );
  }
  if (summary.totalGuests > 0 && (summary.bySideForSuper['bride'] ?? 0) == 0) {
    issues.add(
      const _GuestIssue(
        label: 'لا يوجد ضيوف من طرف العروسة',
        count: 0,
        filter: _GuestFilter.bride,
        icon: Icons.person_2_outlined,
        color: AppTheme.dBlue,
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

String _groupSummaryLabel(String key) {
  return switch (key) {
    'ungrouped' => 'بدون مجموعة',
    'grouped' => 'ضمن مجموعة',
    _ => key,
  };
}

String _supportedSide(String? side) {
  return _sideValues.contains(side) ? side! : 'OTHER';
}

String _sideLabel(String side) {
  return switch (side) {
    'GROOM' => 'طرف العريس',
    'BRIDE' => 'طرف العروسة',
    'FAMILY' => 'غير محدد',
    'FRIEND' => 'غير محدد',
    _ => 'غير محدد',
  };
}

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

Color _statusColor(String status, String attendanceStatus) {
  if (attendanceStatus == 'CONFIRMED' || status == 'CONFIRMED') {
    return AppTheme.dGreen;
  }
  if (attendanceStatus == 'DECLINED' || status == 'DECLINED') {
    return AppTheme.danger;
  }
  if (status == 'PENDING') return AppTheme.dGoldDeep;
  return AppTheme.dMaroon;
}

IconData _statusIcon(String status, String attendanceStatus) {
  if (attendanceStatus == 'CONFIRMED' || status == 'CONFIRMED') {
    return Icons.check_circle_outline_rounded;
  }
  if (attendanceStatus == 'DECLINED' || status == 'DECLINED') {
    return Icons.cancel_outlined;
  }
  if (status == 'PENDING') return Icons.hourglass_bottom_rounded;
  return Icons.mark_email_unread_outlined;
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

String _emptyTitle(_GuestFilter filter) {
  return switch (filter) {
    _GuestFilter.all => 'لم تضف أي ضيف بعد',
    _GuestFilter.confirmed => 'لا يوجد ضيوف مؤكدون بعد',
    _GuestFilter.pending => 'لا يوجد ضيوف بانتظار الرد',
    _GuestFilter.declined => 'لا يوجد ضيوف اعتذروا',
    _GuestFilter.incomplete => 'كل بيانات الضيوف مكتملة',
    _GuestFilter.groom => 'لا يوجد ضيوف من طرف العريس',
    _GuestFilter.bride => 'لا يوجد ضيوف من طرف العروسة',
  };
}

String _emptyMessage(_GuestFilter filter) {
  return switch (filter) {
    _GuestFilter.all => 'ابدأ بإضافة أول ضيف لتظهر أعداد الحضور بصدق.',
    _GuestFilter.confirmed => 'عند تأكيد ضيف سيظهر هنا.',
    _GuestFilter.pending => 'لا توجد أسماء تحتاج انتظار رد حاليًا.',
    _GuestFilter.declined => 'أي ضيف لن يحضر سيظهر في هذه القائمة.',
    _GuestFilter.incomplete => 'لا توجد أرقام أو بيانات ناقصة حاليًا.',
    _GuestFilter.groom => 'لا نعرض طرفًا غير موجود في البيانات.',
    _GuestFilter.bride => 'لا نعرض طرفًا غير موجود في البيانات.',
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
