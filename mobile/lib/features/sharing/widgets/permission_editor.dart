import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/plan_role_permissions.dart';
import '../models/shared_member.dart';

/// محرر الدور والصلاحيات الموحد لشاشتي الإضافة والتعديل:
/// اختيار الدور يضبط الصلاحيات تلقائيًا، والتفاصيل مطوية خلف ملخص
/// من سطر واحد — تُفتح فقط لمن يريد التخصيص.
class SharedPermissionEditor extends StatefulWidget {
  const SharedPermissionEditor({
    required this.role,
    required this.roles,
    required this.permissions,
    required this.onRoleSelected,
    required this.onPermissionsChanged,
    this.enabled = true,
    this.initiallyExpanded = false,
    super.key,
  });

  final String role;
  final List<String> roles;
  final PlanRolePermissions permissions;
  final ValueChanged<String> onRoleSelected;
  final ValueChanged<PlanRolePermissions> onPermissionsChanged;
  final bool enabled;
  final bool initiallyExpanded;

  @override
  State<SharedPermissionEditor> createState() => _SharedPermissionEditorState();
}

class _SharedPermissionEditorState extends State<SharedPermissionEditor> {
  late bool _expanded = widget.initiallyExpanded;

  void _emit(PlanRolePermissions value) => widget.onPermissionsChanged(value);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final value = widget.permissions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'الدور',
          style: textTheme.titleSmall?.copyWith(
            color: AppTheme.deepBurgundy,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final role in widget.roles)
              _RoleChip(
                label: sharedMemberRoleLabel(role),
                selected: role == widget.role,
                onTap: widget.enabled
                    ? () => widget.onRoleSelected(role)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 14),
        AarastCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    LucideIcons.shieldCheck,
                    size: 17,
                    color: AppTheme.gold,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'صلاحيات الدور: ${sharedMemberRoleLabel(widget.role)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _expanded ? 'إخفاء التخصيص' : 'تخصيص',
                            style: textTheme.labelMedium?.copyWith(
                              color: AppTheme.burgundy,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            _expanded
                                ? LucideIcons.chevronUp
                                : LucideIcons.chevronDown,
                            size: 14,
                            color: AppTheme.burgundy,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value.summaryLabel,
                style: textTheme.labelSmall?.copyWith(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_expanded) ...[
                Container(
                  height: 1,
                  margin: const EdgeInsets.only(top: 10),
                  color: AppTheme.border,
                ),
                const _GroupLabel('التنظيم'),
                _PermissionRow(
                  title: 'إدارة المهام',
                  value: value.canManageTasks,
                  enabled: widget.enabled,
                  onChanged: (v) => _emit(value.copyWith(canManageTasks: v)),
                ),
                _PermissionRow(
                  title: 'إدارة الضيوف',
                  value: value.canManageGuests,
                  enabled: widget.enabled,
                  onChanged: (v) => _emit(value.copyWith(canManageGuests: v)),
                ),
                _PermissionRow(
                  title: 'الموردون والعروض',
                  value: value.canManageProviders,
                  enabled: widget.enabled,
                  onChanged: (v) =>
                      _emit(value.copyWith(canManageProviders: v)),
                ),
                _PermissionRow(
                  title: 'تعديل الخطة',
                  value: value.canEditPlan,
                  enabled: widget.enabled,
                  onChanged: (v) => _emit(value.copyWith(canEditPlan: v)),
                ),
                _PermissionRow(
                  title: 'دعوة مشاركين',
                  value: value.canInviteMembers,
                  enabled: widget.enabled,
                  onChanged: (v) => _emit(value.copyWith(canInviteMembers: v)),
                ),
                const _GroupLabel('المال · خاص', color: AppTheme.gold),
                _PermissionRow(
                  title: 'مشاهدة المال',
                  value: value.canViewMoney,
                  enabled: widget.enabled,
                  onChanged: (v) {
                    _emit(
                      value.copyWith(
                        canViewMoney: v,
                        canManageMoney: v ? null : false,
                      ),
                    );
                  },
                ),
                _PermissionRow(
                  title: 'إدارة المال',
                  value: value.canManageMoney,
                  enabled: widget.enabled,
                  onChanged: (v) => _emit(
                    value.copyWith(
                      canManageMoney: v,
                      canViewMoney: v ? true : null,
                    ),
                  ),
                ),
                const _GroupLabel('التنبيهات'),
                _PermissionRow(
                  title: 'استلام تنبيهات الخطة',
                  value: value.receiveNotifications,
                  enabled: widget.enabled,
                  onChanged: (v) =>
                      _emit(value.copyWith(receiveNotifications: v)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {this.color = AppTheme.muted});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.burgundy : AppTheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppTheme.burgundy : AppTheme.border,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: selected ? Colors.white : AppTheme.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
