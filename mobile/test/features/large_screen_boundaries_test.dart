import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guest list keeps form state behind an independent widget boundary', () {
    final screen = _read('lib/features/guests/screens/guest_list_screen.dart');
    final form = _read('lib/features/guests/widgets/guest_form_sheet.dart');

    expect(_lineCount(screen), lessThanOrEqualTo(1000));
    expect(screen, contains('GuestFormSheet('));
    expect(screen, contains('GuestFormResult'));
    expect(screen, contains('GuestSheetHandle'));
    expect(screen, isNot(contains('TextEditingController')));

    for (final forbidden in [
      'GuestsProvider',
      'GuestsApi',
      'AuthActionGuard',
      'go_router',
    ]) {
      expect(form, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('provider details keeps orchestration outside presentation widgets', () {
    final screen = _read(
      'lib/features/marketplace/screens/provider_details_screen.dart',
    );
    final view = _read(
      'lib/features/marketplace/widgets/provider_details_view.dart',
    );
    final sections = _read(
      'lib/features/marketplace/widgets/provider_details_sections.dart',
    );

    expect(_lineCount(screen), lessThanOrEqualTo(350));
    expect(screen, contains('ProviderDetailsView('));
    for (final extractedClass in [
      'class _ProviderHero',
      'class _AboutCard',
      'class _ServicesSection',
      'class _PackagesSection',
      'class _ReviewsSection',
    ]) {
      expect(screen, isNot(contains(extractedClass)), reason: extractedClass);
    }

    final presentation = '$view\n$sections';
    for (final forbidden in [
      'ProviderMarketplaceProvider',
      'AuthActionGuard',
      'AppRouter',
      'go_router',
      'context.push',
      'context.read',
      'context.watch',
    ]) {
      expect(presentation, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('more screen keeps flows outside its presentation components', () {
    final screen = _read('lib/features/more/screens/more_screen.dart');
    final components = _read(
      'lib/features/more/widgets/more_screen_components.dart',
    );

    expect(_lineCount(screen), lessThanOrEqualTo(600));
    expect(screen, contains('MoreIdentitySummary.from'));
    expect(screen, contains('showAarastBottomSheet'));
    expect(screen, contains('AuthActionGuard'));
    expect(screen, contains('AppRouter'));
    for (final extractedClass in [
      'class _IdentitySummary',
      'class _ProfileCard',
      'class _MenuGroup',
      'class _MoreActionTile',
      'class _DangerGroup',
    ]) {
      expect(screen, isNot(contains(extractedClass)), reason: extractedClass);
    }

    for (final forbidden in [
      'Provider',
      'AuthActionGuard',
      'AppRouter',
      'go_router',
      'context.push',
      'context.read',
      'context.watch',
    ]) {
      expect(components, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('smart dashboard barrel keeps responsibility files bounded', () {
    final barrel = _read(
      'lib/features/wedding_plans/widgets/premium/smart_dashboard_cards.dart',
    );
    const files = [
      'smart_dashboard_models.dart',
      'aarast_next_action_card.dart',
      'aarast_setup_journey_card.dart',
      'aarast_pulse_row.dart',
      'aarast_participants_glance_card.dart',
      'aarast_money_glance_card.dart',
    ];

    expect(_lineCount(barrel), lessThanOrEqualTo(20));
    for (final name in files) {
      expect(barrel, contains("export '$name';"), reason: name);
      final source = _read('lib/features/wedding_plans/widgets/premium/$name');
      expect(_lineCount(source), lessThanOrEqualTo(500), reason: name);
      for (final forbidden in [
        'Provider',
        'AuthActionGuard',
        'AppRouter',
        'go_router',
        'context.push',
        'context.read',
        'context.watch',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: '$name: $forbidden');
      }
    }
  });

  test('create task keeps orchestration outside presentation components', () {
    final screen = _read('lib/features/tasks/screens/create_task_screen.dart');
    final components = _read(
      'lib/features/tasks/widgets/create_task_components.dart',
    );

    expect(_lineCount(screen), lessThanOrEqualTo(700));
    expect(screen, contains('CreateTaskResponsibleSection('));
    expect(screen, contains('AuthActionGuard'));
    expect(screen, contains('TaskTimelineProvider'));
    expect(screen, contains('AppRouter'));
    for (final extractedClass in [
      'class _TaskHero',
      'class _ResponsibleSection',
      'class _ParticipantRow',
      'class _SelectorField',
      'class _PriorityChip',
      'class _CategoryRow',
    ]) {
      expect(screen, isNot(contains(extractedClass)), reason: extractedClass);
    }

    expect(_lineCount(components), lessThanOrEqualTo(550));
    for (final forbidden in [
      'TaskTimelineProvider',
      'SharingProvider',
      'AuthController',
      'AuthActionGuard',
      'AppRouter',
      'go_router',
      'context.push',
      'context.read',
      'context.watch',
    ]) {
      expect(components, isNot(contains(forbidden)), reason: forbidden);
    }
  });
}

String _read(String relativePath) {
  return File('${_mobileRoot()}$relativePath').readAsStringSync();
}

int _lineCount(String source) => '\n'.allMatches(source).length + 1;

String _mobileRoot() {
  final cwd = Directory.current.path;
  if (cwd.endsWith('${Platform.pathSeparator}mobile') ||
      cwd.endsWith('/mobile')) {
    return '$cwd${Platform.pathSeparator}';
  }
  return '$cwd${Platform.pathSeparator}mobile${Platform.pathSeparator}';
}
