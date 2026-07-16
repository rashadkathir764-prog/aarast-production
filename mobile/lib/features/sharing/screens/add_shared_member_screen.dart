import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_duplicate_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../shared/widgets/contact_phone_field.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../models/invite_share_content.dart';
import '../models/plan_role_permissions.dart';
import '../models/shared_member.dart';
import '../providers/sharing_provider.dart';
import '../services/invite_share_launcher.dart';
import '../widgets/permission_editor.dart';

/// أدوار الدعوة المعروضة — اختيار الدور يضبط الصلاحيات الافتراضية تلقائيًا.
const _addMemberRoles = ['VIEWER', 'GROOM', 'BRIDE', 'FAMILY', 'HELPER'];

class AddSharedMemberScreen extends StatefulWidget {
  const AddSharedMemberScreen({
    required this.weddingPlanId,
    this.inviteShareLauncher = const UrlLauncherInviteShareLauncher(),
    super.key,
  });

  final String weddingPlanId;
  final InviteShareLauncher inviteShareLauncher;

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
  bool _showPermissionGate = false;
  bool _showAccessError = false;
  PlanInvite? _createdInvite;
  bool _shareHandled = false;
  bool _isCreatingInvite = false;

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
    final createdInvite = _createdInvite;
    final foundUser = provider.lookupUser;
    final isSubmitting = provider.isSubmitting || _isCreatingInvite;
    final gate = _authGateFor(provider);
    final duplicateMessage =
        _localPhoneError ??
        _duplicateMemberMessage(provider.members, provider.invites);

    return PopScope<Object?>(
      canPop: createdInvite == null || _shareHandled,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: AarastPageScaffold(
        title: createdInvite == null ? 'إضافة عضو' : 'دعوة المشاركة جاهزة',
        subtitle: createdInvite == null
            ? 'ابحث بالرقم ثم اختر الدور — الصلاحيات تُضبط تلقائيًا.'
            : 'أرسل الرابط الآن عبر واتساب أو انسخه بأمان.',
        resizeToAvoidBottomInset: true,
        actions: [
          IconButton(
            tooltip: 'رجوع',
            onPressed: _handleBack,
            icon: const Icon(LucideIcons.chevronRight),
          ),
        ],
        child: createdInvite != null
            ? _InviteCreatedView(
                invite: createdInvite,
                onWhatsApp: _openWhatsApp,
                onCopy: _copyInviteLink,
                onDone: _handleBack,
              )
            : gate ??
                  Form(
                    key: _formKey,
                    child: ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
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
                                enabled: !provider.isLookingUp && !isSubmitting,
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
                          enabled: !isSubmitting,
                        ),
                        if (provider.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          _InlineError(message: provider.errorMessage!),
                        ],
                        const SizedBox(height: 18),
                        AarastButton(
                          label: 'إرسال دعوة المشاركة',
                          icon: LucideIcons.userPlus,
                          isLoading: isSubmitting,
                          onPressed: isSubmitting ? null : _submit,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
      ),
    );
  }

