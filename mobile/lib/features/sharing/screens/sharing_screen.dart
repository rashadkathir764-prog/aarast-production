import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_picker_service.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthActionGuard, AuthGatePanel;
import '../models/participant_access.dart';
import '../models/shared_member.dart';
import '../providers/sharing_provider.dart';
import '../widgets/add_participant_sheet.dart';
import '../widgets/invite_link_copy.dart';
import '../widgets/participant_access_editor.dart' show participantReadingNote;
import '../../../shared/models/contact_phone_draft.dart';

/// g01 «المشاركين» and its x07 state «مين معك ومين لسا»: who helps with
/// what (`GET P/members`, the line built from their stored flags), who has
/// not accepted yet (`GET P/invites` with the WhatsApp delivery), and the
/// ready roles to add someone (C63). Pending invites refresh while open.
class SharingScreen extends StatefulWidget {
  const SharingScreen({
    required this.weddingPlanId,
    this.startAdding = false,
    this.pendingInviteRefreshInterval = const Duration(seconds: 10),
    super.key,
  });

  final String weddingPlanId;

  /// Opens «أضف مشارك» once the list is ready (the add route).
  final bool startAdding;
  final Duration pendingInviteRefreshInterval;

  @override
  State<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends State<SharingScreen>
    with WidgetsBindingObserver {
  bool _isCheckingSharingAccess = true;
  bool _showLoginGate = false;
  bool _showPermissionGate = false;
  bool _showAccessError = false;
  bool _addOpened = false;
  Timer? _pendingInviteRefreshTimer;
  int _refreshGeneration = 0;
  int _refreshesInFlight = 0;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isForeground =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshSharingAccessAndLoad();
    });
  }

  @override
  void dispose() {
    _refreshGeneration += 1;
    _pendingInviteRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (!_isForeground) {
      _pendingInviteRefreshTimer?.cancel();
      _pendingInviteRefreshTimer = null;
      return;
    }
    if (!mounted) return;
    unawaited(
      _refreshSharingAccessAndLoad(
        showPageLoader: false,
        preserveCurrentState: true,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant SharingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId ||
        oldWidget.pendingInviteRefreshInterval !=
            widget.pendingInviteRefreshInterval) {
      _refreshGeneration += 1;
      _pendingInviteRefreshTimer?.cancel();
      _pendingInviteRefreshTimer = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refreshSharingAccessAndLoad();
      });
    }
  }

  Future<void> _refreshSharingAccessAndLoad({
    bool showPageLoader = true,
    bool preserveCurrentState = false,
  }) async {
    final planId = widget.weddingPlanId;
    final generation = ++_refreshGeneration;
    _refreshesInFlight += 1;
    _pendingInviteRefreshTimer?.cancel();
    _pendingInviteRefreshTimer = null;
    if (showPageLoader) {
      setState(() {
        _isCheckingSharingAccess = true;
        _showLoginGate = false;
        _showPermissionGate = false;
        _showAccessError = false;
      });
    }

    try {
      final shouldGate = await AuthActionGuard.shouldGateProtectedSharing(
        context,
        weddingPlanId: planId,
      );
      if (!_isCurrentRefresh(generation, planId)) return;

      if (shouldGate) {
        setState(() {
          _isCheckingSharingAccess = false;
          _showLoginGate = true;
          _showPermissionGate = false;
          _showAccessError = false;
        });
        return;
      }

      if (!mounted) return;
      final provider = context.read<SharingProvider>();
      final accessLoaded = await provider.loadAccess(
        planId,
        preserveCurrentState: preserveCurrentState,
      );
      if (!_isCurrentRefresh(generation, planId)) return;
      final canManageMembers = accessLoaded && provider.access.canManageMembers;
      if (canManageMembers) {
        await provider.loadMembers(
          planId,
          preserveCurrentState: preserveCurrentState,
        );
        if (!_isCurrentRefresh(generation, planId)) return;
      }

      setState(() {
        _isCheckingSharingAccess = false;
        _showLoginGate = false;
        _showPermissionGate = accessLoaded && !canManageMembers;
        _showAccessError = !accessLoaded && provider.authGateKind == null;
      });
      if (canManageMembers &&
          widget.startAdding &&
          !_addOpened &&
          provider.authGateKind == null) {
        _addOpened = true;
        unawaited(_openAdd(ParticipantPreset.helper));
      }
    } finally {
      _refreshesInFlight -= 1;
      if (mounted && _refreshesInFlight == 0) {
        _syncPendingInviteRefreshTimer();
      }
    }
  }

  bool _isCurrentRefresh(int generation, String planId) {
    return mounted &&
        generation == _refreshGeneration &&
        planId == widget.weddingPlanId;
  }

  void _syncPendingInviteRefreshTimer() {
    if (!mounted || !_isForeground || _refreshesInFlight > 0) return;
    final provider = context.read<SharingProvider>();
    final canObserveCurrentPlanInvites =
        !_isCheckingSharingAccess &&
        !_showLoginGate &&
        !_showPermissionGate &&
        !_showAccessError &&
        provider.authGateKind == null &&
        provider.access.weddingPlanId == widget.weddingPlanId &&
        provider.access.canManageMembers;
    final hasPendingInvites =
        canObserveCurrentPlanInvites &&
        provider.invites.any(
          (invite) =>
              invite.weddingPlanId == widget.weddingPlanId && invite.isPending,
        );
    if (!hasPendingInvites) {
      _pendingInviteRefreshTimer?.cancel();
      _pendingInviteRefreshTimer = null;
      return;
    }
    if (_pendingInviteRefreshTimer?.isActive == true) return;
    _pendingInviteRefreshTimer = Timer(widget.pendingInviteRefreshInterval, () {
      _pendingInviteRefreshTimer = null;
      if (!mounted || !_isForeground) return;
      // RA-MO-266: under a page pushed on top (a participant, the history)
      // this refresh raced that page's own read on the shared provider,
      // and the page showed an error or «ما لقينا هذا المشارك» for someone
      // who is there. The list waits its turn, and reads again on return.
      if (ModalRoute.of(context)?.isCurrent == false) {
        _syncPendingInviteRefreshTimer();
        return;
      }
      unawaited(
        _refreshSharingAccessAndLoad(
          showPageLoader: false,
          preserveCurrentState: true,
        ),
      );
    });
  }

  Future<void> _openAdd(ParticipantPreset preset) async {
    await showAddParticipantSheet(
      context,
      weddingPlanId: widget.weddingPlanId,
      preset: preset,
    );
    if (mounted) _readAfterAdd();
  }

  /// RA-MO-270: an invite the server made but whose answer was lost was
  /// not in the list, and nothing read the list again once the sheet
  /// closed: the owner kept seeing «لسا ما أضفت أحد» and a second try was
  /// refused as «مرسلة من قبل».
  void _readAfterAdd() {
    unawaited(
      _refreshSharingAccessAndLoad(
        showPageLoader: false,
        preserveCurrentState: true,
      ),
    );
  }

  Future<void> _addFromContacts() async {
    try {
      final contact = await ContactPickerService.pickContact(context);
      if (!mounted || contact == null) return;
      await showAddParticipantSheet(
        context,
        weddingPlanId: widget.weddingPlanId,
        contact: contact,
      );
      if (mounted) _readAfterAdd();
    } on Object catch (error) {
      if (mounted) {
        AarastToast.showError(context, contactPickerErrorMessage(error));
      }
    }
  }

  /// «ذكّره» and «انسخ الرابط» both mint a new link; the old one stops
  /// working, and the message says so (C31).
  Future<void> _reissueInvite(PlanInvite invite) async {
    final provider = context.read<SharingProvider>();
    final reissued = await provider.reissueInvite(invite);
    if (!mounted || reissued == null) return;

    if (reissued.wasDeliveredByAarast) {
      AarastToast.showSuccess(context, newLinkDeliveredMessage);
      return;
    }
    final copied = await copyInviteText(
      context,
      newInviteLinkMessage(reissued),
    );
    if (!mounted || !copied) return;
    AarastToast.showSuccess(
      context,
      context.say(
        'نسخنا رابط جديد، أرسله له. القديم ما عاد يشتغل.',
        // The invitee is not the reader: «لها» followed the reader's own
        // gender (RA-MO-276).
        'نسخنا رابط جديد، أرسليه له. القديم ما عاد يشتغل.',
      ),
    );
  }

  /// J2-13: an ended or refused invite gets a new one, on the same person.
  Future<void> _inviteAgain(PlanInvite invite) async {
    await showAddParticipantSheet(
      context,
      weddingPlanId: widget.weddingPlanId,
      preset: ParticipantPreset.ofRole(invite.role) ?? ParticipantPreset.helper,
      contact: ContactPhoneDraft.fromInput(
        name: invite.name?.trim() ?? '',
        rawPhone: invite.phone ?? '',
        requireYemeni: true,
      ),
    );
    if (mounted) _syncPendingInviteRefreshTimer();
  }

  Future<void> _confirmCancel(PlanInvite invite) async {
    final cancel = await showJourneySheet<bool>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title: '${context.say('تلغي', 'تلغين')} دعوة ${_inviteName(invite)}؟',
        subtitle: context.say(
          'الرابط اللي عنده ما عاد يشتغل، وتقدر تدعوه من جديد.',
          'الرابط اللي عنده ما عاد يشتغل، وتقدرين تدعينه من جديد.',
        ),
        children: [
          JourneyButton(
            key: ValueKey('pending-invite-cancel-${invite.id}'),
            label: context.say('ألغِ الدعوة', 'ألغي الدعوة'),
            background: AarastV3Color.danger,
            large: true,
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: AarastV3Space.x1),
          JourneyTextAction(
            label: 'رجوع',
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    );
    if (cancel != true || !mounted) return;
    final cancelled = await context.read<SharingProvider>().cancelInvite(
      invite,
    );
    if (cancelled && mounted) {
      AarastToast.showSuccess(context, 'لغينا الدعوة.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SharingProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncPendingInviteRefreshTimer();
    });
    final pending = provider.invites
        .where(
          (invite) =>
              invite.weddingPlanId == widget.weddingPlanId && invite.isPending,
        )
        .toList();
    final ready =
        !_isCheckingSharingAccess &&
        !_showLoginGate &&
        !_showPermissionGate &&
        !_showAccessError &&
        provider.authGateKind == null;

    final header = JourneySubHeader(
      title: 'المشاركين',
      subtitle: ready && pending.isNotEmpty
          ? 'مين معك، ومين لسا'
          : 'مين يساعدك في عرسك',
      onBack: () =>
          context.canPop() ? context.pop() : context.go(AppRouter.more),
      trailing: ready
          ? JourneyRoundButton(
              icon: LucideIcons.history,
              tooltip: 'وش سوّى المشاركين',
              onPressed: () => context.push(
                AppRouter.contributionHistory(widget.weddingPlanId),
              ),
            )
          : null,
    );
    final gate = _authGate(provider);
    if (gate != null) {
      // The sign-in panel scrolls on its own, under the header.
      return AarastScreenFrame(
        maxWidth: 520,
        backgroundColor: AarastV3Color.canvas,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AarastV3Space.x4,
                AarastV3Space.x2,
                AarastV3Space.x4,
                0,
              ),
              child: header,
            ),
            Expanded(child: gate),
          ],
        ),
      );
    }

    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: context.accent.primary,
        onRefresh: () => _refreshSharingAccessAndLoad(
          showPageLoader: false,
          preserveCurrentState: true,
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AarastV3Density.pageInsets,
          children: [header, ..._body(provider, pending)],
        ),
      ),
    );
  }

  Widget? _authGate(SharingProvider provider) {
    if (_isCheckingSharingAccess) return null;
    if (_showLoginGate) {
      return const AuthGatePanel(
        title: AuthActionGuard.sharingLoginGateTitle,
        body: AuthActionGuard.sharingLoginGateBody,
        icon: LucideIcons.userPlus,
      );
    }
    if (provider.authGateKind == SharingAuthGateKind.sessionExpired) {
      return const AuthGatePanel(
        title: AuthActionGuard.sessionExpiredTitle,
        body: AuthActionGuard.sharingSessionExpiredBody,
        icon: LucideIcons.fileClock,
      );
    }
    return null;
  }

  List<Widget> _body(SharingProvider provider, List<PlanInvite> pending) {
    if (_isCheckingSharingAccess) {
      return const [
        JourneyListState(
          phase: JourneyListPhase.loading,
          section: JourneySection.home,
        ),
      ];
    }
    if (_showAccessError) {
      return [
        JourneyListState(
          phase: JourneyListPhase.error,
          section: JourneySection.home,
          onRetry: _refreshSharingAccessAndLoad,
        ),
      ];
    }
    if (_showPermissionGate) {
      return [
        JourneyListState(
          phase: JourneyListPhase.empty,
          section: JourneySection.home,
          emptyIcon: LucideIcons.lock,
          emptyTitle: 'المشاركين يديرهم صاحب الخطة',
          emptyMessage: context.planWord(
            'العريس هو اللي يضيفهم ويحدد ايش يشوف كل واحد.',
            'العروسة هي اللي تضيفهم وتحدد ايش يشوف كل واحد.',
          ),
        ),
      ];
    }
    final members = provider.members
        .where((member) => !member.isOwner)
        .toList();
    // J2-13: an invite that ended, was refused or cancelled stays in sight,
    // in a small group under the waiting ones.
    final closed = provider.invites
        .where(
          (invite) =>
              invite.weddingPlanId == widget.weddingPlanId &&
              _closedInviteWord(invite.status) != null,
        )
        .toList();
    if (provider.isLoading && members.isEmpty) {
      return const [
        JourneyListState(
          phase: JourneyListPhase.loading,
          section: JourneySection.home,
        ),
      ];
    }
    if (provider.errorMessage != null &&
        provider.members.isEmpty &&
        provider.invites.isEmpty) {
      return [
        JourneyListState(
          phase: JourneyListPhase.error,
          section: JourneySection.home,
          onRetry: () => provider.loadMembers(widget.weddingPlanId),
        ),
      ];
    }

    return [
      if (provider.isStale && provider.errorMessage == null) ...[
        // D87: an old copy; inviting and permissions need the server.
        JourneyListNotice(
          offline: true,
          onRetry: () => provider.loadMembers(widget.weddingPlanId),
        ),
        const SizedBox(height: AarastV3Space.x2),
      ],
      if (provider.errorMessage != null) ...[
        JourneyNote(
          key: const ValueKey('sharing-error'),
          icon: LucideIcons.alertCircle,
          color: AarastV3Color.danger,
          soft: AarastV3Color.dangerSoft,
          text: provider.errorMessage!,
        ),
        const SizedBox(height: AarastV3Space.x2),
      ],
      if (members.isNotEmpty)
        JourneyList(
          children: [
            for (var i = 0; i < members.length; i++)
              _MemberRow(
                member: members[i],
                color: JourneyAvatar.paletteAt(context, i),
                withTag: pending.isNotEmpty,
                onTap: () {
                  provider.selectMember(members[i]);
                  context.push(
                    AppRouter.editSharedMember(
                      widget.weddingPlanId,
                      members[i].id,
                    ),
                  );
                },
              ),
          ],
        ),
      if (pending.isNotEmpty) ...[
        const JourneySectionTitle('ينتظرون'),
        JourneyList(
          children: [
            for (var i = 0; i < pending.length; i++)
              _PendingInviteRow(
                invite: pending[i],
                color: JourneyAvatar.paletteAt(context, members.length + i),
                busy: provider.isSubmitting,
                onReissue: () => _reissueInvite(pending[i]),
                onTap: () => _confirmCancel(pending[i]),
              ),
          ],
        ),
      ],
      if (closed.isNotEmpty) ...[
        const JourneySectionTitle('ما اكتملت'),
        JourneyList(
          children: [
            for (final invite in closed)
              _ClosedInviteRow(
                invite: invite,
                onInviteAgain:
                    provider.isSubmitting || !_canInviteAgain(invite.status)
                    ? null
                    : () => _inviteAgain(invite),
                showAction: _canInviteAgain(invite.status),
              ),
          ],
        ),
      ],
      if (members.isEmpty && pending.isEmpty)
        JourneyListState(
          phase: JourneyListPhase.empty,
          section: JourneySection.home,
          emptyIcon: LucideIcons.users,
          emptyTitle: context.say('لسا ما أضفت أحد', 'لسا ما أضفتِ أحد'),
          emptyMessage: context.say(
            'اختر له دور من تحت، ويوصله رابط على واتساب.',
            'اختاري له دور من تحت، ويوصله رابط على واتساب.',
          ),
        ),
      const SizedBox(height: AarastV3Space.x2),
      JourneyNote(
        key: const ValueKey('sharing-note'),
        text: pending.isNotEmpty
            ? 'الرابط يشتغل 7 أيام من يوم الدعوة. '
                  '${context.say('لما ترسل', 'لما ترسلين')} له رابط جديد، '
                  'القديم ما عاد يشتغل.'
            : participantReadingNote(context),
      ),
      JourneySectionTitle(
        context.say('أضف مشارك', 'أضيفي مشارك'),
        action: ContactPickerService.isAvailable ? 'من جهات الاتصال' : null,
        onAction: ContactPickerService.isAvailable ? _addFromContacts : null,
      ),
      for (final preset in ParticipantPreset.values)
        Padding(
          padding: const EdgeInsets.only(bottom: AarastV3Space.x2),
          child: _PresetCard(
            preset: preset,
            onTap: provider.isSubmitting ? null : () => _openAdd(preset),
          ),
        ),
    ];
  }
}

