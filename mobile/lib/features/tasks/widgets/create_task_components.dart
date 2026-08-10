import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../shared/models/contact_phone_draft.dart';
import '../../../shared/widgets/contact_phone_field.dart';
import '../../sharing/models/shared_member.dart';
import '../models/wedding_task.dart';

class CreateTaskDetailsDisclosure extends StatelessWidget {
  const CreateTaskDetailsDisclosure({
    required this.initiallyExpanded,
    required this.summary,
    required this.child,
    super.key,
  });

  final bool initiallyExpanded;
  final String summary;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AarastV3Disclosure(
      title: 'المسؤول والتفاصيل',
      subtitle: summary,
      icon: LucideIcons.userCog,
      initiallyExpanded: initiallyExpanded,
      child: child,
    );
  }
}

class CreateTaskResponsibleSection extends StatelessWidget {
  const CreateTaskResponsibleSection({
    required this.participants,
    required this.selectedAssigneeUserId,
    required this.selectedAssigneeRole,
    required this.responsibleNameController,
    required this.responsiblePhoneController,
    required this.canInviteResponsible,
    required this.onSelectParticipant,
    required this.onManualChanged,
    required this.onDraftChanged,
    required this.onInvite,
    super.key,
  });

  final List<SharedMember> participants;
  final String? selectedAssigneeUserId;
  final String? selectedAssigneeRole;
  final TextEditingController responsibleNameController;
  final TextEditingController responsiblePhoneController;
  final bool canInviteResponsible;
  final ValueChanged<List<SharedMember>> onSelectParticipant;
  final VoidCallback onManualChanged;
  final ValueChanged<ContactPhoneDraft> onDraftChanged;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final selectedParticipant = _findSelectedParticipant(
      participants,
      selectedAssigneeUserId,
    );
    final responsibleNameIsPhone = PhoneNumberUtils.areEquivalent(
      responsibleNameController.text,
      responsiblePhoneController.text,
    );

    return Container(
      padding: const EdgeInsets.all(AppTheme.space12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.userCheck,
                color: AppTheme.brand,
                size: 21,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'المسؤول عن المهمة',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (selectedParticipant != null)
                CreateTaskParticipantBadge(role: selectedAssigneeRole),
            ],
          ),
          if (participants.isNotEmpty) ...[
            const SizedBox(height: 12),
            CreateTaskSelectorField(
              label: 'مشارك من الخطة',
              value: selectedParticipant == null
                  ? 'اختر مشاركاً موجوداً'
                  : selectedParticipant.directionalDisplayName,
              icon: LucideIcons.users,
              selected: selectedParticipant != null,
              onTap: () => onSelectParticipant(participants),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: responsibleNameController,
            textAlign: TextAlign.right,
            textDirection: responsibleNameIsPhone
                ? TextDirection.ltr
                : TextDirection.rtl,
            textInputAction: TextInputAction.next,
            onChanged: (_) => onManualChanged(),
            decoration: const InputDecoration(
              labelText: 'اسم المسؤول',
              hintText: 'أنا أو اسم الشخص المسؤول',
              prefixIcon: Icon(LucideIcons.user),
            ),
          ),
          const SizedBox(height: 12),
          ContactPhoneField(
            phoneController: responsiblePhoneController,
            nameController: responsibleNameController,
            label: 'رقم المسؤول',
            hintText: '77xxxxxxx',
            helperText: 'يمكن ترك الرقم فارغاً؛ يظهر كرقم متابعة للمسؤول فقط.',
            onDraftChanged: onDraftChanged,
          ),
          if (canInviteResponsible) ...[
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.brand,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onInvite,
                icon: const Icon(LucideIcons.userPlus, size: 18),
                label: const Text('دعوته كمشارك في الخطة'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CreateTaskParticipantRow extends StatelessWidget {
  const CreateTaskParticipantRow({
    required this.member,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final SharedMember member;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppTheme.brandMuted : AppTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(
              color: selected ? AppTheme.brand : AppTheme.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? LucideIcons.checkCircle : LucideIcons.user,
                color: selected ? AppTheme.brand : AppTheme.focus,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (member.displayNamePhone case final phone?)
                      AarastPhoneText(
                        phone: phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    else
                      Text(
                        member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    Text(
                      sharedMemberRoleLabel(member.role),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateTaskParticipantBadge extends StatelessWidget {
  const CreateTaskParticipantBadge({this.role, super.key});

  final String? role;

  @override
  Widget build(BuildContext context) {
    final hasRole = role?.trim().isNotEmpty == true;
    return Semantics(
      label: hasRole
          ? 'مشارك في الخطة، ${sharedMemberRoleLabel(role!.trim())}'
          : 'مشارك في الخطة',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.brandMuted,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTheme.brandMuted),
          ),
          child: Text(
            'مشارك في الخطة',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.brand,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class CreateTaskSelectorField extends StatelessWidget {
  const CreateTaskSelectorField({
    required this.label,
    required this.value,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppTheme.brand : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppTheme.brand : AppTheme.focus,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronDown,
              size: 17,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class CreateTaskPriorityChip extends StatelessWidget {
  const CreateTaskPriorityChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withAlpha(25) : AppTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: selected ? color : AppTheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? color : AppTheme.textSecondary,
                size: 16,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? color : AppTheme.textSecondary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateTaskCategoryRow extends StatelessWidget {
  const CreateTaskCategoryRow({
    required this.category,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final CreateTaskCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AarastCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        color: selected ? AppTheme.brandMuted : AppTheme.surfaceRaised,
        border: Border.all(color: selected ? AppTheme.brand : AppTheme.border),
        onTap: onTap,
        child: Row(
          children: [
            Icon(category.icon, color: AppTheme.brand),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? AppTheme.brand : AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (selected)
              const Icon(LucideIcons.checkCircle, color: AppTheme.brand),
          ],
        ),
      ),
    );
  }
}

class CreateTaskSheetHandle extends StatelessWidget {
  const CreateTaskSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 46,
        height: 5,
        decoration: BoxDecoration(
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class CreateTaskCategory {
  const CreateTaskCategory(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;
}

String formatTaskDueDate(DateTime date) => formatArabicCompactDate(date);

ContactPhoneSource contactPhoneSourceFromTask(WeddingTask task) {
  if (task.hasResponsibleParticipant) return ContactPhoneSource.planContact;
  final source = task.responsibleSource?.trim();
  return switch (source) {
    'deviceContact' => ContactPhoneSource.deviceContact,
    'planContact' => ContactPhoneSource.planContact,
    _ => ContactPhoneSource.manual,
  };
}

List<SharedMember> sharedMembersForPlan(
  List<SharedMember> members,
  String weddingPlanId,
) {
  return members
      .where((member) => member.weddingPlanId == weddingPlanId)
      .toList(growable: false);
}

SharedMember? _findSelectedParticipant(
  List<SharedMember> members,
  String? assigneeUserId,
) {
  final id = assigneeUserId?.trim();
  if (id == null || id.isEmpty) return null;
  for (final member in members) {
    if (member.userId == id) return member;
  }
  return null;
}

SharedMember? findCurrentSharedMember(
  List<SharedMember> members,
  String? currentUserId,
) {
  final id = currentUserId?.trim();
  if (id == null || id.isEmpty) return null;
  for (final member in members) {
    if (member.userId == id) return member;
  }
  return null;
}

bool isSelfTaskLabel(String value) {
  final normalized = value.trim().replaceAll('أ', 'ا').replaceAll('إ', 'ا');
  return normalized == 'انا';
}
