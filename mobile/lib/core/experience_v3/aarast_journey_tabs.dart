import 'package:flutter/material.dart';

import '../widgets/aarast_pressable.dart';
import 'aarast_journey.dart';
import 'aarast_journey_profile.dart';
import 'aarast_v3_foundations.dart';

/// The pill switcher at the top of a section (money «الملخص · البنود ·
/// الدفعات · من وين»): the chosen tab is filled in the section's colour.
/// A name shrinks a little before it is ever cut.
class JourneyTabSwitch extends StatelessWidget {
  const JourneyTabSwitch({
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.color,
    super.key,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  /// The chosen tab's fill; the plan's colour when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.accent.primary;
    // The prototype's topTabs: 4 around, 9 above and below a 13.5 bold
    // name, 16 outside and 12 inside; about 44 tall.
    return Container(
      padding: const EdgeInsets.all(AarastV3Space.x1),
      decoration: BoxDecoration(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      ),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: Semantics(
                button: true,
                selected: index == selected,
                label: labels[index],
                onTap: () => onSelected(index),
                excludeSemantics: true,
                child: AarastPressable(
                  onTap: () => onSelected(index),
                  selected: index == selected,
                  borderRadius: BorderRadius.circular(AarastV3Radius.control),
                  child: AnimatedContainer(
                    key: ValueKey('journey-tab-$index'),
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AarastV3Space.x1,
                      vertical: AarastV3Space.x2,
                    ),
                    decoration: BoxDecoration(
                      color: index == selected ? color : null,
                      borderRadius: BorderRadius.circular(
                        AarastV3Radius.control,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labels[index],
                        maxLines: 1,
                        style: JourneyType.of(
                          JourneyType.detail,
                          weight: JourneyType.bold,
                          color: index == selected
                              ? AarastV3Color.onPrimary
                              : AarastV3Color.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
