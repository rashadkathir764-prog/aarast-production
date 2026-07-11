import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_ui.dart';
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

  List<String> _rolesFor(SharedMember member) {
    if (_baseEditRoles.contains(member.role)) return _baseEditRoles;
    return [..._baseEditRoles, member.role];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SharingProvider>();
    final member =
        provider.selectedMember ?? provider.findMember(widget.sharedMemberId);

    if (member == null) {
      return const AarastPageScaffold(
        title: 'تعديل عضو المشاركة',
        showBack: true,
        child: Center(
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

  void _syncFromMember(SharedMember member) {
    _role = member.role;
    _permissions = member.toPermissions();
    _initialized = true;
  }

  Future<void> _save(SharedMember member) async {
    final provider = context.read<SharingProvider>();
    final updated = await provider.updateMember(
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
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إزالة العضو؟'),
          content: Text('سيفقد "${member.displayName}" الوصول للخطة فورًا.'),
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
      ),
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    final provider = context.read<SharingProvider>();
    final removed = await provider.removeMember(member.id);

    if (!mounted) {
      return;
    }

    if (removed) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRouter.sharing(member.weddingPlanId));
      }
    }
  }
}
