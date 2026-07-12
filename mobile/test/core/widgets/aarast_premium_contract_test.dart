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
      ];

      for (final path in requiredFiles) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
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

    test('keeps production colors routed through Soft Royal tokens', () {
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

    test('routes every production screen through Premium 2027 wrappers', () {
      // كل شاشة موجهة في التطبيق — لا شاشة خارج المستوى الفاخر الموحّد.
      // ملفات export الخالصة وقشرة الـ ShellRoute خارج القائمة عمداً.
      const screenFiles = [
        'lib/features/auth/screens/splash_screen.dart',
        'lib/features/auth/screens/login_screen.dart',
        'lib/features/auth/screens/register_screen.dart',
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
        'lib/features/wedding_plans/screens/create_wedding_plan_screen.dart',
        'lib/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart',
        'lib/features/wedding_plans/screens/plan_management_screen.dart',
        'lib/features/finance/screens/budget_expense_screen.dart',
        'lib/features/finance/screens/budget_setup_screen.dart',
        'lib/features/finance/screens/budget_category_details_screen.dart',
        'lib/features/finance/screens/create_budget_category_screen.dart',
        'lib/features/finance/screens/create_expense_screen.dart',
        'lib/features/finance/screens/create_financial_commitment_screen.dart',
        'lib/features/finance/screens/financial_commitment_details_screen.dart',
        'lib/features/finance/screens/financial_payables_screen.dart',
        'lib/features/finance/screens/financial_payment_record_details_screen.dart',
        'lib/features/finance/screens/expenses_screen.dart',
        'lib/features/finance/screens/record_payment_screen.dart',
        'lib/features/tasks/screens/task_timeline_screen.dart',
        'lib/features/tasks/screens/create_task_screen.dart',
        'lib/features/guests/screens/guest_list_screen.dart',
        'lib/features/sharing/screens/sharing_screen.dart',
        'lib/features/sharing/screens/add_shared_member_screen.dart',
        'lib/features/sharing/screens/edit_shared_member_screen.dart',
        'lib/features/sharing/screens/invite_decision_screen.dart',
        'lib/features/sharing/screens/shared_wedding_plans_screen.dart',
        'lib/features/marketplace/screens/provider_marketplace_screen.dart',
        'lib/features/marketplace/screens/provider_details_screen.dart',
        'lib/features/marketplace/screens/quote_request_screen.dart',
        'lib/features/marketplace/screens/provider_apply_screen.dart',
        'lib/features/marketplace/screens/provider_portal_screen.dart',
        'lib/features/marketplace/screens/add_provider_service_screen.dart',
        'lib/features/marketplace/screens/add_provider_package_screen.dart',
        'lib/features/marketplace/screens/edit_provider_profile_screen.dart',
        'lib/features/marketplace/screens/favorite_providers_screen.dart',
        'lib/features/notifications/screens/notifications_screen.dart',
        'lib/features/more/screens/more_screen.dart',
        'lib/features/settings/screens/settings_screen.dart',
        'lib/features/support/screens/support_screen.dart',
      ];

      final premiumWrapperPattern = RegExp(
        r'Aarast(ScreenFrame|PageScaffold|Scaffold)|'
        r'AuthWeddingScaffold|GuestOnboardingStepScaffold',
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
          premiumWrapperPattern.hasMatch(text),
          isTrue,
          reason: '$path must render through the Premium 2027 system',
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
      // حالة التحميل الفاخرة إلزامية: AarastSkeleton للجسم،
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

    test('documents Soft Royal Wedding as the final mobile identity', () {
      final identityPlan = File('../docs/frontend/DESIGN_SYSTEM.md');
      final auditMatrix = File('../docs/frontend/PREMIUM_ROADMAP.md');

      expect(identityPlan.existsSync(), isTrue);
      expect(auditMatrix.existsSync(), isTrue);

      final identityText = identityPlan.readAsStringSync();
      expect(identityText, contains('Aarast Design System And Tokens'));
      expect(identityText, contains('dashboard is the visual source of truth'));
      expect(identityText, contains('aarast_design_tokens.dart'));
      expect(identityText, contains('Arabic-first'));
      expect(identityText, contains('Financially trustworthy'));

      final docs = [
        File('../docs/frontend/DESIGN_SYSTEM.md'),
        File('../docs/frontend/PREMIUM_ROADMAP.md'),
      ];

      for (final doc in docs) {
        final text = doc.readAsStringSync();
        expect(text, contains('Premium'), reason: doc.path);
      }
    });

    test(
      'keeps a Phase A audit matrix for the highest-risk mobile screens',
      () {
        final text = File(
          '../docs/frontend/PREMIUM_ROADMAP.md',
        ).readAsStringSync();

        for (final expected in [
          'more_screen.dart',
          'budget_expense_screen',
          'plan_center_screen.dart',
          'provider_dashboard_screen.dart',
          'sharing_screen.dart',
          'create_financial_commitment_screen.dart',
        ]) {
          expect(text, contains(expected), reason: expected);
        }

        expect(text, contains('Definition of Done'));
        expect(text, contains('المرحلة أ'));
      },
    );
  });
}