  Future<void> _handleBack() async {
    if (_createdInvite != null && !_shareHandled) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AarastDialog(
          icon: const Icon(
            LucideIcons.link,
            color: AppTheme.burgundy,
            size: 28,
          ),
          title: const Text('هل حفظت رابط الدعوة؟'),
          content: const Text(
            'رابط الدعوة الآمن يظهر الآن فقط. أرسله عبر واتساب أو انسخه قبل المغادرة.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('البقاء'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('مغادرة'),
            ),
          ],
        ),
      );
      if (leave != true || !mounted) return;
    }
    _finish();
  }

  void _finish() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouter.sharing(widget.weddingPlanId));
    }
  }

  Future<void> _openWhatsApp() async {
    final invite = _createdInvite;
    if (invite == null) return;
    try {
      final content = InviteShareContent.fromInvite(invite);
      final opened = await widget.inviteShareLauncher.openWhatsApp(
        content.whatsappUri,
      );
      if (!mounted) return;
      if (!opened) {
        _showError('تعذر فتح واتساب. انسخ الرابط وأرسله يدويًا.');
        return;
      }
    } on FormatException {
      if (mounted) {
        _showError(
          'رقم المدعو غير صالح لفتح واتساب. انسخ الرابط بدلًا من ذلك.',
        );
      }
    } catch (_) {
      if (mounted) {
        _showError('تعذر فتح واتساب. انسخ الرابط وأرسله يدويًا.');
      }
    }
  }

  Future<void> _copyInviteLink() async {
    final invite = _createdInvite;
    if (invite == null) return;
    final link = InviteShareContent.fromInvite(invite).inviteLink.toString();
    try {
      await Clipboard.setData(ClipboardData(text: link));
    } catch (_) {
      if (mounted) {
        AarastToast.showError(
          context,
          'تعذر نسخ الرابط. حاول مرة أخرى قبل مغادرة الشاشة.',
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() => _shareHandled = true);
    AarastToast.showSuccess(context, 'تم نسخ رابط الدعوة.');
  }

  void _showError(String message) => AarastToast.showError(context, message);

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
    if (_isCreatingInvite) return;
    setState(() => _isCreatingInvite = true);
    try {
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
        canViewMoney: _permissions.canViewMoney,
        canEditPlan: _permissions.canEditPlan,
        canManageTasks: _permissions.canManageTasks,
        canManageGuests: _permissions.canManageGuests,
        canManageProviders: _permissions.canManageProviders,
        canInviteMembers: _permissions.canInviteMembers,
        canManageMoney: _permissions.canManageMoney,
        receiveNotifications: _permissions.receiveNotifications,
      );

      if (!mounted) return;

      if (created != null) {
        setState(() {
          _createdInvite = created;
          _shareHandled = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingInvite = false);
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
      _showPermissionGate = false;
      _showAccessError = false;
    });

    final shouldGate = await AuthActionGuard.shouldGateProtectedSharing(
      context,
      weddingPlanId: widget.weddingPlanId,
    );
    if (!mounted) return true;

    if (shouldGate) {
      setState(() {
        _isCheckingSharingAccess = false;
        _showLoginGate = true;
      });
      return true;
    }

    final provider = context.read<SharingProvider>();
    final accessLoaded = await provider.loadAccess(widget.weddingPlanId);
    if (!mounted) return true;
    final canManageMembers = accessLoaded && provider.access.canManageMembers;
    setState(() {
      _isCheckingSharingAccess = false;
      _showPermissionGate = accessLoaded && !canManageMembers;
      _showAccessError = !accessLoaded && provider.authGateKind == null;
    });
    return !canManageMembers;
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

    if (_showAccessError) {
      return AarastErrorState(
        title: 'تعذر التحقق من الصلاحيات',
        message:
            provider.accessErrorMessage ?? 'تحقق من الاتصال وحاول مرة أخرى.',
        onRetry: _refreshSharingAccess,
      );
    }

    if (_showPermissionGate) {
      return const AarastEmptyState(
        title: 'ليس لديك صلاحية دعوة المشاركين',
        message: 'إضافة الأعضاء وتحديد صلاحياتهم متاحة للمصرح لهم فقط.',
        icon: LucideIcons.shieldAlert,
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

class _InviteCreatedView extends StatelessWidget {
  const _InviteCreatedView({
    required this.invite,
    required this.onWhatsApp,
    required this.onCopy,
    required this.onDone,
  });

  final PlanInvite invite;
  final VoidCallback onWhatsApp;
  final VoidCallback onCopy;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final recipientName = invite.name?.trim();
    final phone = invite.phone?.trim();

    return ListView(
      key: const Key('invite-created-view'),
      children: [
        AarastCard(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.successBg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.successSoft),
                ),
                child: const Icon(
                  LucideIcons.send,
                  color: AppTheme.success,
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'تم إنشاء الدعوة بأمان',
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                recipientName == null || recipientName.isEmpty
                    ? 'الرابط جاهز للإرسال إلى العضو.'
                    : 'الرابط جاهز للإرسال إلى $recipientName.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (phone != null && phone.isNotEmpty) ...[
                const SizedBox(height: 8),
                AarastPhoneText(
                  phone: phone,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: AppTheme.burgundy,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        AarastCard(
          color: AppTheme.goldSoft.withAlpha(34),
          border: Border.all(color: AppTheme.gold.withAlpha(80)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                LucideIcons.shieldCheck,
                color: AppTheme.burgundy,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'هذا رابط خاص بالمدعو ويظهر الآن فقط. لن تظهر تفاصيل الخطة قبل التحقق من رقم الهاتف.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        AarastButton(
          key: const Key('invite-share-whatsapp'),
          label: 'إرسال عبر واتساب',
          icon: LucideIcons.messageCircle,
          onPressed: onWhatsApp,
        ),
        const SizedBox(height: 10),
        AarastButton(
          key: const Key('invite-copy-link'),
          label: 'نسخ رابط الدعوة',
          icon: LucideIcons.copy,
          variant: AarastButtonVariant.secondary,
          onPressed: onCopy,
        ),
        const SizedBox(height: 6),
        AarastButton(
          key: const Key('invite-done'),
          label: 'تم',
          variant: AarastButtonVariant.ghost,
          onPressed: onDone,
        ),
        const SizedBox(height: 20),
      ],
    );
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
                  AarastPhoneText(
                    phone: phone,
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
