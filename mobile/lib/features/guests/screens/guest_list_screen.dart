import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_picker_service.dart';
import '../../../core/utils/arabic_sort.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/forms/aarast_form_success.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/sync_status.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/root_tab_back_scope.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthActionGuard;
import '../../wedding_day/wedding_day_api.dart'
    show PlanEvent, PlanEventsProvider, showPlanEventSheet;
import '../../wedding_plans/wedding_plans_api.dart' show publishGuestPlanPulse;
import '../models/guest.dart';
import '../models/guest_invitations.dart';
import '../models/guest_invite_text.dart' show guestChatCanOpen;
import '../providers/guests_provider.dart';
import '../utils/guest_display.dart';
import '../utils/guest_plan_events.dart';
import '../widgets/guest_form_sheet.dart';
import '../widgets/guest_groups_sheet.dart';
import '../widgets/guest_row.dart';
import '../widgets/guest_search_field.dart';
import '../widgets/occasion_invitees_sheet.dart';

part 'guest_list_screen_helpers.dart';
part 'guest_list_screen.occasions.dart';

/// e01 «الضيوف»: how many confirmed out of how many invited and who has not
/// answered, the guests by family with each group's progress, and every
/// guest one tap away. Offline (w29) it shows the saved list.
class GuestListScreen extends StatefulWidget {
  const GuestListScreen({
    required this.weddingPlanId,
    this.openAddOnStart = false,
    this.openAddRequest = 0,
    this.openAddMenuRequest = 0,
    this.ownerWord,
    this.showHeaderAdd = true,
    super.key,
  });

  /// D116: raised by the plan shell's «+» on this tab; each new value opens
  /// the add menu once (a guest, several, an occasion, a group).
  final int openAddMenuRequest;

  final String weddingPlanId;
  final bool openAddOnStart;

  /// Whether the header draws its own «+». False where a shell already
  /// floats one over this tab: the two opened the same sheet, so the screen
  /// showed two controls for one action. It stays true for the participant's
  /// shell, which floats none, and for /guests/add, which has no chrome —
  /// there the header's «+» is the only way in.
  final bool showHeaderAdd;

  /// «العريس», «العروسة» when the reader helps on another's plan (D80):
  /// the list is the whole plan's, and the owner keeps the numbers and the
  /// edits of every guest the reader did not add. Null on the owner's list.
  final String? ownerWord;

  /// Raised by the home shell's «+» (D33): each new value opens the add
  /// sheet once.
  final int openAddRequest;

  @override
  State<GuestListScreen> createState() => _GuestListScreenState();
}

/// The last «+» request the guests tab answered, kept across rebuilds of the
/// tab (AppRouter.guestListAddMenu numbers them).
int _answeredAddMenuRequest = 0;

class _GuestListScreenState extends State<GuestListScreen> {
  /// null: the overview; otherwise the group being looked at.
  String? _openGroup;
  _ReplyFilter _reply = _ReplyFilter.all;

