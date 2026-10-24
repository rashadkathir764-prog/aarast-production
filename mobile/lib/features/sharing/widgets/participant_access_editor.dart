import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../models/participant_access.dart';
import '../models/plan_role_permissions.dart';

/// g06's ready roles and per-section levels, shared by adding a participant
/// and editing one. Tasks, guests and providers are «لا / يعدّل»; money is
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
        const SizedBox(height: 12),
        JourneyBox(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
        const SizedBox(height: 10),
        JourneyNote(
          key: const ValueKey('participant-access-note'),
          icon: LucideIcons.lock,
          text: role == 'GROOM' || role == 'BRIDE'
              ? 'الشريك يشوف الخطة كلها في الأقسام اللي '
                    '${context.say('تفتحها', 'تفتحينها')} له، إلا مصادر '
                    'فلوسك وسلفك تبقى لك.'
              : 'في كل قسم ${context.say('تفتحه', 'تفتحينه')}، المشارك يشوف '
                    'اللي أضافه هو أو اللي عليه بس. '
                    '"المهام: يعدّل" يعني يضيف مهام ويخلّص اللي عليه، ومصادر '
                    'فلوسك وسلفك تبقى لك.',
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
    this.options = const ['لا', 'يعدّل'],
  });

  final IconData icon;
  final String label;
  final List<String> options;
  final int selected;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
                Icon(icon, size: 19, color: context.accent.primary),
                const SizedBox(width: 10),
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
