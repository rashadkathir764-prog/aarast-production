import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_picker_service.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/forms/aarast_form_success.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/sync_status.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthActionGuard;
import '../../wedding_plans/wedding_plans_api.dart' show publishGuestPlanPulse;
import '../models/guest.dart';
import '../providers/guests_provider.dart';
import '../utils/guest_display.dart';
import '../widgets/guest_form_sheet.dart';
import '../widgets/guest_groups_sheet.dart';
import '../widgets/guest_row.dart';
import '../widgets/guest_search_field.dart';

part 'guest_list_screen_helpers.dart';

/// e01 «الضيوف»: how many confirmed out of how many invited and who has not
/// answered, the guests by family with each group's progress, and every
/// guest one tap away. Offline (w29) it shows the saved list.
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
  /// null: the overview; otherwise the group being looked at.
  String? _openGroup;
  _ReplyFilter _reply = _ReplyFilter.all;
  bool _searching = false;
  String _query = '';

  bool get _isLocalPlan =>
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
        if (mounted) _load();
      });
    }
    if ((!oldWidget.openAddOnStart && widget.openAddOnStart) ||
        oldWidget.openAddRequest != widget.openAddRequest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openAddSheetIfRequested());
      });
    }
  }

  Future<void> _load() =>
      context.read<GuestsProvider>().loadGuests(widget.weddingPlanId);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuestsProvider>();
    final sync = context.watch<OfflineSyncService?>();
    // w29: an account plan without a connection shows its last copy and
    // waits to add. A plan kept on the phone needs no connection at all.
    final offline = !_isLocalPlan && sync?.state == SyncState.offline;
    final guests = provider.guests
        .where((guest) => guest.weddingPlanId == widget.weddingPlanId)
        .toList();
    final summary = GuestSummary.fromGuests(
      weddingPlanId: widget.weddingPlanId,
      guests: guests,
      groups: provider.groups,
    );
    final duplicates = _duplicateGuests(guests);
    final query = _query;

    final Widget body;
    if (provider.isLoading && guests.isEmpty) {
      body = const JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.guests,
      );
    } else if (provider.errorMessage != null && guests.isEmpty) {
      body = JourneyListState(
        phase: JourneyListPhase.error,
        section: JourneySection.guests,
        onRetry: _load,
      );
    } else if (guests.isEmpty && offline) {
      // The note above says why there is nothing to add with yet.
      body = const JourneyListState(
        key: ValueKey('guests-empty-offline'),
        phase: JourneyListPhase.empty,
        section: JourneySection.guests,
        emptyTitle: 'ما أضفت أحد بعد',
      );
    } else if (guests.isEmpty) {
      body = _FirstGuests(
        onContacts: ContactPickerService.isAvailable
            ? () => _openImport(contacts: true)
            : null,
        onPaste: () => _openImport(contacts: false),
        onOne: () => _showGuestSheet(provider: provider),
      );
    } else if (query.isNotEmpty) {
      body = _guestBox(
        provider,
        _search(guests, query),
        duplicates,
        empty: 'ما لقينا أحد بهذا الاسم أو الرقم',
      );
    } else if (_openGroup != null) {
      body = _groupView(provider, guests, duplicates);
    } else {
      body = _overview(provider, guests, summary);
    }

    return AarastScreenFrame(
      maxWidth: 600,
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: AarastV3Color.lilac,
        onRefresh: _isLocalPlan ? () async {} : _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            12,
            16,
            AarastV3Density.pageBottomWithQuickAction,
          ),
          children: [
            JourneyTabHeader(
              title: 'الضيوف',
              status: _statusLine(summary),
              actions: [
                if (guests.isNotEmpty)
                  JourneyRoundButton(
                    key: const ValueKey('guests-search'),
                    icon: _searching ? LucideIcons.x : LucideIcons.search,
                    tooltip: _searching ? 'سكّر البحث' : 'دوّر على ضيف',
                    onPressed: () => setState(() {
                      _searching = !_searching;
                      if (!_searching) _query = '';
                    }),
                  ),
                if (widget.showLocalFab && !offline)
                  JourneyRoundButton(
                    key: const ValueKey('guests-add'),
                    icon: LucideIcons.plus,
                    tooltip: 'ضيف جديد',
                    onPressed: provider.isSubmitting
                        ? null
                        : () => _showGuestSheet(provider: provider),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (offline) ...[
              JourneyNote(
                key: const ValueKey('guests-offline'),
                text: [
                  'تشوف القائمة. الإضافة والدعوات لما يرجع النت.',
                  if (sync?.lastSyncedAt case final at?) _lastUpdate(at),
                ].join('\n'),
                icon: LucideIcons.wifiOff,
                color: AarastV3Color.textMuted,
                soft: AarastV3Color.paper,
              ),
              const SizedBox(height: 12),
            ] else if (provider.errorMessage != null && guests.isNotEmpty) ...[
              JourneyListNotice(offline: false, onRetry: _load),
              const SizedBox(height: 12),
            ],
            if (_searching) ...[
              GuestSearchField(
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
            ],
            body,
          ],
        ),
      ),
    );
  }

  Widget _overview(
    GuestsProvider provider,
    List<Guest> guests,
    GuestSummary summary,
  ) {
    final groupRows = <({String key, String name, List<Guest> guests})>[
      for (final group in provider.groups)
        (
          key: group.id,
          name: group.name,
          guests: guests.where((guest) => guest.groupId == group.id).toList(),
        ),
    ]..removeWhere((row) => row.guests.isEmpty);
    final ungrouped = guests
        .where(
          (guest) => guestGroupLabel(guest, provider.groups) == 'بدون مجموعة',
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GuestSummaryCard(summary: summary),
        if (!_isLocalPlan && summary.pending > 0) ...[
          const SizedBox(height: 10),
          JourneyButton(
            key: const ValueKey('guests-remind'),
            label: 'ذكّر الـ ${summary.pending} على واتساب',
            icon: LucideIcons.send,
            background: AarastV3Color.lilac,
            expand: true,
            onPressed: () => context.push(
              AppRouter.guestInvite(widget.weddingPlanId, reminder: true),
            ),
          ),
        ],
        if (!_isLocalPlan) ...[
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: JourneyTextAction(
              key: const ValueKey('guests-invite-card'),
              label: 'بطاقة الدعوة',
              icon: LucideIcons.mail,
              color: AarastV3Color.lilac,
              onPressed: () =>
                  context.push(AppRouter.guestInvite(widget.weddingPlanId)),
            ),
          ),
        ],
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          children: [
            if (ContactPickerService.isAvailable)
              JourneyTextAction(
                key: const ValueKey('guests-from-contacts'),
                label: 'من جهات الاتصال',
                icon: LucideIcons.contact,
                color: AarastV3Color.lilac,
                onPressed: () => _openImport(contacts: true),
              ),
            JourneyTextAction(
              key: const ValueKey('guests-paste-list'),
              label: 'الصق قائمة',
              icon: LucideIcons.clipboardList,
              color: AarastV3Color.lilac,
              onPressed: () => _openImport(contacts: false),
            ),
          ],
        ),
        const SizedBox(height: 8),
        JourneySectionTitle(
          'حسب العائلة',
          action: _isLocalPlan ? null : 'المجموعات',
          onAction: _isLocalPlan ? null : _showGroupsSheet,
        ),
        JourneyBox(
          padding: EdgeInsets.zero,
          child: JourneyList(
            children: [
              _GroupRow(
                key: const ValueKey('guest-group-all'),
                name: 'كل الضيوف',
                guests: guests,
                icon: LucideIcons.users,
                onTap: () => _openGroupView(_allGroups),
              ),
              for (final row in groupRows)
                _GroupRow(
                  key: ValueKey('guest-group-${row.key}'),
                  name: row.name,
                  guests: row.guests,
                  onTap: () => _openGroupView(row.key),
                ),
              if (ungrouped.isNotEmpty && groupRows.isNotEmpty)
                _GroupRow(
                  key: const ValueKey('guest-group-none'),
                  name: 'بدون مجموعة',
                  guests: ungrouped,
                  icon: LucideIcons.userX,
                  onTap: () => _openGroupView(_noGroup),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _groupView(
    GuestsProvider provider,
    List<Guest> guests,
    Set<String> duplicates,
  ) {
    final open = _openGroup!;
    final inGroup = switch (open) {
      _allGroups => guests,
      _noGroup =>
        guests
            .where(
              (guest) =>
                  guestGroupLabel(guest, provider.groups) == 'بدون مجموعة',
            )
            .toList(),
      _ => guests.where((guest) => guest.groupId == open).toList(),
    };
    final title = switch (open) {
      _allGroups => 'كل الضيوف',
      _noGroup => 'بدون مجموعة',
      _ =>
        provider.groups
                .where((group) => group.id == open)
                .map((group) => group.name)
                .firstOrNull ??
            'المجموعة',
    };
    final visible = _filtered(inGroup, _reply)
      ..sort((a, b) => a.name.compareTo(b.name));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: JourneyTextAction(
            key: const ValueKey('guest-group-back'),
            label: 'كل العائلات',
            icon: LucideIcons.chevronRight,
            color: AarastV3Color.lilac,
            onPressed: () => setState(() => _openGroup = null),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
          child: Text(
            '$title · ${_guestCount(inGroup.length)}',
            style: JourneyType.of(JourneyType.title, weight: JourneyType.bold),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in _ReplyFilter.values) ...[
                JourneyChip(
                  key: ValueKey('guest-filter-${filter.name}'),
                  label: '${filter.label} ${_filtered(inGroup, filter).length}',
                  selected: _reply == filter,
                  selectedColor: AarastV3Color.lilac,
                  onTap: () => setState(() => _reply = filter),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _guestBox(provider, visible, duplicates, empty: 'ما فيه أحد هنا'),
      ],
    );
  }

  Widget _guestBox(
    GuestsProvider provider,
    List<Guest> guests,
    Set<String> duplicates, {
    required String empty,
  }) {
    if (guests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          empty,
          textAlign: TextAlign.center,
          style: JourneyType.of(
            JourneyType.body,
            color: AarastV3Color.textMuted,
          ),
        ),
      );
    }
    return JourneyBox(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < guests.length; index++) ...[
            if (index > 0)
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AarastV3Color.line,
              ),
            GuestRow(
              guest: guests[index],
              groupLabel: guestGroupLabel(guests[index], provider.groups),
              isDuplicate: duplicates.contains(guests[index].id),
              onOpen: () => context.push(
                AppRouter.guestDetails(widget.weddingPlanId, guests[index].id),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openGroupView(String key) => setState(() {
    _openGroup = key;
    _reply = _ReplyFilter.all;
  });

  /// Groups are saved on the account, so a device-only plan has none (w27).
  Future<void> _showGroupsSheet() {
    final provider = context.read<GuestsProvider>();
    return showJourneySheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => ListenableBuilder(
        listenable: provider,
        builder: (_, _) => GuestGroupsSheet(
          groups: provider.groups,
          guestCounts: {
            for (final group in provider.groups)
              group.id: provider.guests
                  .where((guest) => guest.groupId == group.id)
                  .length,
          },
          ungroupedCount: provider.guests
              .where(
                (guest) =>
                    guestGroupLabel(guest, provider.groups) == 'بدون مجموعة',
              )
              .length,
          saving: provider.isSavingGroups,
          errorMessage: provider.groupsErrorMessage,
          onCreate: (name) => provider.createGroup(widget.weddingPlanId, name),
          onRename: provider.renameGroup,
          onDelete: provider.deleteGroup,
        ),
      ),
    );
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

  Future<void> _showGuestSheet({required GuestsProvider provider}) async {
    final scope = 'guest:${widget.weddingPlanId}:new';
    final result = await showJourneySheet<GuestFormResult>(
      context: context,
      useRootNavigator: true,
      builder: (_) => GuestFormSheet(
        draftScope: scope,
        existingGuests: provider.guests,
        groups: provider.groups,
        blockDuplicatePhone: !_isLocalPlan,
        onCreateGroup: _isLocalPlan ? null : _createGroup,
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
    final ok = await provider.createGuest(
      weddingPlanId: widget.weddingPlanId,
      name: result.name,
      phone: result.phone,
      groupId: result.groupId,
      side: result.side,
      status: result.status,
      attendanceStatus: guestAttendanceForStatus(result.status),
      seatsCount: result.seatsCount,
      companionsCount: result.companionsCount,
      notes: result.notes,
    );
    if (!mounted) return;
    if (!ok) {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'ما قدرنا نحفظ الضيف',
      );
      return;
    }
    publishGuestPlanPulse(
      context,
      weddingPlanId: widget.weddingPlanId,
      summary: provider.summary,
    );
    await context.read<AarastFormDraftStore?>()?.clear(scope);
    if (!mounted) return;
    if (result.addAnother) {
      AarastToast.showSuccess(context, 'انضاف ${result.name}');
      await _showGuestSheet(provider: provider);
      return;
    }
    AarastFormSuccess.show(
      context,
      message: provider.noticeMessage ?? 'انضاف الضيف',
      nextLabel: 'أضف ثاني',
      onNext: () => _showGuestSheet(provider: provider),
    );
  }

  void _openImport({required bool contacts}) {
    context.push(
      AppRouter.guestImport(widget.weddingPlanId, contacts: contacts),
    );
  }

  /// «جديدة» in the guest form: the group is saved first, then chosen.
  Future<String?> _createGroup(String name) async {
    final provider = context.read<GuestsProvider>();
    final ok = await provider.createGroup(widget.weddingPlanId, name);
    if (!ok) {
      if (mounted) {
        AarastToast.showError(
          context,
          provider.groupsErrorMessage ?? 'ما قدرنا نضيف المجموعة',
        );
      }
      return null;
    }
    return provider.groups.last.id;
  }
}
