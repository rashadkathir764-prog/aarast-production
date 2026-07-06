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
import '../models/shared_member.dart';
import '../models/plan_role_permissions.dart';
import '../providers/sharing_provider.dart';

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
  bool _canViewBudget = false;
  bool _canViewExpenses = false;
  bool _canViewDebts = false;
  bool _canEditPlan = false;
  bool _canManageTasks = false;
  bool _canManageGuests = false;
  bool _canManageProviders = false;
  bool _canInviteMembers = false;
  bool _canManageFinancialRecords = false;
  bool _receiveNotifications = true;
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

    return AarastPageScaffold(
      title: 'إضافة عضو',
      subtitle: 'ابحث برقم الهاتف ثم حدد الصلاحيات قبل المشاركة.',
      resizeToAvoidBottomInset: true,
      actions: [
        IconButton(
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
                const _PrivacyHint(),
                const SizedBox(height: 14),
                _PhoneLookupCard(
                  controller: _phoneController,
                  isLookingUp: provider.isLookingUp,
                  errorMessage: provider.lookupErrorMessage,
                  duplicateMessage:
                      _localPhoneError ??
                      _duplicateMemberMessage(
                        provider.members,
                        provider.invites,
                      ),
                  foundUser: foundUser,
                  onChanged: (_) {
                    provider.clearLookup();
                    setState(() => _localPhoneError = null);
                  },
                  onLookup: _lookupUser,
                ),
                const SizedBox(height: 14),
                _RoleDropdown(value: _role, onChanged: _applyRole),
                const SizedBox(height: 14),
                _PermissionSwitches(
                  canViewBudget: _canViewBudget,
                  canViewExpenses: _canViewExpenses,
                  canViewDebts: _canViewDebts,
                  canEditPlan: _canEditPlan,
                  canManageTasks: _canManageTasks,
                  canManageGuests: _canManageGuests,
                  canManageProviders: _canManageProviders,
                  canInviteMembers: _canInviteMembers,
                  canManageFinancialRecords: _canManageFinancialRecords,
                  receiveNotifications: _receiveNotifications,
                  onViewBudgetChanged: (value) =>
                      setState(() => _canViewBudget = value),
                  onViewExpensesChanged: (value) =>
                      setState(() => _canViewExpenses = value),
                  onViewDebtsChanged: (value) =>
                      setState(() => _canViewDebts = value),
                  onEditPlanChanged: (value) =>
                      setState(() => _canEditPlan = value),
                  onManageTasksChanged: (value) =>
                      setState(() => _canManageTasks = value),
                  onManageGuestsChanged: (value) =>
                      setState(() => _canManageGuests = value),
                  onManageProvidersChanged: (value) =>
                      setState(() => _canManageProviders = value),
                  onInviteMembersChanged: (value) =>
                      setState(() => _canInviteMembers = value),
                  onManageFinancialRecordsChanged: (value) =>
                      setState(() => _canManageFinancialRecords = value),
                  onReceiveNotificationsChanged: (value) =>
                      setState(() => _receiveNotifications = value),
                ),
                if (provider.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _InlineError(message: provider.errorMessage!),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: provider.isSubmitting ? null : _submit,
                  icon: provider.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.userPlus),
                  label: const Text('إرسال دعوة المشاركة'),
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
    await provider.lookupUserByPhone(_phoneController.text);
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
      canViewBudget: _canViewBudget,
      canViewExpenses: _canViewExpenses,
      canViewDebts: _canViewDebts,
      canEditPlan: _canEditPlan,
      canManageTasks: _canManageTasks,
      canManageGuests: _canManageGuests,
      canManageProviders: _canManageProviders,
      canInviteMembers: _canInviteMembers,
      canManageFinancialRecords: _canManageFinancialRecords,
      receiveNotifications: _receiveNotifications,
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
    final defaults = PlanRolePermissions.forRole(role);
    setState(() {
      _role = role;
      _canViewBudget = defaults.canViewBudget;
      _canViewExpenses = defaults.canViewExpenses;
      _canViewDebts = defaults.canViewDebts;
      _canEditPlan = defaults.canEditPlan;
      _canManageTasks = defaults.canManageTasks;
      _canManageGuests = defaults.canManageGuests;
      _canManageProviders = defaults.canManageProviders;
      _canInviteMembers = defaults.canInviteMembers;
      _canManageFinancialRecords = defaults.canManageFinancialRecords;
      _receiveNotifications = defaults.receiveNotifications;
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
      return const Center(child: CircularProgressIndicator());
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

class _PhoneLookupCard extends StatelessWidget {
  const _PhoneLookupCard({
    required this.controller,
    required this.isLookingUp,
    required this.onChanged,
    required this.onLookup,
    this.errorMessage,
    this.duplicateMessage,
    this.foundUser,
  });

  final TextEditingController controller;
  final bool isLookingUp;
  final String? errorMessage;
  final String? duplicateMessage;
  final SharedUserLookup? foundUser;
  final ValueChanged<String> onChanged;
  final VoidCallback onLookup;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(
            title: 'البحث عن العضو',
            icon: LucideIcons.smartphone,
          ),
          const SizedBox(height: 14),
          ContactPhoneField(
            phoneController: controller,
            label: 'رقم جوال العضو',
            optional: false,
            requireYemeni: true,
            enabled: !isLookingUp,
            duplicateMessage: duplicateMessage,
            onDraftChanged: (draft) =>
                onChanged(draft.normalizedPhone ?? draft.rawPhone),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isLookingUp ? null : onLookup,
            icon: const Icon(LucideIcons.search),
            label: const Text('بحث عن المستخدم'),
          ),
          if (foundUser != null) ...[
            const SizedBox(height: 14),
            _FoundUserCard(user: foundUser!),
          ] else if (errorMessage != null) ...[
            const SizedBox(height: 14),
            _LookupEmpty(message: errorMessage!),
          ],
        ],
      ),
    );
  }
}

class _FoundUserCard extends StatelessWidget {
  const _FoundUserCard({required this.user});

  final SharedUserLookup user;

  @override
  Widget build(BuildContext context) {
    final phone = user.phone?.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.successBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.successSoft),
      ),
      child: Row(
        children: [
          _LookupAvatar(user: user),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AarastStatusPill(
                  label: 'مستخدم مسجل',
                  icon: LucideIcons.badgeCheck,
                  color: AppTheme.success,
                  backgroundColor: AppTheme.ivory,
                ),
                const SizedBox(height: 8),
                Text(
                  user.name.trim().isEmpty ? 'عضو أعرست' : user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (phone != null && phone.isNotEmpty)
                  Text(
                    phone,
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
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

class _LookupAvatar extends StatelessWidget {
  const _LookupAvatar({required this.user});

  final SharedUserLookup user;

  @override
  Widget build(BuildContext context) {
    final imageUrl = user.avatarUrl?.trim();
    final initial = user.name.trim().isEmpty ? 'ع' : user.name.trim()[0];

    return ClipOval(
      child: Container(
        width: 54,
        height: 54,
        color: AppTheme.surface,
        child: imageUrl == null || imageUrl.isEmpty
            ? Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppTheme.burgundy,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: AppTheme.burgundy,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
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

class _RoleDropdown extends StatelessWidget {
  const _RoleDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.surface,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: const InputDecoration(
          labelText: 'الدور',
          prefixIcon: Icon(LucideIcons.shieldCheck),
        ),
        items: const [
          DropdownMenuItem(value: 'VIEWER', child: Text('مشاهد')),
          DropdownMenuItem(value: 'GROOM', child: Text('العريس')),
          DropdownMenuItem(value: 'BRIDE', child: Text('العروس')),
          DropdownMenuItem(value: 'FAMILY', child: Text('العائلة')),
          DropdownMenuItem(value: 'HELPER', child: Text('مساعد')),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _PermissionSwitches extends StatelessWidget {
  const _PermissionSwitches({
    required this.canViewBudget,
    required this.canViewExpenses,
    required this.canViewDebts,
    required this.canEditPlan,
    required this.canManageTasks,
    required this.canManageGuests,
    required this.canManageProviders,
    required this.canInviteMembers,
    required this.canManageFinancialRecords,
    required this.receiveNotifications,
    required this.onViewBudgetChanged,
    required this.onViewExpensesChanged,
    required this.onViewDebtsChanged,
    required this.onEditPlanChanged,
    required this.onManageTasksChanged,
    required this.onManageGuestsChanged,
    required this.onManageProvidersChanged,
    required this.onInviteMembersChanged,
    required this.onManageFinancialRecordsChanged,
    required this.onReceiveNotificationsChanged,
  });

  final bool canViewBudget;
  final bool canViewExpenses;
  final bool canViewDebts;
  final bool canEditPlan;
  final bool canManageTasks;
  final bool canManageGuests;
  final bool canManageProviders;
  final bool canInviteMembers;
  final bool canManageFinancialRecords;
  final bool receiveNotifications;
  final ValueChanged<bool> onViewBudgetChanged;
  final ValueChanged<bool> onViewExpensesChanged;
  final ValueChanged<bool> onViewDebtsChanged;
  final ValueChanged<bool> onEditPlanChanged;
  final ValueChanged<bool> onManageTasksChanged;
  final ValueChanged<bool> onManageGuestsChanged;
  final ValueChanged<bool> onManageProvidersChanged;
  final ValueChanged<bool> onInviteMembersChanged;
  final ValueChanged<bool> onManageFinancialRecordsChanged;
  final ValueChanged<bool> onReceiveNotificationsChanged;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(
            title: 'الصلاحيات',
            icon: LucideIcons.shieldCheck,
          ),
          const SizedBox(height: 8),
          _PermissionTile(
            value: canManageTasks,
            onChanged: onManageTasksChanged,
            title: 'إدارة المهام',
            subtitle: 'إضافة وتعديل مهام الخطة.',
            icon: LucideIcons.listChecks,
          ),
          _PermissionTile(
            value: canManageGuests,
            onChanged: onManageGuestsChanged,
            title: 'إدارة الضيوف',
            subtitle: 'إضافة الضيوف وتحديث حضورهم.',
            icon: LucideIcons.users,
          ),
          _PermissionTile(
            value: canManageProviders,
            onChanged: onManageProvidersChanged,
            title: 'إدارة الموردين والعروض',
            subtitle: 'طلب عروض الأسعار وقبولها أو رفضها.',
            icon: LucideIcons.store,
          ),
          _PermissionTile(
            value: canEditPlan,
            onChanged: onEditPlanChanged,
            title: 'تعديل الخطة',
            subtitle: 'تعديل بيانات الخطة الأساسية.',
            icon: LucideIcons.calendarDays,
          ),
          _PermissionTile(
            value: canInviteMembers,
            onChanged: onInviteMembersChanged,
            title: 'دعوة مشاركين',
            subtitle: 'إرسال الدعوات وإدارة المشاركين.',
            icon: LucideIcons.userPlus,
          ),
          _PermissionTile(
            value: canViewBudget,
            onChanged: onViewBudgetChanged,
            title: 'عرض الميزانية',
            subtitle: 'إظهار ملخص الميزانية فقط.',
            icon: LucideIcons.wallet,
          ),
          _PermissionTile(
            value: canViewExpenses,
            onChanged: onViewExpensesChanged,
            title: 'عرض المصاريف',
            subtitle: 'السماح بقراءة المصاريف المسجلة.',
            icon: LucideIcons.receipt,
          ),
          _PermissionTile(
            value: canViewDebts,
            onChanged: onViewDebtsChanged,
            title: 'عرض الديون والأقساط',
            subtitle: 'بيانات مالية خاصة، فعليها عند الحاجة فقط.',
            icon: LucideIcons.creditCard,
          ),
          _PermissionTile(
            value: canManageFinancialRecords,
            onChanged: onManageFinancialRecordsChanged,
            title: 'إدارة السجلات المالية',
            subtitle: 'إضافة وتعديل المصاريف والديون.',
            icon: LucideIcons.fileText,
          ),
          _PermissionTile(
            value: receiveNotifications,
            onChanged: onReceiveNotificationsChanged,
            title: 'استلام تنبيهات الخطة',
            subtitle: 'إظهار الأحداث المهمة المرتبطة بالخطة.',
            icon: LucideIcons.bellRing,
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      secondary: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: value ? AppTheme.burgundySoft : AppTheme.surface,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          icon,
          color: value ? AppTheme.burgundy : AppTheme.muted,
          size: 21,
        ),
      ),
      title: Text(
        title,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: AppTheme.ink,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        subtitle,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: AppTheme.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PrivacyHint extends StatelessWidget {
  const _PrivacyHint();

  @override
  Widget build(BuildContext context) {
    return const AarastCard(
      color: AppTheme.ivory,
      child: Row(
        children: [
          Icon(LucideIcons.lock, color: AppTheme.gold),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'الخصوصية المالية مغلقة افتراضياً. فعلي صلاحيات الميزانية والمصاريف والديون فقط للعضو المناسب.',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
                height: 1.45,
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
