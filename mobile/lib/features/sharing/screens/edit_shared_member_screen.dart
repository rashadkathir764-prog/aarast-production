import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../models/plan_role_permissions.dart';
import '../models/shared_member.dart';
import '../providers/sharing_provider.dart';
import '../widgets/permission_editor.dart';
import '../widgets/shared_member_card.dart';

/// الأدوار الأساسية المعروضة — نفس قائمة شاشة الإضافة. دور العضو الحالي
/// يُدرج دائمًا حتى لو كان من الأدوار الخلفية القديمة (MANAGER/CONTRIBUTOR)
/// فلا تنكسر القائمة عند فتح عضو أضيف بها.
const _baseEditRoles = ['VIEWER', 'GROOM', 'BRIDE', 'FAMILY', 'HELPER'];

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

  List<String> _rolesFor(SharedMember member) {
    if (_baseEditRoles.contains(member.role)) return _baseEditRoles;
    return [..._baseEditRoles, member.role];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SharingProvider>();

    if (_isCheckingAccess) {
      return _stateScaffold(AarastSkeleton.form(fields: 4, withButton: true));
    }

    if (provider.authGateKind == SharingAuthGateKind.sessionExpired) {
      return _stateScaffold(
        const AuthGatePanel(
          title: AuthActionGuard.sessionExpiredTitle,
          body: AuthActionGuard.sharingSessionExpiredBody,
          icon: LucideIcons.fileClock,
        ),
      );
    }

    if (_showLoadError) {
      return _stateScaffold(
        AarastErrorState(
          title: 'تعذر التحقق من صلاحية تعديل العضو',
          message:
              provider.accessErrorMessage ??
              provider.errorMessage ??
              'تحقق من الاتصال وحاول مرة أخرى.',
          onRetry: _refreshMemberAccess,
        ),
      );
    }

    if (_showPermissionGate) {
      return _stateScaffold(
        const AarastEmptyState(
          title: 'ليس لديك صلاحية إدارة المشاركين',
          message: 'تعديل الأعضاء أو حذفهم متاح للمصرح لهم فقط.',
          icon: LucideIcons.shieldAlert,
          tone: AarastEmptyStateTone.restricted,
        ),
      );
    }

    final member = _verifiedMember;

    if (_showMissingMember || member == null) {
      return _stateScaffold(
        const Center(
          child: AarastEmptyState(
            title: 'لا يمكن تعديل العضو الآن',
            message: 'افتح العضو من شاشة المشاركة حتى يمكن تعديل صلاحياته.',
            icon: LucideIcons.users,
          ),
        ),
      );
    }

    if (!_initialized) {
      _syncFromMember(member);
    }

    return AarastPageScaffold(
      title: 'تعديل عضو المشاركة',
      subtitle: 'عدّل الدور أو خصص الصلاحيات ثم احفظ.',
      showBack: true,
      child: ListView(
        children: [
          SharedMemberCard(member: member, onTap: null),
          const SizedBox(height: 6),
          SharedPermissionEditor(
            role: _role,
            roles: _rolesFor(member),
            permissions: _permissions,
            onRoleSelected: (role) => setState(() {
              _role = role;
              _permissions = PlanRolePermissions.forRole(role);
            }),
            onPermissionsChanged: (value) =>
                setState(() => _permissions = value),
            enabled: !provider.isSubmitting,
            // في التعديل الهدف غالبًا ضبط الصلاحيات — تُفتح جاهزة.
            initiallyExpanded: true,
          ),
          if (provider.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              provider.errorMessage!,
              textAlign: TextAlign.right,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 18),
          AarastButton(
            label: 'حفظ التغييرات',
            isLoading: provider.isSubmitting,
            onPressed: provider.isSubmitting ? null : () => _save(member),
          ),
          const SizedBox(height: 10),
          AarastButton(
            label: 'إزالة العضو من الخطة',
            icon: LucideIcons.trash2,
            variant: AarastButtonVariant.danger,
            onPressed: provider.isSubmitting
                ? null
                : () => _confirmRemove(member),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  AarastPageScaffold _stateScaffold(Widget child) {
    return AarastPageScaffold(
      title: 'تعديل عضو المشاركة',
      subtitle: 'عدّل الدور أو خصص الصلاحيات ثم احفظ.',
      showBack: true,
      child: child,
    );
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

    if (!mounted) {
      return;
    }

    if (updated) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRouter.sharing(member.weddingPlanId));
      }
    }
  }

  Future<void> _confirmRemove(SharedMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AarastDialog(
        title: const Text('إزالة العضو؟'),
        content: Text(
          'سيفقد "${member.directionalDisplayName}" الوصول للخطة فورًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    final provider = context.read<SharingProvider>();
    final removed = await provider.removeMember(
      member.weddingPlanId,
      member.id,
    );

    if (!mounted) {
      return;
    }

    if (removed) {
      AarastToast.showSuccess(context, 'تمت إزالة العضو من الخطة.');
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRouter.sharing(member.weddingPlanId));
      }
    }
  }
}
