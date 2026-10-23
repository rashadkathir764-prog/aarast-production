import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../shared/models/contact_phone_draft.dart';
import '../../../shared/widgets/contact_phone_field.dart';
import '../../sharing/sharing_api.dart' show SharedMember;
import '../models/wedding_task.dart';

/// The «لمين؟» choice for someone not in the list yet.
const createTaskOtherPerson = 'other';

/// d02 «لمين؟»: the owner, the plan's members and people already given
/// tasks as chips, and «شخص ثاني» with a name and an optional number. A
/// private task stays with its owner, so [locked] keeps it on «أنا».
class CreateTaskResponsibleSection extends StatelessWidget {
  const CreateTaskResponsibleSection({
    required this.choices,
    required this.selected,
    required this.onSelected,
    required this.otherNameController,
    required this.otherPhoneController,
    required this.onDraftChanged,
    required this.canInvite,
    required this.onInvite,
    this.locked = false,
    this.otherNameError,
    super.key,
  });

  /// (key, label) for every choice but «شخص ثاني», «أنا» first.
  final List<(String, String)> choices;
  final String selected;
  final ValueChanged<String> onSelected;
  final TextEditingController otherNameController;
  final TextEditingController otherPhoneController;
  final ValueChanged<ContactPhoneDraft> onDraftChanged;
  final bool canInvite;
  final VoidCallback onInvite;
  final bool locked;
  final String? otherNameError;

  @override
  Widget build(BuildContext context) {
    final nameIsPhone = PhoneNumberUtils.areEquivalent(
      otherNameController.text,
      otherPhoneController.text,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'لمين؟',
            style: JourneyType.of(
              JourneyType.small,
              weight: JourneyType.bold,
              color: AarastV3Color.textMuted,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (key, label) in choices)
              JourneyChip(
                key: ValueKey('task-who-$key'),
                label: label,
                selected: selected == key,
                selectedColor: AarastV3Color.brandAccentStrong,
                onTap: locked && key != choices.first.$1
                    ? null
                    : () => onSelected(key),
              ),
            if (!locked)
              JourneyChip(
                key: const ValueKey('task-who-other'),
                label: 'شخص ثاني',
                icon: LucideIcons.plus,
                selected: selected == createTaskOtherPerson,
                selectedColor: AarastV3Color.brandAccentStrong,
                onTap: () => onSelected(createTaskOtherPerson),
              ),
          ],
        ),
        if (locked)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'المهمة الخاصة تبقى لك وحدك',
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
        if (selected == createTaskOtherPerson) ...[
          const SizedBox(height: 12),
          JourneyTextField(
            key: const ValueKey('task-other-name'),
            label: 'اسمه',
            hint: 'مثلًا: الوالد',
            controller: otherNameController,
            icon: LucideIcons.user,
            textDirection: nameIsPhone ? TextDirection.ltr : null,
            errorText: otherNameError,
          ),
          const SizedBox(height: 10),
          ContactPhoneField(
            key: const ValueKey('task-other-phone'),
            phoneController: otherPhoneController,
            nameController: otherNameController,
            label: 'رقمه (لو تبي)',
            hintText: '77xxxxxxx',
            onDraftChanged: onDraftChanged,
          ),
          if (canInvite)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: JourneyTextAction(
                key: const ValueKey('task-invite-responsible'),
                label: 'دعوته كمشارك في الخطة',
                icon: LucideIcons.userPlus,
                color: AarastV3Color.primary,
                onPressed: onInvite,
              ),
            ),
        ],
      ],
    );
  }
}

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