String _letter(String? name) {
  final value = name?.trim() ?? '';
  return value.isEmpty ? 'م' : value.characters.first;
}

String _inviteName(PlanInvite invite) {
  final name = invite.name?.trim();
  if (name != null && name.isNotEmpty) return name;
  final phone = participantPhone(invite.phone);
  return phone == null ? 'المدعو' : PhoneNumberUtils.isolateLtr(phone);
}

/// A participant's name, or the number laid out left to right.
class _Name extends StatelessWidget {
  const _Name({required this.name, required this.phone});

  final String? name;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final style = JourneyType.of(JourneyType.body, weight: JourneyType.bold);
    final value = name?.trim();
    if (value != null && value.isNotEmpty) {
      return Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return Text(
      participantPhone(phone) ?? 'مشارك',
      textDirection: TextDirection.ltr,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.color,
    required this.withTag,
    required this.onTap,
  });

  final SharedMember member;
  final Color color;

  /// x07: next to people still waiting, the ones with you say «معك».
  final bool withTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = member.user?.name;
    final summary = participantSummary(member.toPermissions());
    return AarastPressable(
      key: ValueKey('sharing-member-${member.id}'),
      onTap: onTap,
      semanticLabel:
          '${member.displayName}، ${participantRoleLabel(member.role)}، '
          '$summary',
      child: Padding(
        padding: const EdgeInsets.all(AarastV3Space.x3),
        child: Row(
          children: [
            JourneyAvatar(letter: _letter(name), color: color, size: 42),
            const SizedBox(width: AarastV3Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: _Name(name: name, phone: member.user?.phone),
                      ),
                      const SizedBox(width: AarastV3Space.x2),
                      Text(
                        participantRoleLabel(member.role),
                        style: JourneyType.of(
                          JourneyType.small,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    summary,
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AarastV3Space.x2),
            if (withTag)
              const JourneyTag(
                label: 'معك',
                color: AarastV3Color.mint,
                soft: AarastV3Color.mintSoft,
              )
            else
              const Icon(
                LucideIcons.chevronLeft,
                size: 18,
                color: AarastV3Color.textFaint,
              ),
          ],
        ),
      ),
    );
  }
}

