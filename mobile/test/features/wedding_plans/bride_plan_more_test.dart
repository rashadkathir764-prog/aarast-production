import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/widgets/provider_trust_signals.dart';
import 'package:aarast_mobile/features/sharing/models/plan_role_permissions.dart';
import 'package:aarast_mobile/features/sharing/widgets/participant_access_editor.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/plan_details_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

// The bride's plan, sharing and providers (bride_profile/out w10, g06, f02):
// the same screens in her rose and spoken to her as a woman.

Future<void> _pump(
  WidgetTester tester,
  JourneyProfile profile,
  Widget child,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: JourneyProfileScope(
        profile: profile,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _details() => PlanDetailsView(
  plan: WeddingPlan(
    id: 'plan-1',
    ownerUserId: 'u1',
    title: 'عرس سلمى',
    weddingDate: DateTime(2027, 1, 21),
    currency: 'YER',
    status: 'PLANNING',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  budgetTotal: '3000000.00',
  onBack: () {},
  onSave: ({title, firstDay, budgetTotal}) async => true,
  onChangeDate: () {},
  onArchive: () {},
);

Widget _editor() => ParticipantAccessEditor(
  role: 'VIEWER',
  permissions: PlanRolePermissions.forRole('VIEWER'),
  onPresetSelected: (_) {},
  onChanged: (_) {},
);

void main() {
  testWidgets('w10: her plan details speak to her', (tester) async {
    await _pump(tester, JourneyProfile.bride, _details());

    expect(find.text('غيّري الموعد'), findsOneWidget);
    expect(find.text('حطي الخطة في الأرشيف'), findsOneWidget);
    expect(
      find.text(
        'لو غيّرتِ الموعد، المهام تنتقل معه، والدفعات تبقى على مواعيدها.',
      ),
      findsOneWidget,
    );
    expect(find.text('غيّر الموعد'), findsNothing);
  });

  testWidgets('w10: the groom keeps his words', (tester) async {
    await _pump(tester, JourneyProfile.groom, _details());

    expect(find.text('غيّر الموعد'), findsOneWidget);
    expect(find.text('حط الخطة في الأرشيف'), findsOneWidget);
  });

  testWidgets('g06: her sharing levels are in rose and spoken to her', (
    tester,
  ) async {
    await _pump(tester, JourneyProfile.bride, _editor());

    final icon = tester.widget<Icon>(find.byIcon(LucideIcons.listChecks));
    expect(icon.color, JourneyAccent.bride.primary);
    // D80: what every participant reads, spoken to her.
    expect(find.textContaining('القسم اللي تفتحينه له'), findsOneWidget);
    expect(find.text('الضيفات'), findsOneWidget);
  });

  testWidgets('g06: his sharing levels stay teal', (tester) async {
    await _pump(tester, JourneyProfile.groom, _editor());

    final icon = tester.widget<Icon>(find.byIcon(LucideIcons.listChecks));
    expect(icon.color, JourneyAccent.groom.primary);
    expect(find.textContaining('القسم اللي تفتحه له'), findsOneWidget);
  });

  test('f02: an old price asks her to check it', () {
    final now = DateTime(2026, 10, 24);
    final old = now.subtract(const Duration(days: 120));
    expect(
      priceAgeLine(old, now, profile: JourneyProfile.bride),
      endsWith('تأكدي منه لما تطلبين العرض'),
    );
    expect(priceAgeLine(old, now), endsWith('تأكد منه لما تطلب العرض'));
  });
}