  /// D116: the occasion the overview follows; null, the wedding.
  String? _occasion;
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
      if (widget.openAddMenuRequest > 0) unawaited(_openAddMenuRequested());
    });
  }

  /// The shell's «+» on this tab: each request opens the menu once. The
  /// address is left as it is: going back to the list address under the
  /// menu took the sheet away with the old page on the device. A request
  /// already answered (back from the import, the tab built again) does not
  /// open it again.
  Future<void> _openAddMenuRequested() async {
    final request = widget.openAddMenuRequest;
    if (request <= _answeredAddMenuRequest) return;
    _answeredAddMenuRequest = request;
    await _onAdd(context.read<GuestsProvider>());
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
    if (widget.openAddMenuRequest > 0 &&
        oldWidget.openAddMenuRequest != widget.openAddMenuRequest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openAddMenuRequested());
      });
    }
  }

  Future<void> _load() {
    // D83: the plan's events, so a new guest can be invited to the lunch.
    if (!_isLocalPlan) readPlanEventsOnce(context, widget.weddingPlanId);
    return context.read<GuestsProvider>().loadGuests(widget.weddingPlanId);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuestsProvider>();
    final sync = context.watch<OfflineSyncService?>();
    // An account plan without a connection shows its last copy with a note;
    // adding still works, saved on the phone (D85). A plan kept on the phone
    // needs no connection at all.
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
    final words = GuestWords.of(context);
    final helps = widget.ownerWord != null;
    final emptyLine = helps ? _emptyPlanLine(context) : words.noneAdded;

    // D1 of the closing round: until the plan's list is read (the phone's
    // copy or the server's answer) an empty list is «not read yet», not «no
    // guests»; the first-guests page flashed before the copy arrived.
    final notReadYet =
        !provider.hasRead(widget.weddingPlanId) &&
        provider.loadErrorMessage == null;
    final _ListPart body;
    if ((provider.isLoading || notReadYet) && guests.isEmpty) {
      body = const _ListPart([
        JourneyListState(
          phase: JourneyListPhase.loading,
          section: JourneySection.guests,
        ),
      ]);
    } else if (provider.loadErrorMessage != null && guests.isEmpty) {
      body = _ListPart([
        JourneyListState(
          phase: JourneyListPhase.error,
          section: JourneySection.guests,
          onRetry: _load,
        ),
      ]);
    } else if (guests.isEmpty) {
      body = _ListPart([
        _FirstGuests(
          emptyLine: emptyLine,
          onContacts: ContactPickerService.isAvailable
              ? () => _openImport(contacts: true)
              : null,
          onPaste: () => _openImport(contacts: false),
          onOne: () => _showGuestSheet(provider: provider),
        ),
      ]);
    } else if (query.isNotEmpty) {
      body = _guestRows(
        _search(guests, query),
        duplicates,
        empty: 'ما لقينا أحد بهذا الاسم أو الرقم',
      );
    } else if (_openGroup != null) {
      body = _groupView(provider, guests, duplicates);
    } else {
      body = _ListPart([_overview(provider, guests, summary)]);
    }

    // The open group and the search box are states inside one route, and the
    // screen draws its own way back out of them («كل العائلات», the X on the
    // search). Android back has to undo the same states, or it leaves the
    // tab while the screen still shows a back affordance.
    final nested = _openGroup != null || _searching;
    return TabBackStep(
      nested: nested,
      onBack: () {
        setState(() {
          if (_searching) {
            _searching = false;
            _query = '';
          } else {
            _openGroup = null;
            _reply = _ReplyFilter.all;
          }
        });
      },
      child: AarastScreenFrame(
        backgroundColor: AarastV3Color.canvas,
        child: RefreshIndicator(
          color: context.accent.primary,
          onRefresh: _isLocalPlan ? () async {} : _load,
          child: CustomScrollView(
            // The overview, a family and the search each start at their top:
            // a family opened from low on the overview kept its scroll and
            // opened in the middle of its rows, its title, its way back and
            // its answer chips above the screen (RA-MO-16).
            key: ValueKey('guests-${_openGroup ?? '-'}-$_searching'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AarastV3Space.x4,
                  AarastV3Space.x3,
                  AarastV3Space.x4,
                  0,
                ),
                sliver: SliverList.list(
                  children: [
                    JourneyTabHeader(
                      title: words.guests,
                      status: _statusLine(summary, words, helps: helps),
                      actions: [
                        if (guests.isNotEmpty)
                          JourneyRoundButton(
                            key: const ValueKey('guests-search'),
                            icon: _searching
                                ? LucideIcons.x
                                : LucideIcons.search,
                            tooltip: _searching
                                ? context.say('سكّر البحث', 'سكّري البحث')
                                : '${context.say('دوّر', 'دوّري')} على '
                                      '${context.planWord('ضيف', 'ضيفة')}',
                            onPressed: () => setState(() {
                              _searching = !_searching;
                              if (!_searching) _query = '';
                            }),
                          ),
                        // D85: adding never waits for the server; a guest added
                        // without it is kept on the phone and sent later.
                        if (widget.showHeaderAdd)
                          JourneyRoundButton(
                            key: const ValueKey('guests-add'),
                            icon: LucideIcons.plus,
                            tooltip: words.newGuest,
                            onPressed: provider.isSubmitting
                                ? null
                                : () => _onAdd(provider),
                          ),
                      ],
                    ),
                    const SizedBox(height: AarastV3Space.x3),
                    if (offline || provider.isStale) ...[
                      JourneyNote(
                        key: const ValueKey('guests-offline'),
                        text: [
                          // D85: the copy is the phone's; the invitations need the
                          // server because their links are its.
                          context.say(
                            'تشوف آخر نسخة محفوظة، واللي تضيفه ينحفظ في جوالك ويوصل لما يرجع النت. الدعوات تحتاج نت.',
                            'تشوفين آخر نسخة محفوظة، واللي تضيفينه ينحفظ في جوالك ويوصل لما يرجع النت. الدعوات تحتاج نت.',
                          ),
                          if (sync?.lastSyncedAt case final at?)
                            _lastUpdate(at),
                        ].join('\n'),
                        icon: LucideIcons.wifiOff,
                        color: AarastV3Color.textMuted,
                        soft: AarastV3Color.paper,
                      ),
                      const SizedBox(height: AarastV3Space.x3),
                    ] else if (provider.loadErrorMessage != null &&
                        guests.isNotEmpty) ...[
                      JourneyListNotice(offline: false, onRetry: _load),
                      const SizedBox(height: AarastV3Space.x3),
                    ],
                    if (widget.ownerWord case final owner?
                        when guests.any((guest) => !guest.editable)) ...[
                      JourneyNote(
                        key: const ValueKey('guests-helper-note'),
                        text: context.say(
                          'تشوف كل ${words.guests}. تعدّل اللي من إضافتك، وأرقام البقية عند $owner.',
                          'تشوفين كل ${words.guests}. تعدّلين اللي من إضافتك، وأرقام البقية عند $owner.',
                        ),
                        icon: LucideIcons.eye,
                        color: AarastV3Color.textMuted,
                        soft: AarastV3Color.paper,
                      ),
                      const SizedBox(height: AarastV3Space.x3),
                    ],
                    if (_searching) ...[
                      GuestSearchField(
                        onChanged: (value) => setState(() => _query = value),
                      ),
                      const SizedBox(height: AarastV3Space.x3),
                    ],
                    ...body.widgets,
                  ],
                ),
              ),
              // RA-MO-16: the guest rows are built as they scroll in, so a
              // list of hundreds is one list, every name reached by
              // scrolling. Fifty at a time behind «باقي» hid a guest just
              // added whose name sorts late.
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AarastV3Space.x4,
                  0,
                  AarastV3Space.x4,
                  AarastV3Density.pageBottomWithQuickAction,
                ),
                sliver: SliverList.builder(
                  itemCount: body.rows.length,
                  itemBuilder: (context, index) =>
                      _guestRowAt(provider, body, index),
                ),
              ),
            ],
          ),
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
    final words = GuestWords.of(context);
    // D116: the occasion the figures, the send and the families follow.
    final planId = widget.weddingPlanId;
    final occasions = planOccasions(
      context.watch<PlanEventsProvider?>()?.viewOf(planId)?.items ?? const [],
      planId,
    );
    final selected =
        occasions
            .where((event) => occasionKey(event, planId) == _occasion)
            .firstOrNull ??
        occasions.first;
    final selectedKey = occasionKey(selected, planId);
    OccasionStanding? standingOf(Guest guest) =>
        guestOccasion(guest, occasions, planId, selectedKey)?.standing;
    final invited = [
      for (final guest in guests)
        if (standingOf(guest) != null) guest,
    ];
    final counts = occasionCountsOf(guests, occasions, planId, selectedKey);
    final due = _isLocalPlan
        ? null
        : SendAudience.values
              .map(
                (audience) => (
                  audience: audience,
                  // RA-MO-61: the button counts who a message reaches (a
                  // number whose chat opens), as the send screen does; the
                  // ones without are listed there.
                  count: invited
                      .where(
                        (guest) =>
                            guest.editable &&
                            guest.hasPhone &&
                            guestChatCanOpen(guest.phone) &&
                            audience.includes(standingOf(guest)!),
                      )
                      .length,
                ),
              )
              .where((entry) => entry.count > 0)
              .firstOrNull;
    void openSend([SendAudience? audience]) => context.push(
      AppRouter.guestSend(
        planId,
        event: selected.isMain ? null : selectedKey,
        audience: audience?.wire,
      ),
    );
    bool isConfirmedHere(Guest guest) => standingOf(guest)?.isConfirmed == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (occasions.length > 1) ...[
          _OccasionPicker(
            occasions: occasions,
            selected: selectedKey,
            weddingPlanId: planId,
            onSelected: (key) => setState(() => _occasion = key),
          ),
          const SizedBox(height: AarastV3Space.x3),
        ],
        _OccasionSummaryCard(
          label: guestEventLabel(selected, context.journeyProfile),
          showLabel: occasions.length > 1,
          counts: counts,
          onTap: () => context.push(AppRouter.guestAttendance(planId)),
          // The one send due, as the hero's tag.
          sendKey: due == null
              ? null
              : ValueKey('guests-send-${due.audience.wire}'),
          sendLabel: due == null
              ? null
              : switch (due.audience) {
                  SendAudience.notTold =>
                    '${context.say('أرسل', 'أرسلي')} الدعوة لـ${words.count(due.count)}',
                  SendAudience.changed =>
                    '${context.say('بلّغ', 'بلّغي')} ${words.count(due.count)} بالتغيير',
                  SendAudience.silent =>
                    '${context.say('ذكّر', 'ذكّري')} ${words.count(due.count)}',
                },
          onSend: due == null ? null : () => openSend(due.audience),
          allOptions: _isLocalPlan || invited.every((guest) => !guest.editable)
              ? null
              : JourneyTextAction(
                  key: const ValueKey('guests-send-all-options'),
                  label: 'خيارات الإرسال',
                  icon: LucideIcons.send,
                  color: context.accent.primary,
                  onPressed: openSend,
                ),
        ),
        // D116: an occasion beyond the wedding chooses its own guests, a
        // whole group at a time.
        if (!selected.isMain && !_isLocalPlan && selected.id != null) ...[
          const SizedBox(height: AarastV3Space.x1),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: JourneyTextAction(
              key: const ValueKey('guests-occasion-invitees'),
              label:
                  '${context.say('اختر', 'اختاري')} مدعوين ${guestEventLabel(selected, context.journeyProfile)}',
              icon: LucideIcons.userCheck,
              color: context.accent.primary,
              onPressed: provider.isSubmitting
                  ? null
                  : () => showJourneySheet<int>(
                      context: context,
                      builder: (_) => OccasionInviteesSheet(
                        provider: provider,
                        weddingPlanId: planId,
                        eventId: selected.id!,
                        label: guestEventLabel(
                          selected,
                          context.journeyProfile,
                        ),
                      ),
                    ),
            ),
          ),
        ],
        const SizedBox(height: AarastV3Space.x3),
        _InvitationDoors(
          weddingPlanId: planId,
          occasionCount: occasions.length,
          localPlan: _isLocalPlan,
        ),
        const SizedBox(height: AarastV3Space.x3),
        JourneySectionTitle(
          'حسب المجموعة',
          action: _isLocalPlan ? null : 'المجموعات',
          onAction: _isLocalPlan ? null : _showGroupsSheet,
          // The guests' own colour, as e01 draws the section's link.
          actionColor: context.accent.primary,
        ),
        JourneyBox(
          padding: EdgeInsets.zero,
          child: JourneyList(
            children: [
              // D116: each family counts the guests of the occasion followed.
              _GroupRow(
                key: const ValueKey('guest-group-all'),
                name: GuestWords.of(context).allGuests,
                guests: invited,
                isConfirmed: isConfirmedHere,
                icon: LucideIcons.users,
                onTap: () => _openGroupView(_allGroups),
              ),
              for (final row in groupRows)
                if (row.guests.where(invited.contains).toList()
                    case final members when members.isNotEmpty)
                  _GroupRow(
                    key: ValueKey('guest-group-${row.key}'),
                    name: row.name,
                    guests: members,
                    isConfirmed: isConfirmedHere,
                    onTap: () => _openGroupView(row.key),
                  ),
              if (ungrouped.where(invited.contains).toList() case final members
                  when members.isNotEmpty && groupRows.isNotEmpty)
                _GroupRow(
                  key: const ValueKey('guest-group-none'),
                  name: 'بدون مجموعة',
                  guests: members,
                  isConfirmed: isConfirmedHere,
                  icon: LucideIcons.userX,
                  onTap: () => _openGroupView(_noGroup),
                ),
            ],
          ),
        ),
      ],
    );
  }

  _ListPart _groupView(
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
    final words = GuestWords.of(context);
    final title = switch (open) {
      _allGroups => words.allGuests,
      _noGroup => 'بدون مجموعة',
      _ =>
        provider.groups
                .where((group) => group.id == open)
                .map((group) => group.name)
                .firstOrNull ??
            'المجموعة',
    };
    final visible = _filtered(inGroup, _reply)
      ..sort((a, b) => compareArabicNames(a.name, b.name));
    // Each chip's count, from the group the reader opened.
    final counts = <_ReplyFilter, int>{
      for (final filter in _ReplyFilter.values)
        filter: _filtered(inGroup, filter).length,
    };
    return _guestRows(
      visible,
      duplicates,
      before: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: JourneyTextAction(
            key: const ValueKey('guest-group-back'),
            label: 'كل العائلات',
            icon: LucideIcons.chevronRight,
            color: context.accent.primary,
            onPressed: () => setState(() => _openGroup = null),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AarastV3Space.x1,
            AarastV3Space.x1,
            AarastV3Space.x1,
            AarastV3Space.x2,
          ),
          child: Text(
            '$title · ${words.count(inGroup.length)}',
            style: JourneyType.of(JourneyType.lead, weight: JourneyType.bold),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in _ReplyFilter.values) ...[
                JourneyChip(
                  key: ValueKey('guest-filter-${filter.name}'),
                  label: '${filter.labelFor(words)} ${counts[filter] ?? 0}',
                  selected: _reply == filter,
                  selectedColor: context.accent.primary,
                  onTap: () => setState(() => _reply = filter),
                ),
                const SizedBox(width: AarastV3Space.x2),
              ],
            ],
          ),
        ),
        const SizedBox(height: AarastV3Space.x3),
      ],
      empty: _reply == _ReplyFilter.all
          ? 'ما فيه أحد هنا'
          : 'ما فيه أحد تحت «${_reply.labelFor(words)}» في $title',
      emptyAction: _reply == _ReplyFilter.all ? null : 'شوف الكل',
      onEmptyAction: _reply == _ReplyFilter.all
          ? null
          : () => setState(() => _reply = _ReplyFilter.all),
    );
  }

  /// [before], then [guests] as rows the page builds as they scroll in, or
  /// the line that says nobody matched.
  _ListPart _guestRows(
    List<Guest> guests,
    Set<String> duplicates, {
    List<Widget> before = const [],
    required String empty,
    String? emptyAction,
    VoidCallback? onEmptyAction,
  }) {
    if (guests.isNotEmpty) return _ListPart(before, guests, duplicates);
    // A filter that matched nobody is not an empty list, and it must say
    // the way back out of itself.
    return _ListPart([
      ...before,
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x6),
        child: Column(
          children: [
            Text(
              empty,
              textAlign: TextAlign.center,
              style: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textMuted,
              ),
            ),
            if (emptyAction != null && onEmptyAction != null) ...[
              const SizedBox(height: AarastV3Space.x2),
              JourneyTextAction(
                key: const ValueKey('guests-clear-reply-filter'),
                label: emptyAction,
                color: context.accent.primary,
                onPressed: onEmptyAction,
              ),
            ],
          ],
        ),
      ),
    ]);
  }

  /// One guest row as its slice of the list's card: the card's paper, its
  /// corners on the first and last row, and a line between rows.
  Widget _guestRowAt(GuestsProvider provider, _ListPart part, int index) {
    final guest = part.rows[index];
    const corner = Radius.circular(AarastV3Radius.card);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.vertical(
          top: index == 0 ? corner : Radius.zero,
          bottom: index == part.rows.length - 1 ? corner : Radius.zero,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (index > 0)
            const Divider(
              height: AarastV3Space.hair,
              indent: 16,
              endIndent: 16,
              color: AarastV3Color.line,
            ),
          GuestRow(
            guest: guest,
            groupLabel: guestGroupLabel(guest, provider.groups),
            isDuplicate: part.duplicates.contains(guest.id),
            onOpen: () => context.push(
              AppRouter.guestDetails(widget.weddingPlanId, guest.id),
            ),
          ),
        ],
      ),
    );
  }

  void _openGroupView(String key) => setState(() {
    _openGroup = key;
    _reply = _ReplyFilter.all;
  });

  /// Groups are saved on the account, so a device-only plan has none (w27).
  /// D116: «+» adds what the guests tab holds: a guest, many at once, an
  /// occasion, a group.
  Future<void> _onAdd(GuestsProvider provider) async {
    final choice = await _showAddMenu(context, localPlan: _isLocalPlan);
    if (!mounted || choice == null) return;
    switch (choice) {
      case _AddChoice.guest:
        await _showGuestSheet(provider: provider);
      case _AddChoice.contacts:
        _openImport(contacts: true);
      case _AddChoice.paste:
        _openImport(contacts: false);
      case _AddChoice.group:
        await _showGroupsSheet();
      case _AddChoice.occasion:
        final events = context.read<PlanEventsProvider?>();
        if (events == null) return;
        await showPlanEventSheet(
          context,
          weddingPlanId: widget.weddingPlanId,
          provider: events,
        );
    }
  }

  Future<void> _showGroupsSheet() {
    final provider = context.read<GuestsProvider>()..clearGroupsError();
    // D8 of the closing round: the plan's own guests; the counts took every
    // guest the phone held, another plan's among them.
    Iterable<Guest> planGuests() => provider.guests.where(
      (guest) => guest.weddingPlanId == widget.weddingPlanId,
    );
    return showJourneySheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => ListenableBuilder(
        listenable: provider,
        builder: (_, _) => GuestGroupsSheet(
          groups: provider.groups,
          guestCounts: {
            for (final group in provider.groups)
              group.id: planGuests()
                  .where((guest) => guest.groupId == group.id)
                  .length,
          },
          ungroupedCount: planGuests()
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

  Future<void> _showGuestSheet({
    required GuestsProvider provider,
    String? saveError,
  }) async {
    final scope = 'guest:${widget.weddingPlanId}:new';
    final events = _isLocalPlan
        ? const <GuestFormEvent>[]
        : guestFormEventsOf(context, widget.weddingPlanId, listen: false);
    final result = await showJourneySheet<GuestFormResult>(
      context: context,
      useRootNavigator: true,
      builder: (_) => GuestFormSheet(
        draftScope: scope,
        existingGuests: provider.guests,
        // D80: a helper adds into the groups they made; the server refuses
        // another's group.
        groups: provider.editableGroups,
        events: events,
        onAddEvent: _isLocalPlan
            ? null
            : () => addOccasionFromForm(context, widget.weddingPlanId),
        blockDuplicatePhone: !_isLocalPlan,
        onCreateGroup: _isLocalPlan ? null : _createGroup,
        saveError: saveError,
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
      // D83: only when the form offered the plan's events.
      eventIds: events.isEmpty ? null : result.eventIds,
    );
    if (!mounted) return;
    if (!ok) {
      // Critique ط4: the sheet opens again with what was typed (its draft
      // is kept until a save succeeds) and says why by its button.
      await _showGuestSheet(
        provider: provider,
        saveError:
            provider.errorMessage ??
            context.planWord('ما قدرنا نحفظ الضيف', 'ما قدرنا نحفظ الضيفة'),
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
    // RA-MO-26: from /guests/add this screen closes right after (its route
    // goes back to the list), while the receipt stays. Its «أضف ثاني» then
    // opens the add route again through the router, not a sheet on a screen
    // that is gone.
    final router = GoRouter.maybeOf(context);
    final planId = widget.weddingPlanId;
    AarastFormSuccess.show(
      context,
      message:
          provider.noticeMessage ??
          context.planWord('انضاف الضيف', 'انضافت الضيفة'),
      // The verb is the reader's, «ثاني/ثانية» the plan's guest.
      nextLabel:
          '${context.say('أضف', 'أضيفي')} ${context.planWord('ثاني', 'ثانية')}',
      onNext: () {
        if (mounted) {
          _showGuestSheet(provider: provider);
        } else {
          router?.go(AppRouter.guestListAdd(planId));
        }
      },
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
