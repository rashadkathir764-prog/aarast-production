import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_picker_service.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthActionGuard, AuthGatePanel;
import '../models/participant_access.dart';
import '../models/shared_member.dart';
import '../providers/sharing_provider.dart';
import '../widgets/add_participant_sheet.dart';
import '../widgets/invite_link_copy.dart';

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
    if (mounted) _syncPendingInviteRefreshTimer();
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
      if (mounted) _syncPendingInviteRefreshTimer();
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
      AarastToast.showSuccess(
        context,
        'وصله رابط جديد على واتساب، والقديم ما عاد يشتغل.',
      );
      return;
    }
    final copied = await copyInviteText(
      context,
      newInviteLinkMessage(reissued),
    );
    if (!mounted || !copied) return;
    AarastToast.showSuccess(
      context,
      'نسخنا رابط جديد، أرسله له. القديم ما عاد يشتغل.',
    );
  }

  Future<void> _confirmCancel(PlanInvite invite) async {
    final cancel = await showJourneySheet<bool>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title: 'تلغي دعوة ${_inviteName(invite)}؟',
        subtitle: 'الرابط اللي عنده ما عاد يشتغل، وتقدر تدعوه من جديد.',
        children: [
          JourneyButton(
            key: ValueKey('pending-invite-cancel-${invite.id}'),
            label: 'الغِ الدعوة',
            background: AarastV3Color.danger,
            large: true,
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: 6),
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
        color: AarastV3Color.primary,
        onRefresh: () => _refreshSharingAccessAndLoad(
          showPageLoader: false,
          preserveCurrentState: true,
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
      return const [
        JourneyListState(
          phase: JourneyListPhase.empty,
          section: JourneySection.home,
          emptyIcon: LucideIcons.lock,
          emptyTitle: 'المشاركين يديرهم صاحب الخطة',
          emptyMessage: 'هو اللي يضيفهم ويحدد ايش يشوف كل واحد.',
        ),
      ];
    }
    final members = provider.members
        .where((member) => !member.isOwner)
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
      if (provider.errorMessage != null) ...[
        JourneyNote(
          key: const ValueKey('sharing-error'),
          icon: LucideIcons.alertCircle,
          color: AarastV3Color.danger,
          soft: AarastV3Color.dangerSoft,
          text: provider.errorMessage!,
        ),
        const SizedBox(height: 10),
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
      if (members.isEmpty && pending.isEmpty)
        const JourneyListState(
          phase: JourneyListPhase.empty,
          section: JourneySection.home,
          emptyIcon: LucideIcons.users,
          emptyTitle: 'لسا ما أضفت أحد',
          emptyMessage: 'اختر له دور من تحت، ويوصله رابط على واتساب.',
        ),
      const SizedBox(height: 10),
      JourneyNote(
        key: const ValueKey('sharing-note'),
        text: pending.isNotEmpty
            ? 'الرابط يشتغل 7 أيام من يوم الدعوة. لما ترسل له رابط جديد، '
                  'القديم ما عاد يشتغل.'
            : 'كل مشارك يدخل برقمه، ويشوف بس الأقسام اللي تفتحها له.',
      ),
      JourneySectionTitle(
        'أضف مشارك',
        action: ContactPickerService.isAvailable ? 'من جهات الاتصال' : null,
        onAction: ContactPickerService.isAvailable ? _addFromContacts : null,
      ),
      for (final preset in ParticipantPreset.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            JourneyAvatar(letter: _letter(name), color: color, size: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: _Name(name: name, phone: member.user?.phone),
                      ),
                      const SizedBox(width: 8),
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
            const SizedBox(width: 8),
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
      semanticLabel: '${_inviteName(invite)}، ${_deliveryLine(invite)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            JourneyAvatar(
              letter: _letter(invite.name),
              color: widget.color,
              size: 42,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Name(name: invite.name, phone: invite.phone),
                  Text(
                    _deliveryLine(invite),
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Large text wraps the action instead of pushing the row off.
            // x07 draws a small pill; while the server asks to wait it
            // rests faded instead of turning into a grey button.
            Flexible(
              child: Opacity(
                opacity: canRetry ? 1 : 0.5,
                child: AarastPressable(
                  key: ValueKey('pending-invite-reissue-${invite.id}'),
                  onTap: canRetry ? widget.onReissue : null,
                  borderRadius: BorderRadius.circular(14),
                  semanticLabel: remind ? 'ذكّره' : 'انسخ الرابط',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: remind
                          ? AarastV3Color.primarySoft
                          : AarastV3Color.brandAccentSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      remind ? 'ذكّره' : 'انسخ الرابط',
                      style: JourneyType.of(
                        JourneyType.small,
                        weight: JourneyType.bold,
                        color: remind
                            ? AarastV3Color.primary
                            : AarastV3Color.brandAccentStrong,
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
String _deliveryLine(PlanInvite invite) {
  return switch (invite.deliveryStatus) {
    'DELIVERED' => 'الدعوة وصلت ${_dayWord(invite.deliveryAttemptedAt)}',
    'PENDING' => 'نرسل له الدعوة على واتساب',
    'UNCERTAIN' => 'ما تأكدنا إنها وصلت · أرسل له الرابط بأي طريقة',
    'UNAVAILABLE' => 'ما وصلته على واتساب · أرسل له الرابط بأي طريقة',
    _ => 'الدعوة محفوظة · أرسل له الرابط بأي طريقة',
  };
}

String _dayWord(DateTime? at) {
  if (at == null) return 'على واتساب';
  final local = at.toLocal();
  final now = DateTime.now();
  final day = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(day).inDays;
  if (days <= 0) return 'اليوم';
  if (days == 1) return 'أمس';
  return formatArabicDayMonth(local);
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
      semanticLabel: 'أضف ${preset.label}، ${preset.description}',
      borderRadius: BorderRadius.circular(18),
      child: JourneyBox(
        radius: 18,
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AarastV3Color.primary),
            const SizedBox(width: 12),
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
