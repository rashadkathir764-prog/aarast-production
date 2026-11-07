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
    // The prototype's topTabs: a 13.5 bold name on a selected fill 8 above
    // and below it, 4 inside the pill at its sides. RA-MO-28 (D74): the pill
    // is at least 48 tall and each tab fills its height, so every tab is
    // touched in 48; the selected fill keeps its size, centred.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x1),
      constraints: const BoxConstraints(minHeight: AarastV3Space.x12),
      decoration: BoxDecoration(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.circular(AarastV3Radius.surface),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    child: Center(
                      child: SizedBox(
                        width: double.infinity,
                        child: AnimatedContainer(
                          key: ValueKey('journey-tab-$index'),
                          duration: const Duration(milliseconds: 180),
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
                          // The fill is as tall as its name, not the 48 tab.
                          child: Center(
                            heightFactor: 1,
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
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