class _PendingInviteRow extends StatefulWidget {
  const _PendingInviteRow({
    required this.invite,
    required this.color,
    required this.busy,
    required this.onReissue,
    required this.onTap,
  });

  final PlanInvite invite;
  final Color color;
  final bool busy;
  final VoidCallback onReissue;
  final VoidCallback onTap;

  @override
  State<_PendingInviteRow> createState() => _PendingInviteRowState();
}

class _PendingInviteRowState extends State<_PendingInviteRow> {
  Timer? _retryTimer;
  bool _retryUnlocked = false;

  @override
  void initState() {
    super.initState();
    _scheduleRetryUnlock();
  }

  @override
  void didUpdateWidget(covariant _PendingInviteRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.invite.deliveryRetryAvailableAt !=
        widget.invite.deliveryRetryAvailableAt) {
      _scheduleRetryUnlock();
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _scheduleRetryUnlock() {
    _retryTimer?.cancel();
    final remaining = widget.invite.deliveryRetryRemaining;
    _retryUnlocked = remaining == Duration.zero;
    if (_retryUnlocked) return;
    _retryTimer = Timer(remaining + const Duration(milliseconds: 50), () {
      if (mounted) setState(() => _retryUnlocked = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    final canRetry =
        !widget.busy && (_retryUnlocked || invite.canRetryDelivery);
    // Delivered or on its way: remind on WhatsApp. Otherwise the owner
    // sends the link himself.
    final remind = invite.wasDeliveredByAarast || invite.hasPendingDelivery;
    return AarastPressable(
      key: ValueKey('pending-invite-${invite.id}'),
      onTap: widget.onTap,
      semanticLabel:
          '${_inviteName(invite)}، ${_deliveryLine(invite, context.journeyProfile)}',
      child: Padding(
        padding: const EdgeInsets.all(AarastV3Space.x3),
        child: Row(
          children: [
            JourneyAvatar(
              letter: _letter(invite.name),
              color: widget.color,
              size: 42,
            ),
            const SizedBox(width: AarastV3Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Name(name: invite.name, phone: invite.phone),
                  Text(
                    _deliveryLine(invite, context.journeyProfile),
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AarastV3Space.x2),
            // Large text wraps the action instead of pushing the row off.
            // x07 draws a small pill; while the server asks to wait it
            // rests faded instead of turning into a grey button.
            Flexible(
              child: Opacity(
                opacity: canRetry ? 1 : 0.5,
                child: AarastPressable(
                  key: ValueKey('pending-invite-reissue-${invite.id}'),
                  onTap: canRetry ? widget.onReissue : null,
                  borderRadius: BorderRadius.circular(AarastV3Radius.surface),
                  semanticLabel: remind
                      ? context.say('ذكّره', 'ذكّريه')
                      : context.say('انسخ الرابط', 'انسخي الرابط'),
                  // The small pill keeps its look in a 48 target, so a near
                  // miss does not land on the row's cancel sheet.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AarastV3Space.x12,
                    ),
                    child: Align(
                      widthFactor: 1,
                      child: Container(
                        padding: AarastV3Density.tagInsets,
                        decoration: BoxDecoration(
                          color: remind
                              ? context.accent.primarySoft
                              : AarastV3Color.brandAccentSoft,
                          borderRadius: BorderRadius.circular(
                            AarastV3Radius.surface,
                          ),
                        ),
                        child: Text(
                          remind
                              ? context.say('ذكّره', 'ذكّريه')
                              : context.say('انسخ الرابط', 'انسخي الرابط'),
                          style: JourneyType.of(
                            JourneyType.small,
                            weight: JourneyType.bold,
                            color: remind
                                ? context.accent.primary
                                : AarastV3Color.brandAccentStrong,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where the invite stands, from the server's delivery record. Whether it
/// was opened is not known, so it is not said.
String _deliveryLine(PlanInvite invite, JourneyProfile profile) {
  final send = profile.say(
    'أرسل له الرابط بأي طريقة',
    'أرسلي له الرابط بأي طريقة',
  );
  return switch (invite.deliveryStatus) {
    'DELIVERED' => 'الدعوة وصلت ${_dayWord(invite.deliveryAttemptedAt)}',
    'PENDING' => 'نرسل له الدعوة على واتساب',
    'UNCERTAIN' => 'ما تأكدنا إنها وصلت · $send',
    'UNAVAILABLE' => 'ما وصلته على واتساب · $send',
    _ => 'الدعوة محفوظة · $send',
  };
}

String _dayWord(DateTime? at) {
  if (at == null) return 'على واتساب';
  final local = at.toLocal();
  final now = appNow();
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return 'اليوم';
  if (days == 1) return 'أمس';
  return formatArabicDayMonth(local);
}

/// J2-13: the state word of an invite that is no longer waiting; null for
/// a waiting or an accepted one.
String? _closedInviteWord(String status) => switch (status) {
  'EXPIRED' => 'انتهت',
  // The invite, like its two neighbours: «رفض» said the invitee is a man.
  'DECLINED' => 'رُفضت',
  'CANCELLED' => 'أُلغيت',
  _ => null,
};

/// A cancelled invite was the owner's own choice; an ended or refused one
/// may be sent again.
bool _canInviteAgain(String status) =>
    status == 'EXPIRED' || status == 'DECLINED';

/// One closed invite: the name, its state word, and «أرسل دعوة جديدة» when
/// it ended or was refused. Quiet, so the list stays calm.
class _ClosedInviteRow extends StatelessWidget {
  const _ClosedInviteRow({
    required this.invite,
    required this.onInviteAgain,
    required this.showAction,
  });

  final PlanInvite invite;
  final VoidCallback? onInviteAgain;
  final bool showAction;

  @override
  Widget build(BuildContext context) {
    final word = _closedInviteWord(invite.status) ?? '';
    return Padding(
      key: ValueKey('closed-invite-${invite.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: AarastV3Space.x3,
        vertical: AarastV3Space.x1,
      ),
      child: Row(
        children: [
          Expanded(
            child: Opacity(
              opacity: 0.7,
              child: _Name(name: invite.name, phone: invite.phone),
            ),
          ),
          const SizedBox(width: AarastV3Space.x2),
          JourneyTag(
            label: word,
            color: AarastV3Color.textMuted,
            soft: AarastV3Color.canvas,
          ),
          if (showAction) ...[
            const SizedBox(width: AarastV3Space.x1),
            JourneyTextAction(
              key: ValueKey('closed-invite-resend-${invite.id}'),
              label: context.say('أرسل دعوة جديدة', 'أرسلي دعوة جديدة'),
              color: context.accent.primary,
              onPressed: onInviteAgain,
            ),
          ],
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({required this.preset, required this.onTap});

  final ParticipantPreset preset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (preset) {
      ParticipantPreset.helper => LucideIcons.listChecks,
      ParticipantPreset.family => LucideIcons.users,
      ParticipantPreset.viewer => LucideIcons.eye,
    };
    return AarastPressable(
      key: ValueKey('sharing-preset-${preset.role}'),
      onTap: onTap,
      semanticLabel:
          '${context.say('أضف', 'أضيفي')} ${preset.label}، ${preset.description}',
      borderRadius: BorderRadius.circular(AarastV3Radius.card),
      child: JourneyBox(
        radius: 18,
        padding: const EdgeInsets.all(AarastV3Space.x3),
        child: Row(
          children: [
            Icon(icon, size: 20, color: context.accent.primary),
            const SizedBox(width: AarastV3Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.label,
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                    ),
                  ),
                  Text(
                    preset.description,
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
