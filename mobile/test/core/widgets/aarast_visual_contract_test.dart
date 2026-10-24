import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Iterable<File> _productionScreenFiles() sync* {
  final root = Directory('lib/features');
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('_screen.dart')) continue;
    final text = entity.readAsStringSync().trimLeft();
    if (text.startsWith('export ')) continue;
    yield entity;
  }
}

List<String> _iconButtonsWithoutTooltips(File file) {
  final text = file.readAsStringSync();
  final matches = RegExp(
    r'(^|[^\w])IconButton\s*\(',
    multiLine: true,
  ).allMatches(text);
  final offenders = <String>[];

  for (final match in matches) {
    final open = text.indexOf('(', match.start);
    var depth = 0;
    var end = open;
    for (; end < text.length; end += 1) {
      final char = text[end];
      if (char == '(') depth += 1;
      if (char == ')') {
        depth -= 1;
        if (depth == 0) break;
      }
    }
    final call = text.substring(open, end + 1);
    if (!call.contains('tooltip:')) {
      final line = '\n'.allMatches(text.substring(0, match.start)).length + 1;
      offenders.add('${file.path}:$line');
    }
  }
  return offenders;
}

void main() {
  group('Aarast mobile visual production contract', () {
    test('keeps the official design system files in place', () {
      const requiredFiles = [
        'lib/core/experience_v3/aarast_v3_adaptive.dart',
        'lib/core/experience_v3/aarast_v3_content.dart',
        'lib/core/theme/aarast_design_tokens.dart',
        'lib/core/theme/aarast_theme.dart',
        'lib/core/theme/aarast_motion.dart',
        'lib/core/widgets/aarast_scaffold.dart',
        'lib/core/widgets/aarast_screen_frame.dart',
        'lib/core/widgets/aarast_app_bar.dart',
        'lib/core/widgets/aarast_card.dart',
        'lib/core/widgets/aarast_button.dart',
        'lib/core/widgets/aarast_section_header.dart',
        'lib/core/widgets/aarast_empty_state.dart',
        'lib/core/widgets/aarast_loading_state.dart',
        'lib/core/widgets/aarast_error_state.dart',
        'lib/core/widgets/aarast_status_badge.dart',
        'lib/core/widgets/aarast_bottom_sheet.dart',
        'lib/core/widgets/aarast_dialog.dart',
        'lib/core/widgets/aarast_metric_tile.dart',
        'lib/core/widgets/aarast_pressable.dart',
        'lib/core/widgets/aarast_surface.dart',
      ];

      for (final path in requiredFiles) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('keeps the adaptive route contract mounted at app level', () {
      final app = File('lib/app.dart').readAsStringSync();
      final adaptive = File(
        'lib/core/experience_v3/aarast_v3_adaptive.dart',
      ).readAsStringSync();

      expect(app, contains('AarastV3AdaptiveExperienceShell'));
      expect(adaptive, contains('class AarastV3ScreenContract'));
      expect(adaptive, contains('class AarastV3ExperienceScope'));
      expect(adaptive, contains('class AarastV3AttentionSurface'));
      expect(adaptive, contains('class AarastV3StateSurface'));
    });

    test(
      'does not allow direct Material Card usage in production features',
      () {
        final roots = [Directory('lib/features'), Directory('lib/shared')];
        final offenders = <String>[];

        for (final root in roots.where((directory) => directory.existsSync())) {
          for (final entity in root.listSync(recursive: true)) {
            if (entity is! File || !entity.path.endsWith('.dart')) continue;
            final lines = entity.readAsLinesSync();
            for (var index = 0; index < lines.length; index += 1) {
              final line = lines[index];
              final hasRawCardCall = RegExp(r'(^|[^\w])Card\(').hasMatch(line);
              if (hasRawCardCall) {
                offenders.add('${entity.path}:${index + 1}: ${line.trim()}');
              }
            }
          }
        }

        expect(offenders, isEmpty, reason: offenders.join('\n'));
      },
    );

    test('keeps production colors routed through shared theme tokens', () {
      final roots = [
        Directory('lib/features'),
        Directory('lib/shared'),
        Directory('lib/core/widgets'),
      ];
      final rawHex = RegExp(r'Color\(0x');
      final rawSemanticColor = RegExp(
        r'Colors\.(red|green|blue|orange|purple|pink|brown|grey|gray|black)',
      );
      final localColorClass = RegExp(r'class\s+\w*Colors\b|_\w+Colors\b');
      final offenders = <String>[];

      for (final root in roots.where((directory) => directory.existsSync())) {
        for (final entity in root.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final lines = entity.readAsLinesSync();
          for (var index = 0; index < lines.length; index += 1) {
            final line = lines[index];
            if (rawHex.hasMatch(line) ||
                rawSemanticColor.hasMatch(line) ||
                localColorClass.hasMatch(line)) {
              offenders.add('${entity.path}:${index + 1}: ${line.trim()}');
            }
          }
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('bans production gradients and decorative shadows', () {
      final roots = [Directory('lib')];
      final decoration = RegExp(
        r'LinearGradient|RadialGradient|SweepGradient|BoxShadow\s*\(',
      );
      final offenders = <String>[];

      for (final root in roots.where((directory) => directory.existsSync())) {
        for (final entity in root.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final lines = entity.readAsLinesSync();
          for (var index = 0; index < lines.length; index += 1) {
            if (decoration.hasMatch(lines[index])) {
              offenders.add(
                '${entity.path}:${index + 1}: ${lines[index].trim()}',
              );
            }
          }
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('retires Premium and Royal vocabulary from production source', () {
      final retiredVocabulary = RegExp(
        r'\b(?:premium|royal)\b',
        caseSensitive: false,
      );
      final offenders = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is Directory &&
            retiredVocabulary.hasMatch(entity.path.replaceAll('\\', '/'))) {
          offenders.add(entity.path);
          continue;
        }
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (retiredVocabulary.hasMatch(entity.path.replaceAll('\\', '/'))) {
          offenders.add(entity.path);
        }
        final lines = entity.readAsLinesSync();
        for (var index = 0; index < lines.length; index += 1) {
          if (retiredVocabulary.hasMatch(lines[index])) {
            offenders.add(
              '${entity.path}:${index + 1}: ${lines[index].trim()}',
            );
          }
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('keeps all production icons on the Lucide design language', () {
      final rawMaterialIcon = RegExp(r'(?<![A-Za-z0-9_])Icons\.[A-Za-z0-9_]+');
      final offenders = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var index = 0; index < lines.length; index += 1) {
          for (final match in rawMaterialIcon.allMatches(lines[index])) {
            offenders.add('${entity.path}:${index + 1}: ${match.group(0)}');
          }
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('routes feature dialogs through AarastDialog', () {
      final roots = [Directory('lib/features'), Directory('lib/shared')];
      final offenders = <String>[];

      for (final root in roots.where((directory) => directory.existsSync())) {
        for (final entity in root.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final lines = entity.readAsLinesSync();
          for (var index = 0; index < lines.length; index += 1) {
            if (RegExp(
              r'(^|[^A-Za-z0-9_])AlertDialog\s*\(',
            ).hasMatch(lines[index])) {
              offenders.add('${entity.path}:${index + 1}');
            }
          }
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('routes transient feedback through AarastToast', () {
      final roots = [Directory('lib/features'), Directory('lib/shared')];
      final offenders = <String>[];

      for (final root in roots.where((directory) => directory.existsSync())) {
        for (final entity in root.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final lines = entity.readAsLinesSync();
          for (var index = 0; index < lines.length; index += 1) {
            if (RegExp(
              r'(^|[^A-Za-z0-9_])SnackBar\s*\(',
            ).hasMatch(lines[index])) {
              offenders.add('${entity.path}:${index + 1}');
            }
          }
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('routes feature sheets through showAarastBottomSheet', () {
      final roots = [Directory('lib/features'), Directory('lib/shared')];
      final offenders = <String>[];

      for (final root in roots.where((directory) => directory.existsSync())) {
        for (final entity in root.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final lines = entity.readAsLinesSync();
          for (var index = 0; index < lines.length; index += 1) {
            if (lines[index].contains('showModalBottomSheet')) {
              offenders.add('${entity.path}:${index + 1}');
            }
          }
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    // D30: a journey sheet takes its canvas, radius, handle and title from
    // showJourneySheet and JourneySheetBody, never from the call site.
    test('journey sheets take their shell from the kit', () {
      // A sheet call whose arguments, before its builder, pick the journey
      // canvas or a drag handle by hand.
      final handMade = RegExp(
        r'showAarastBottomSheet<[^>]*>\((?:(?!builder:)[\s\S])*?'
        r'(showDragHandle|AarastV3Color\.canvas)',
      );
      final offenders = <String>[];
      for (final root in [Directory('lib/features'), Directory('lib/shared')]) {
        for (final entity in root.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final text = entity.readAsStringSync();
          for (final match in handMade.allMatches(text)) {
            final line = '\n'.allMatches(text.substring(0, match.start)).length;
            offenders.add('${entity.path}:${line + 1}');
          }
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('routes every production screen through shared shell wrappers', () {
      // كل شاشة موجهة في التطبيق — لا شاشة خارج نظام V3 الموحّد.
      // ملفات export الخالصة وقشرة الـ ShellRoute خارج القائمة عمداً.
      const screenFiles = [
        'lib/features/account_contexts/screens/account_context_selection_screen.dart',
        'lib/features/auth/screens/splash_screen.dart',
        'lib/features/auth/screens/login_screen.dart',
        'lib/features/auth/screens/register_screen.dart',
        'lib/features/auth/screens/provider_register_screen.dart',
        'lib/features/auth/screens/otp_screen.dart',
        'lib/features/auth/screens/reset_password_screen.dart',
        'lib/features/chat/screens/chat_screen.dart',
        'lib/features/chat/screens/quote_conversation_entry_screen.dart',
        'lib/features/home/screens/dashboard_entry_screen.dart',
        'lib/features/home/screens/home_screen.dart',
        'lib/features/home/screens/local_guest_dashboard_screen.dart',
        'lib/features/onboarding/screens/local_plan_migration_screen.dart',
        'lib/features/welcome_gateway/screens/smart_welcome_screen.dart',
        'lib/features/wedding_plans/screens/my_wedding_plans_screen.dart',
        'lib/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart',
        'lib/features/wedding_plans/screens/plan_management_screen.dart',
        'lib/features/wedding_plans/screens/plan_assistant_screen.dart',
        'lib/features/wedding_plans/screens/participant_home_screen.dart',
        'lib/features/shell/screens/participant_locked_screen.dart',
        'lib/features/finance/screens/money_overview_screen.dart',
        'lib/features/finance/screens/money_budget_screen.dart',
        'lib/features/finance/screens/budget_category_details_screen.dart',
        'lib/features/finance/screens/budget_category_form_screen.dart',
        'lib/features/finance/screens/cost_form_screen.dart',
        'lib/features/finance/screens/cost_details_screen.dart',
        'lib/features/finance/screens/funding_sources_screen.dart',
        'lib/features/finance/screens/money_receipts_screen.dart',
        'lib/features/tasks/screens/task_timeline_screen.dart',
        'lib/features/tasks/screens/participant_tasks_screen.dart',
        'lib/features/tasks/screens/task_details_screen.dart',
        'lib/features/tasks/screens/create_task_screen.dart',
        'lib/features/guests/screens/guest_list_screen.dart',
        'lib/features/guests/screens/guest_attendance_screen.dart',
        'lib/features/guests/screens/guest_details_screen.dart',
        'lib/features/guests/screens/guest_import_screen.dart',
        'lib/features/guests/screens/guest_invite_screen.dart',
        'lib/features/wedding_day/screens/wedding_day_mode_screen.dart',
        'lib/features/sharing/screens/sharing_screen.dart',
        'lib/features/sharing/screens/contribution_history_screen.dart',
        'lib/features/sharing/screens/edit_shared_member_screen.dart',
        'lib/features/sharing/screens/invite_decision_screen.dart',
        'lib/features/sharing/screens/from_family_screen.dart',
        'lib/features/sharing/screens/participant_plan_state_screen.dart',
        'lib/features/marketplace/screens/provider_marketplace_screen.dart',
        'lib/features/marketplace/screens/provider_requests_screen.dart',
        'lib/features/marketplace/screens/provider_details_screen.dart',
        'lib/features/marketplace/screens/quote_request_screen.dart',
        'lib/features/provider_portal/screens/provider_apply_screen.dart',
        'lib/features/provider_portal/screens/provider_claim_screen.dart',
        'lib/features/provider_portal/screens/provider_portal_screen.dart',
        'lib/features/provider_portal/screens/provider_pending_screen.dart',
        'lib/features/provider_portal/screens/provider_approved_screen.dart',
        'lib/features/provider_portal/screens/provider_suspended_screen.dart',
        'lib/features/provider_portal/screens/provider_changes_screen.dart',
        'lib/features/provider_portal/screens/provider_rejected_screen.dart',
        'lib/features/provider_portal/screens/provider_request_screen.dart',
        'lib/features/provider_portal/screens/provider_booking_screen.dart',
        'lib/features/provider_portal/screens/provider_notifications_screen.dart',
        'lib/features/provider_portal/screens/provider_offer_screen.dart',
        'lib/features/provider_portal/screens/provider_services_screen.dart',
        'lib/features/provider_portal/screens/provider_gallery_screen.dart',
        'lib/features/provider_portal/screens/provider_performance_screen.dart',
        'lib/features/provider_portal/screens/provider_settings_screen.dart',
        'lib/features/provider_portal/screens/provider_share_screen.dart',
        'lib/features/provider_portal/screens/add_provider_service_screen.dart',
        'lib/features/provider_portal/screens/add_provider_package_screen.dart',
        'lib/features/provider_portal/screens/edit_provider_profile_screen.dart',
        'lib/features/marketplace/screens/booking_moment_screen.dart',
        'lib/features/marketplace/screens/favorite_providers_screen.dart',
        'lib/features/marketplace/screens/plan_bookings_screen.dart',
        'lib/features/marketplace/screens/provider_reviews_screen.dart',
        'lib/features/notifications/screens/notifications_screen.dart',
        'lib/features/more/screens/more_screen.dart',
        'lib/features/settings/screens/lock_settings_screen.dart',
        'lib/features/settings/screens/settings_screen.dart',
        'lib/features/support/screens/support_screen.dart',
      ];

      final sharedWrapperPattern = RegExp(
        r'Aarast(ScreenFrame|PageScaffold|Scaffold)|'
        r'AuthWeddingScaffold|GuestOnboardingStepScaffold|'
        r'PlanShellChrome|AarastDashboardView',
      );

      final discovered =
          _productionScreenFiles()
              .map((file) => file.path.replaceAll('\\', '/'))
              .toList()
            ..sort();
      final declared = [...screenFiles]..sort();
      expect(
        declared,
        discovered,
        reason: 'The production-screen contract must cover every screen file.',
      );

      for (final path in screenFiles) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: path);
        final text = file.readAsStringSync();
        expect(
          sharedWrapperPattern.hasMatch(text),
          isTrue,
          reason: '$path must render through the shared Aarast shell system',
        );
      }
    });

    test('gives every production IconButton an accessible tooltip', () {
      final offenders = _productionScreenFiles()
          .expand(_iconButtonsWithoutTooltips)
          .toList();

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('uses accessible pressable primitives instead of raw gestures', () {
      final offenders = <String>[];
      for (final file in _productionScreenFiles()) {
        final lines = file.readAsLinesSync();
        for (var index = 0; index < lines.length; index += 1) {
          if (lines[index].contains('GestureDetector(')) {
            offenders.add('${file.path}:${index + 1}');
          }
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('does not expose implementation placeholders to users', () {
      final placeholderCopy = RegExp(
        r'عند ربط نظام الملفات|رفع الصور سيظهر لاحق',
      );
      final offenders = <String>[];
      for (final file in _productionScreenFiles()) {
        final lines = file.readAsLinesSync();
        for (var index = 0; index < lines.length; index += 1) {
          if (placeholderCopy.hasMatch(lines[index])) {
            offenders.add('${file.path}:${index + 1}');
          }
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('keeps domain forms decision-led and sensitive auth forms ephemeral', () {
      final domainFormFiles = Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.replaceAll('\\', '/').contains('/auth/'))
          // A Flutter Form widget, not names ending in «Form» such as
          // PaymentEntryForm.
          .where(
            (file) => RegExp(r'\bForm\(').hasMatch(file.readAsStringSync()),
          )
          .toList(growable: false);
      final missingPrompt = domainFormFiles
          .where(
            (file) => !file.readAsStringSync().contains('AarastV3FocusPrompt'),
          )
          .map((file) => file.path)
          .toList(growable: false);
      expect(missingPrompt, isEmpty, reason: missingPrompt.join('\n'));

      const durableDraftFiles = [
        'lib/features/finance/screens/budget_category_form_screen.dart',
        'lib/features/finance/screens/cost_form_screen.dart',
        'lib/features/finance/screens/money_budget_screen.dart',
        // c07: an agreement's payment date is added or changed in its sheet.
        'lib/features/finance/widgets/payment_schedule_sheet.dart',
        // c06: both payment screens share this journey form.
        'lib/features/finance/widgets/payment_entry_form.dart',
        'lib/features/guests/widgets/guest_form_sheet.dart',
        'lib/features/provider_portal/screens/add_provider_package_screen.dart',
        'lib/features/provider_portal/screens/add_provider_service_screen.dart',
        'lib/features/provider_portal/screens/edit_provider_profile_screen.dart',
        'lib/features/provider_portal/screens/provider_apply_screen.dart',
        'lib/features/marketplace/screens/quote_request_screen.dart',
        // g06: «أضف مشارك» is a sheet over the participants list.
        'lib/features/sharing/widgets/add_participant_sheet.dart',
        'lib/features/tasks/screens/create_task_screen.dart',
      ];
      for (final path in durableDraftFiles) {
        final text = File(path).readAsStringSync();
        expect(
          text.contains('AarastFormDraftBinding') ||
              text.contains('AarastFormDraftCoordinator'),
          isTrue,
          reason: '$path must preserve unfinished non-sensitive values',
        );
        // The journey look pins its save button under the scrolling fields
        // instead of the older action bar.
        const journeySaveKeys = {
          'payment_entry_form.dart': 'payment-save',
          'payment_schedule_sheet.dart': 'schedule-save',
          'cost_form_screen.dart': 'cost-save',
          'budget_category_form_screen.dart': 'category-save',
          'money_budget_screen.dart': 'money-budget-save',
          'create_task_screen.dart': 'task-save',
          'quote_request_screen.dart': 'quote-send',
          'add_participant_sheet.dart': 'participant-send',
          'provider_apply_screen.dart': 'provider-apply-send',
        };
        final journeySave = journeySaveKeys.entries
            .where((entry) => path.endsWith(entry.key))
            .map((entry) => entry.value)
            .firstOrNull;
        if (journeySave != null) {
          expect(
            text,
            contains(
              RegExp(
                "JourneyButton\\(\\s*key: const ValueKey\\('$journeySave'\\)",
              ),
            ),
            reason: '$path must keep its primary action reachable on phones',
          );
        } else if (!path.endsWith('guest_form_sheet.dart')) {
          expect(
            text,
            contains('AarastV3FormActionBar'),
            reason: '$path must keep its primary action reachable on phones',
          );
        }
      }

      for (final file
          in Directory('lib/features/auth/screens')
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))) {
        expect(
          file.readAsStringSync(),
          isNot(contains('AarastFormDraft')),
          reason: '${file.path} must never persist passwords or OTP values',
        );
      }
    });

    test(
      'keeps every production screen covered by an explicit widget test',
      () {
        final testSource = Directory('test')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))
            .map((file) => file.readAsStringSync())
            .join('\n');
        final classPattern = RegExp(r'class\s+(\w+Screen)\s+extends');
        final offenders = <String>[];

        for (final file in _productionScreenFiles()) {
          final match = classPattern.firstMatch(file.readAsStringSync());
          if (match == null) continue;
          final className = match.group(1)!;
          if (!testSource.contains(className)) {
            offenders.add('${file.path}: $className');
          }
        }

        expect(offenders, isEmpty, reason: offenders.join('\n'));
      },
    );

    test('bans raw CircularProgressIndicator outside the design system', () {
      // حالة التحميل الموحّدة إلزامية: AarastSkeleton للجسم،
      // AarastButton.isLoading أو AarastInlineSpinner للأزرار.
      final roots = [Directory('lib/features'), Directory('lib/shared')];
      final offenders = <String>[];

      for (final root in roots.where((directory) => directory.existsSync())) {
        for (final entity in root.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final lines = entity.readAsLinesSync();
          for (var index = 0; index < lines.length; index += 1) {
            if (lines[index].contains('CircularProgressIndicator')) {
              offenders.add('${entity.path}:${index + 1}');
            }
          }
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('routes feature progress through the shared V3 progress line', () {
      final roots = [Directory('lib/features'), Directory('lib/shared')];
      final offenders = <String>[];

      for (final root in roots.where((directory) => directory.existsSync())) {
        for (final entity in root.listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final lines = entity.readAsLinesSync();
          for (var index = 0; index < lines.length; index += 1) {
            if (lines[index].contains('LinearProgressIndicator')) {
              offenders.add('${entity.path}:${index + 1}');
            }
          }
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('does not allow legacy screen shell primitives in routed screens', () {
      final root = Directory('lib/features');
      final offenders = <String>[];
      final directScaffold = RegExp(r'(^|[^\w])Scaffold\(');
      final rawMaterialCard = RegExp(r'(^|[^\w])Card\(');

      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('_screen.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var index = 0; index < lines.length; index += 1) {
          final line = lines[index];
          if (directScaffold.hasMatch(line) ||
              rawMaterialCard.hasMatch(line) ||
              line.contains('PrimaryActionButton') ||
              line.contains('primary_action_button.dart')) {
            offenders.add('${entity.path}:${index + 1}: ${line.trim()}');
          }
        }
      }

      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('documents the modern semantic mobile identity', () {
      final designContract = File('../docs/frontend/DESIGN_SYSTEM.md');

      expect(designContract.existsSync(), isTrue);

      final text = designContract.readAsStringSync();
      for (final expected in [
        '# Aarast Adaptive Experience System V3',
        '## Product Direction',
        '## Source Of Truth',
        '`canvas`',
        '`paper`',
        '`primary`',
        'Every routed view must answer without guessing',
        'the one primary action',
        '320px',
        'RTL is the composition default',
      ]) {
        expect(text, contains(expected), reason: expected);
      }

      for (final retired in [
        'dashboard is the visual source of truth',
        'RoyalDashboardBottomNav',
        'RoyalSmartFloatingActionButton',
        'active premium roadmap',
      ]) {
        expect(text, isNot(contains(retired)), reason: retired);
      }
    });

    test('keeps the retired premium roadmap out of active documentation', () {
      final retiredRoadmap = File('../docs/frontend/PREMIUM_ROADMAP.md');
      final archivedRoadmap = File(
        '../docs/archive/2026-08-modernization-consolidation/frontend/'
        'PREMIUM_ROADMAP.md.txt',
      );

      expect(retiredRoadmap.existsSync(), isFalse);
      expect(archivedRoadmap.existsSync(), isTrue);
    });
  });
}
