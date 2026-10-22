import 'package:flutter/material.dart';

import '../widgets/aarast_pressable.dart';
import 'aarast_journey.dart';
import 'aarast_v3_foundations.dart';

/// The pill switcher at the top of a section (money «الملخص · البنود ·
/// الدفعات · من وين»): the chosen tab is filled in the section's colour.
/// A name shrinks a little before it is ever cut.
class JourneyTabSwitch extends StatelessWidget {
  const JourneyTabSwitch({
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.color = AarastV3Color.primary,
    super.key,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.circular(18),
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
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    key: ValueKey('journey-tab-$index'),
                    duration: const Duration(milliseconds: 180),
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == selected ? color : null,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labels[index],
                        maxLines: 1,
                        style: JourneyType.of(
                          JourneyType.body,
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
