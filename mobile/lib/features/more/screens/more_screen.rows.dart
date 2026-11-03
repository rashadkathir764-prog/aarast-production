part of 'more_screen.dart';

/// One row: an icon, a title, then a value with an arrow or a switch.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.switchValue,
    this.onSwitch,
    this.color,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitch;

  /// A warning colour; the plan's colour (with ink text) when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final toggle = switchValue;
    final color = this.color ?? context.accent.primary;
    final row = Padding(
      padding: const EdgeInsets.all(AarastV3Space.x3),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AarastV3Space.x3),
          Expanded(
            child: Text(
              title,
              style: JourneyType.of(
                JourneyType.body,
                weight: JourneyType.bold,
                color: this.color == null ? AarastV3Color.text : color,
              ),
            ),
          ),
          if (toggle != null)
            JourneyToggle(value: toggle, onChanged: onSwitch)
          else ...[
            if (value != null)
              Text(
                value!,
                style: JourneyType.of(
                  JourneyType.bodySmall,
                  color: AarastV3Color.textMuted,
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: AarastV3Space.x1),
              const Icon(
                LucideIcons.chevronLeft,
                size: 17,
                color: AarastV3Color.textFaint,
              ),
            ],
          ],
        ],
      ),
    );
    // A switch row flips from anywhere on it.
    final switchChanged = onSwitch;
    final VoidCallback? tap = toggle != null && switchChanged != null
        ? () => switchChanged(!toggle)
        : onTap;
    if (tap == null) return row;
    return AarastPressable(onTap: tap, child: row);
  }
}
