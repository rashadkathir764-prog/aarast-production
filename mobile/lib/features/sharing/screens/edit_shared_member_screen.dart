import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthActionGuard, AuthGatePanel;
import '../models/participant_access.dart';
import '../models/plan_role_permissions.dart';
import '../models/shared_member.dart';
import '../providers/sharing_provider.dart';
import '../widgets/participant_access_editor.dart';

/// A participant from g01: the same ready roles and section levels as adding
/// one (g06), saved as one complete permission snapshot, and taking them off
/// the plan. Flags the levels do not show (editing the plan, inviting) keep
/// their stored value.
class EditSharedMemberScreen extends StatefulWidget {
  const EditSharedMemberScreen({required this.sharedMemberId, super.key});

  final String sharedMemberId;

  @override
  State<EditSharedMemberScreen> createState() => _EditSharedMemberScreenState();
}

class _EditSharedMemberScreenState extends State<EditSharedMemberScreen> {
  String _role = 'VIEWER';
  PlanRolePermissions _permissions = PlanRolePermissions.forRole('VIEWER');
  bool _initialized = false;
  bool _isCheckingAccess = true;
  bool _showPermissionGate = false;
  bool _showLoadError = false;
  bool _showMissingMember = false;
  SharedMember? _verifiedMember;
  String? _memberPlanId;
  int _refreshGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshMemberAccess();
    });
  }

  @override
  void didUpdateWidget(covariant EditSharedMemberScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sharedMemberId == widget.sharedMemberId) return;
    _memberPlanId = null;
    _verifiedMember = null;
    _initialized = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshMemberAccess();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SharingProvider>();
    final member = _verifiedMember;
    if (member != null && !_initialized) _syncFromMember(member);
    final name = member?.user?.name.trim();
    // Isolated so the digit groups keep their order inside Arabic text.
    final localPhone = participantPhone(member?.user?.phone);
    final phone = localPhone == null
        ? null
        : PhoneNumberUtils.isolateLtr(localPhone);
    final hasName = name != null && name.isNotEmpty;

    final header = JourneySubHeader(
      title: member == null
          ? 'المشارك'
          : hasName
          ? name
          : (phone ?? 'المشارك'),
      subtitle: member == null
          ? null
          : hasName && phone != null
          ? '${participantRoleLabel(member.role)} · $phone'
          : participantRoleLabel(member.role),
      onBack: _leave,
    );
    if (!_isCheckingAccess &&
        provider.authGateKind == SharingAuthGateKind.sessionExpired) {
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
            const Expanded(
              child: AuthGatePanel(
                title: AuthActionGuard.sessionExpiredTitle,
                body: AuthActionGuard.sharingSessionExpiredBody,
                icon: LucideIcons.fileClock,
              ),
            ),
          ],
        ),
      );
    }
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        padding: AarastV3Density.pageInsets,
        children: [header, ..._body(provider, member)],
      ),
    );
  }

  List<Widget> _body(SharingProvider provider, SharedMember? member) {
    if (_isCheckingAccess) {
      return const [
        JourneyListState(
          phase: JourneyListPhase.loading,
          section: JourneySection.home,
        ),
      ];
    }
    if (_showLoadError) {
      return [
        JourneyListState(
          phase: JourneyListPhase.error,
          section: JourneySection.home,
          onRetry: _refreshMemberAccess,
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
          emptyMessage: 'هو اللي يغيّر ايش يشوف كل واحد أو يشيله.',
        ),
      ];
    }
    if (_showMissingMember || member == null) {
      return const [
        JourneyListState(
          phase: JourneyListPhase.empty,
          section: JourneySection.home,
          emptyIcon: LucideIcons.users,
          emptyTitle: 'ما لقينا هذا المشارك',
          emptyMessage: 'يمكن طلع من الخطة. افتحه من «المشاركين».',
        ),
      ];
    }

    return [
      ParticipantAccessEditor(
        role: _role,
        permissions: _permissions,
        enabled: !provider.isSubmitting,
        onPresetSelected: (preset) => setState(() {
          _role = preset.role;
          _permissions = preset.permissions;
        }),
        onChanged: (value) => setState(() => _permissions = value),
      ),
      if (provider.errorMessage != null) ...[
        const SizedBox(height: AarastV3Space.x2),
        JourneyNote(
          key: const ValueKey('member-error'),
          icon: LucideIcons.alertCircle,
          color: AarastV3Color.danger,
          soft: AarastV3Color.dangerSoft,
          text: provider.errorMessage!,
        ),
      ],
      const SizedBox(height: AarastV3Space.x3),
      JourneyButton(
        key: const ValueKey('member-save'),
        label: context.say('احفظ', 'احفظي'),
        large: true,
        expand: true,
        loading: provider.isSubmitting,
        onPressed: provider.isSubmitting ? null : () => _save(member),
      ),
      const SizedBox(height: AarastV3Space.x1),
      Center(
        child: JourneyTextAction(
          key: const ValueKey('member-remove'),
          label: context.say('شيله من الخطة', 'شيليه من الخطة'),
          icon: LucideIcons.userMinus,
          color: AarastV3Color.danger,
          onPressed: provider.isSubmitting
              ? null
              : () => _confirmRemove(member),
        ),
      ),
    ];
  }

  void _leave() {
    final planId = _memberPlanId;
    if (context.canPop()) {
      context.pop();
    } else if (planId != null) {
      context.go(AppRouter.sharing(planId));
    } else {
      context.go(AppRouter.more);
    }
  }

  Future<void> _refreshMemberAccess() async {
    final generation = ++_refreshGeneration;
    final provider = context.read<SharingProvider>();
    final selected = provider.selectedMember;
    final candidate = selected?.id == widget.sharedMemberId
        ? selected
        : provider.findMember(widget.sharedMemberId);
    final weddingPlanId = _memberPlanId ?? candidate?.weddingPlanId;

    setState(() {
      _isCheckingAccess = true;
      _showPermissionGate = false;
      _showLoadError = false;
      _showMissingMember = false;
      _verifiedMember = null;
    });

    if (weddingPlanId == null || weddingPlanId.isEmpty) {
      if (!_isCurrentRefresh(generation)) return;
      setState(() {
        _isCheckingAccess = false;
        _showMissingMember = true;
      });
      return;
    }
    _memberPlanId = weddingPlanId;

    final accessLoaded = await provider.loadAccess(weddingPlanId);
    if (!_isCurrentRefresh(generation)) return;
    if (!accessLoaded) {
      setState(() {
        _isCheckingAccess = false;
        _showLoadError = provider.authGateKind == null;
      });
      return;
    }

    final access = provider.access;
    if (access.weddingPlanId != weddingPlanId) {
      setState(() {
        _isCheckingAccess = false;
        _showLoadError = true;
      });
      return;
    }
    if (!access.canManageMembers) {
      setState(() {
        _isCheckingAccess = false;
        _showPermissionGate = true;
      });
      return;
    }

    await provider.loadMembers(weddingPlanId);
    if (!_isCurrentRefresh(generation)) return;
    if (provider.authGateKind != null || provider.errorMessage != null) {
      setState(() {
        _isCheckingAccess = false;
        _showLoadError = provider.authGateKind == null;
      });
      return;
    }

    final refreshed = provider.findMember(widget.sharedMemberId);
    setState(() {
      _isCheckingAccess = false;
      _showMissingMember = refreshed == null;
      _verifiedMember = refreshed;
      _initialized = false;
    });
  }

  bool _isCurrentRefresh(int generation) {
    return mounted && generation == _refreshGeneration;
  }

  void _syncFromMember(SharedMember member) {
    _role = member.role;
    _permissions = member.toPermissions();
    _initialized = true;
  }

  Future<void> _save(SharedMember member) async {
    final provider = context.read<SharingProvider>();
    final updated = await provider.updateMember(
      weddingPlanId: member.weddingPlanId,
      id: member.id,
      role: _role,
      permissions: _permissions,
    );
    if (!mounted || !updated) return;
    AarastToast.showSuccess(context, 'حفظنا اللي يشوفه.');
    _leave();
  }

  Future<void> _confirmRemove(SharedMember member) async {
    final name = member.user?.name.trim();
    final who = name == null || name.isEmpty
        ? member.directionalDisplayName
        : name;
    final confirmed = await showJourneySheet<bool>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title: '${context.say('تشيل', 'تشيلين')} $who من الخطة؟',
        subtitle: 'يطلع على طول، وما يقدر يفتح الخطة بعدها.',
        children: [
          JourneyButton(
            key: const ValueKey('member-remove-confirm'),
            label: context.say('شيله', 'شيليه'),
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
    if (confirmed != true || !mounted) return;
    final removed = await context.read<SharingProvider>().removeMember(
      member.weddingPlanId,
      member.id,
    );
    if (!mounted || !removed) return;
    AarastToast.showSuccess(context, 'شلناه من الخطة.');
    _leave();
  }
}
