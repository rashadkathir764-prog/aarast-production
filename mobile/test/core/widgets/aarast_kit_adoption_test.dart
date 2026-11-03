import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The rule behind DESIGN_SYSTEM.md's "one field, one button" (D74, DS-06).
//
// Feature code builds forms and actions from the journey kit
// (JourneyTextField, JourneyPickerField, JourneyButton, JourneyTextAction,
// JourneyListRow). A raw Material field, button, dropdown, list tile or app
// bar outside the kit draws a second look of the same thing, and a compact
// tap target breaks the 48 rule. The files that still do so are listed here
// with their counts; a count may only go down, and no file may join the list.

const _kitPaths = {
  'lib/core/experience_v3/',
  'lib/core/theme/',
  'lib/core/widgets/aarast_button.dart',
  'lib/core/widgets/aarast_dialog.dart',
  'lib/core/widgets/aarast_bottom_sheet.dart',
};

final _rawWidgets = RegExp(
  r'(?<![\w.])(?:'
  r'TextField|TextFormField|FilledButton|TextButton|OutlinedButton|'
  r'ElevatedButton|DropdownButton(?:FormField)?|DropdownMenu|ListTile|AppBar'
  r')(?:<[^()]*>)?(?:\.icon|\.tonal)?\s*\(',
);
final _compactTargets = RegExp(
  r'MaterialTapTargetSize\.shrinkWrap|VisualDensity\.compact',
);

String _withoutComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'^\s*//.*$', multiLine: true), '');

/// Raw Material widgets and compact tap targets written in [source].
int rawKitBypasses(String source) {
  final text = _withoutComments(source);
  return _rawWidgets.allMatches(text).length +
      _compactTargets.allMatches(text).length;
}

/// Files that still bypass the kit, with how many times. Shrinks only.
const _baseline = <String, int>{
  'lib/app.dart': 1,
  'lib/core/contacts/contact_picker_service.dart': 1,
  'lib/core/offline/offline_status_widgets.dart': 2,
  'lib/core/routing/app_router.dart': 2,
  'lib/core/widgets/aarast_error_state.dart': 1,
  'lib/core/widgets/aarast_otp_field.dart': 1,
  'lib/core/widgets/aarast_share_sheet.dart': 1,
  'lib/core/widgets/aarast_toast.dart': 2,
  'lib/core/widgets/aarast_ui.dart': 1,
  'lib/features/auth/utils/auth_action_guard.dart': 4,
  'lib/features/auth/widgets/auth_wedding_widgets.dart': 3,
  'lib/features/chat/screens/chat_screen.dart': 2,
  'lib/features/finance/screens/funding_sources_screen.dart': 2,
  'lib/features/finance/widgets/receipt_flows.dart': 5,
  'lib/features/guests/widgets/guest_groups_sheet.dart': 5,
  'lib/features/marketplace/screens/provider_marketplace_screen.sections.dart': 1,
  'lib/features/notifications/screens/notifications_screen.dart': 1,
  'lib/features/provider_portal/screens/add_provider_package_screen.dart': 6,
  'lib/features/provider_portal/screens/add_provider_service_screen.dart': 7,
  'lib/features/provider_portal/screens/edit_provider_profile_screen.dart': 4,
  'lib/features/support/screens/support_screen.dart': 2,
  'lib/features/tasks/screens/create_task_screen_privacy.dart': 2,
  'lib/features/wedding_plans/screens/plan_assistant_screen.dart': 1,
  'lib/shared/widgets/contact_phone_field.dart': 4,
};

Map<String, int> _liveCounts() {
  final counts = <String, int>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (_kitPaths.any(path.startsWith)) continue;
    final count = rawKitBypasses(entity.readAsStringSync());
    if (count > 0) counts[path] = count;
  }
  return counts;
}

void main() {
  group('raw kit bypasses', () {
    test('counts raw fields, buttons, tiles and compact targets', () {
      expect(rawKitBypasses('TextField(controller: c)'), 1);
      expect(rawKitBypasses('TextFormField(\n  decoration: d,\n)'), 1);
      expect(rawKitBypasses('FilledButton.tonal(onPressed: f)'), 1);
      expect(rawKitBypasses('TextButton.icon(onPressed: f)'), 1);
      expect(rawKitBypasses('DropdownButtonFormField<String>('), 1);
      expect(rawKitBypasses('DropdownButton<String>('), 1);
      expect(rawKitBypasses('ListTile(title: t)'), 1);
      expect(rawKitBypasses('AppBar(title: t)'), 1);
      expect(rawKitBypasses('tapTargetSize: MaterialTapTargetSize.shrinkWrap'), 1);
      expect(rawKitBypasses('visualDensity: VisualDensity.compact'), 1);
    });

    test('leaves the kit, comments and other names alone', () {
      expect(rawKitBypasses('JourneyTextField(label: l)'), 0);
      expect(rawKitBypasses('JourneyButton(label: l)'), 0);
      expect(rawKitBypasses('// TextField(controller: c)'), 0);
      expect(rawKitBypasses('AarastButton(label: l)'), 0);
      expect(rawKitBypasses('theme.textButtonTheme'), 0);
    });
  });

  test('no feature file adds a raw field, button, tile, app bar or compact '
      'target, and the listed ones only shrink', () {
    final live = _liveCounts();
    final grew = <String>[];
    for (final entry in live.entries) {
      final allowed = _baseline[entry.key];
      if (allowed == null || entry.value > allowed) {
        grew.add('${entry.key}: ${entry.value} (allowed ${allowed ?? 0})');
      }
    }
    expect(
      grew,
      isEmpty,
      reason:
          'Use JourneyTextField, JourneyPickerField, JourneyButton, '
          'JourneyTextAction or JourneyListRow (DESIGN_SYSTEM.md, D74). '
          'A listed file may only lower its count.',
    );
    final cleaned = [
      for (final entry in _baseline.entries)
        if ((live[entry.key] ?? 0) < entry.value)
          '${entry.key}: ${live[entry.key] ?? 0} (listed ${entry.value})',
    ];
    expect(
      cleaned,
      isEmpty,
      reason: 'The file got cleaner: lower or remove its entry in _baseline.',
    );
  });
}
