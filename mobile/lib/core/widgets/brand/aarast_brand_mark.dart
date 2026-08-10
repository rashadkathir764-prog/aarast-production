import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../experience_v3/aarast_v3.dart';

/// The single flat Aarast brand signature used by entry surfaces.
class AarastBrandMark extends StatelessWidget {
  const AarastBrandMark({super.key});

  static const semanticsLabel = 'اعّرست، كل ما يخص الزفاف في مكان واحد';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      image: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AarastV3Color.primarySoft,
                borderRadius: BorderRadius.circular(AarastV3Radius.surface),
                border: Border.all(color: AarastV3Color.lineStrong),
              ),
              child: const Icon(
                LucideIcons.sparkles,
                color: AarastV3Color.primary,
                size: 21,
              ),
            ),
            const SizedBox(height: AarastV3Space.x3),
            Text(
              'اعّرست',
              style: AarastV3Type.display(
                context,
              ).copyWith(color: AarastV3Color.ink, fontSize: 38),
            ),
            const SizedBox(height: AarastV3Space.x2),
            Text(
              'كل ما يخص الزفاف في مكان واحد',
              textAlign: TextAlign.center,
              style: AarastV3Type.body(
                context,
              ).copyWith(color: AarastV3Color.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
