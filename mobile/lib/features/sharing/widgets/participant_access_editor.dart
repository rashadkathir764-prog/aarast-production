import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../models/participant_access.dart';
import '../models/plan_role_permissions.dart';
import '../models/shared_member.dart' show ParticipantGender;

/// D80, said to the plan's owner: what every participant reads, where they
/// edit, and what stays the owner's.
String participantReadingNote(BuildContext context) =>
    'كل مشارك يشوف أسماء الضيوف والمهام والحجوزات، ويعدّل بس في القسم اللي '
    '${context.say('تفتحه', 'تفتحينه')} له. أرقام جوالات الضيوف لك ولمن '
    'أضافهم، ومصادر فلوسك وسلفك تبقى لك.';

/// g06's ready roles and per-section levels, shared by adding a participant
/// and editing one. Tasks, guests and providers are «يشوف / يعدّل»: every
/// participant reads them (D80; the server guards only the money's reading),
/// so «لا» promised a hiding that never happened. Money alone is
/// «لا / يشوف / يعدّل». Choosing a role resets the levels to its defaults.
class ParticipantAccessEditor extends StatelessWidget {
  const ParticipantAccessEditor({
    required this.role,
    required this.permissions,
    required this.onPresetSelected,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final String role;
  final PlanRolePermissions permissions;
  final ValueChanged<ParticipantPreset> onPresetSelected;
  final ValueChanged<PlanRolePermissions> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = permissions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in ParticipantPreset.values)
              JourneyChip(
                key: ValueKey('participant-preset-${preset.role}'),
                label: preset.label,
                selected: role == preset.role,
                fontSize: JourneyType.small,
                onTap: enabled ? () => onPresetSelected(preset) : null,
              ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x3),
        JourneyBox(
          padding: AarastV3Density.chipInsets,
          child: Column(
            children: [
              _LevelRow(
                icon: LucideIcons.listChecks,
                label: 'المهام',
                selected: p.canManageTasks ? 1 : 0,
                onChanged: enabled
                    ? (i) => onChanged(p.copyWith(canManageTasks: i == 1))
                    : null,
              ),
              _LevelRow(
                icon: LucideIcons.users,
                label: JourneySection.guests.labelOf(context),
                selected: p.canManageGuests ? 1 : 0,
                onChanged: enabled
                    ? (i) => onChanged(p.copyWith(canManageGuests: i == 1))
                    : null,
              ),
              _LevelRow(
                icon: LucideIcons.store,
                label: 'المزودين',
                selected: p.canManageProviders ? 1 : 0,
                onChanged: enabled
                    ? (i) => onChanged(p.copyWith(canManageProviders: i == 1))
                    : null,
              ),
              _LevelRow(
                icon: LucideIcons.wallet,
                label: 'المال',
                options: const ['لا', 'يشوف', 'يعدّل'],
                selected: p.moneyLevel.index,
                onChanged: enabled
                    ? (i) => onChanged(p.withMoneyLevel(MoneyLevel.values[i]))
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: AarastV3Space.x2),
        JourneyNote(
          key: const ValueKey('participant-access-note'),
          icon: LucideIcons.lock,
          text: role == 'GROOM' || role == 'BRIDE'
              ? 'الشريك يشوف الخطة كلها في الأقسام اللي '
                    '${context.say('تفتحها', 'تفتحينها')} له، إلا مصادر '
                    'فلوسك وسلفك تبقى لك.'
              : participantReadingNote(context),
        ),
      ],
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onChanged,
    this.options = const ['يشوف', 'يعدّل'],
  });

  final IconData icon;
  final String label;
  final List<String> options;
  final int selected;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x1),
      // With large text on a narrow phone the switch drops under its name
      // instead of running off the row. The full width lets spaceBetween
      // put the switch on the far side, as drawn.
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 6,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: AarastV3Icon.md,
                  color: context.accent.primary,
                ),
                const SizedBox(width: AarastV3Space.x2),
                Text(
                  label,
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                  ),
                ),
              ],
            ),
            JourneyLevelSwitch(
              key: ValueKey('participant-level-$label'),
              options: options,
              selected: selected,
              semanticLabel: label,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

/// Q-67 (D127): «ذكر ولا أنثى؟», asked when adding a participant and on
/// their page, so the plan speaks of a mother or a sister in the feminine
/// («سجّلت»). The roles do not say it: «أهل» is a father or a mother.
class ParticipantGenderChoice extends StatelessWidget {
  const ParticipantGenderChoice({
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.errorText,
    super.key,
  });

  final ParticipantGender? selected;
  final ValueChanged<ParticipantGender> onChanged;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final error = errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const JourneyFieldLabel('ذكر ولا أنثى؟'),
        const SizedBox(height: AarastV3Space.x1),
        Wrap(
          spacing: AarastV3Space.x2,
          runSpacing: AarastV3Space.x2,
          children: [
            for (final gender in ParticipantGender.values)
              JourneyChip(
                key: ValueKey('participant-gender-${gender.wire}'),
                label: gender.label,
                selected: selected == gender,
                fontSize: JourneyType.small,
                onTap: enabled ? () => onChanged(gender) : null,
              ),
          ],
        ),
        if (error != null) JourneyFieldError(error),
      ],
    );
  }
}
