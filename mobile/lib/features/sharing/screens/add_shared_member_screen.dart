import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_duplicate_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../shared/widgets/contact_phone_field.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../models/plan_role_permissions.dart';
import '../models/shared_member.dart';
import '../providers/sharing_provider.dart';
import '../widgets/permission_editor.dart';

/// أدوار الدعوة المعروضة — اختيار الدور يضبط الصلاحيات الافتراضية تلقائيًا.
const _addMemberRoles = ['VIEWER', 'GROOM', 'BRIDE', 'FAMILY', 'HELPER'];

class AddSharedMemberScreen extends StatefulWidget {
  const AddSharedMemberScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<AddSharedMemberScreen> createState() => _AddSharedMemberScreenState();
}

class _AddSharedMemberScreenState extends State<AddSharedMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String _role = 'VIEWER';
  PlanRolePermissions _permissions = PlanRolePermissions.forRole('VIEWER');
  String? _localPhoneError;
  bool _isCheckingSharingAccess = true;
  bool _showLoginGate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshSharingAccess();
    });
  }

  @override
  void didUpdateWidget(covariant AddSharedMemberScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refreshSharingAccess();
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SharingProvider>();
    final foundUser = provider.lookupUser;
    final gate = _authGateFor(provider);
    final duplicateMessage =
        _localPhoneError ??
        _duplicateMemberMessage(provider.members, provider.invites);

    return AarastPageScaffold(
      title: 'إضافة عضو',
      subtitle: 'ابحث بالرقم ثم اختر الدور — الصلاحيات تُضبط تلقائيًا.',
      resizeToAvoidBottomInset: true,
      actions: [
        IconButton(
          tooltip: 'رجوع',
          onPressed: () {
            if (context.canPop()) context.pop();
          },
          icon: const Icon(LucideIcons.chevronRight),
        ),
      ],
      child:
          gate ??
          Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ContactPhoneField(
                        phoneController: _phoneController,
                        label: 'رقم جوال العضو',
                        optional: false,
                        requireYemeni: true,
                        enabled: !provider.isLookingUp,
                        duplicateMessage: duplicateMessage,
                        onDraftChanged: (_) {
                          provider.clearLookup();
                          setState(() => _localPhoneError = null);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _LookupButton(
                        isLookingUp: provider.isLookingUp,
                        onTap: _lookupUser,
                      ),
                    ),
                  ],
                ),
                if (foundUser != null) ...[
                  const SizedBox(height: 4),
                  _FoundUserStrip(user: foundUser),
                ] else if (provider.lookupErrorMessage != null) ...[
                  const SizedBox(height: 4),
                  _LookupEmpty(message: provider.lookupErrorMessage!),
                ],
                const SizedBox(height: 16),
                SharedPermissionEditor(
                  role: _role,
                  roles: _addMemberRoles,
                  permissions: _permissions,
                  onRoleSelected: _applyRole,
                  onPermissionsChanged: (value) =>
                      setState(() => _permissions = value),
                  enabled: !provider.isSubmitting,
                ),
                if (provider.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _InlineError(message: provider.errorMessage!),
                ],
                const SizedBox(height: 18),
                AarastButton(
                  label: 'إرسال دعوة المشاركة',
                  icon: LucideIcons.userPlus,
                  isLoading: provider.isSubmitting,
                  onPressed: provider.isSubmitting ? null : _submit,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  Future<void> _lookupUser() async {
    if (await _refreshSharingAccess()) return;
    if (!mounted) return;
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<SharingProvider>();
    final duplicateMessage = _duplicateMemberMessage(
      provider.members,
      provider.invites,
    );
    if (duplicateMessage != null) {
      setState(() => _localPhoneError = duplicateMessage);
      return;
    }
    await provider.lookupUserByPhone(
      widget.weddingPlanId,
      _phoneController.text,
    );
    if (!mounted) return;
    final foundUserId = provider.lookupUser?.id;
    if (foundUserId != null &&
        provider.members.any((member) => member.userId == foundUserId)) {
      provider.clearLookup();
      setState(() => _localPhoneError = 'هذا الرقم مضاف مسبقًا.');
    }
  }

  Future<void> _submit() async {
    if (await _refreshSharingAccess()) return;
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;

    final provider = context.read<SharingProvider>();
    final duplicateMessage = _duplicateMemberMessage(
      provider.members,
      provider.invites,
    );
    if (duplicateMessage != null) {
      setState(() => _localPhoneError = duplicateMessage);
      return;
    }
    final created = await provider.createInvite(
      weddingPlanId: widget.weddingPlanId,
      phone: _phoneController.text,
      name: provider.lookupUser?.name,
      role: _role,
      canViewBudget: _permissions.canViewBudget,
      canViewExpenses: _permissions.canViewExpenses,
      canViewDebts: _permissions.canViewDebts,
      canEditPlan: _permissions.canEditPlan,
      canManageTasks: _permissions.canManageTasks,
      canManageGuests: _permissions.canManageGuests,
      canManageProviders: _permissions.canManageProviders,
      canInviteMembers: _permissions.canInviteMembers,
      canManageFinancialRecords: _permissions.canManageFinancialRecords,
      receiveNotifications: _permissions.receiveNotifications,
    );

    if (!mounted) return;

    if (created) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRouter.sharing(widget.weddingPlanId));
      }
    }
  }

  void _applyRole(String role) {
    setState(() {
      _role = role;
      _permissions = PlanRolePermissions.forRole(role);
    });
  }

  Future<bool> _refreshSharingAccess() async {
    setState(() {
      _isCheckingSharingAccess = true;
      _showLoginGate = false;
    });

    final shouldGate = await AuthActionGuard.shouldGateProtectedSharing(
      context,
      weddingPlanId: widget.weddingPlanId,
    );
    if (!mounted) return true;

    setState(() {
      _isCheckingSharingAccess = false;
      _showLoginGate = shouldGate;
    });
    return shouldGate;
  }

  Widget? _authGateFor(SharingProvider provider) {
    if (_isCheckingSharingAccess) {
      return AarastSkeleton.form(fields: 3, withButton: true);
    }

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

  String? _duplicateMemberMessage(
    List<SharedMember> members,
    List<PlanInvite> invites,
  ) {
    final duplicate = ContactDuplicateUtils.findByPhone(
      members,
      candidatePhone: _phoneController.text,
      phoneOf: (member) => member.user?.phone,
    );
    if (duplicate != null) return 'هذا الرقم مضاف مسبقًا.';
    final pendingInvite = ContactDuplicateUtils.findByPhone(
      invites.where((invite) => invite.isPending),
      candidatePhone: _phoneController.text,
      phoneOf: (invite) => invite.phone,
    );
    return pendingInvite == null ? null : 'توجد دعوة معلقة لهذا الرقم.';
  }
}

