import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';
import 'provider_services_tab.dart';

/// His services and packages, opened from «ملفي» since the calendar took
/// their place in the bottom bar (p28, D39). The list itself is unchanged
/// until p36 (slice 4) rebuilds it; this page only gives it a way back.
class ProviderServicesScreen extends StatelessWidget {
  const ProviderServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: JourneySubHeader(title: ''),
          ),
          Expanded(child: ProviderServicesTab()),
        ],
      ),
    );
  }
}