/// زر البحث الملاصق لحقل الرقم — بديل الزر العريض المستقل.
class _LookupButton extends StatelessWidget {
  const _LookupButton({required this.isLookingUp, required this.onTap});

  final bool isLookingUp;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'بحث عن المستخدم',
      child: Material(
        color: AppTheme.burgundy,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: isLookingUp ? null : onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Center(
              child: isLookingUp
                  ? const AarastInlineSpinner(
                      dimension: 18,
                      color: Colors.white,
                    )
                  : const Icon(
                      LucideIcons.search,
                      size: 20,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FoundUserStrip extends StatelessWidget {
  const _FoundUserStrip({required this.user});

  final SharedUserLookup user;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final phone = user.phone?.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.successBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.successSoft),
      ),
      child: Row(
        children: [
          _LookupAvatar(user: user),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name.trim().isEmpty ? 'عضو أعرست' : user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (phone != null && phone.isNotEmpty)
                  Text(
                    phone,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const AarastStatusPill(
            label: 'مستخدم مسجل',
            icon: LucideIcons.badgeCheck,
            color: AppTheme.success,
            backgroundColor: AppTheme.ivory,
          ),
        ],
      ),
    );
  }
}

class _LookupAvatar extends StatelessWidget {
  const _LookupAvatar({required this.user});

  final SharedUserLookup user;

  @override
  Widget build(BuildContext context) {
    final imageUrl = user.avatarUrl?.trim();
    final initial = user.name.trim().isEmpty ? 'ع' : user.name.trim()[0];

    Widget fallback = Center(
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppTheme.burgundy,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return ClipOval(
      child: Container(
        width: 40,
        height: 40,
        color: AppTheme.surface,
        child: imageUrl == null || imageUrl.isEmpty
            ? fallback
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
      ),
    );
  }
}

class _LookupEmpty extends StatelessWidget {
  const _LookupEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.ivory,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.gold.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.info, color: AppTheme.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.burgundySoft,
      border: Border.all(color: AppTheme.dangerSoft),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.danger,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
