// Visual preview harness for the Aarast dashboard. Renders the real dashboard
// widgets in the same compact snapshot layout used by WeddingPlanDashboardScreen,
// with mock data, and writes golden PNGs so the layout/scaling can be inspected
// without a backend or browser.
//
// Regenerate the images with:
//   flutter test test/dashboard_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/aarast_dashboard_widgets.dart';

const double _designWidth = 843;

Widget _padded(Widget child) =>
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: child);

Widget _scaledCanvas(Widget child) {
  return LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _designWidth),
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
            child: SizedBox(width: _designWidth, child: child),
          ),
        ),
      ),
    ),
  );
}

Widget _quickActions() {
  return QuickActionsCard(
    actions:
        const [
              QuickAction(
                icon: Icons.account_balance_wallet_outlined,
                label: 'إضافة مصروف',
                color: AppTheme.burgundy,
                bg: AppTheme.dangerSoft,
              ),
              QuickAction(
                icon: Icons.credit_card_rounded,
                label: 'إضافة دين',
                color: AppTheme.burgundy,
                bg: AppTheme.dangerSoft,
              ),
              QuickAction(
                icon: Icons.check_circle_outline_rounded,
                label: 'إضافة مهمة',
                color: AppTheme.success,
                bg: AppTheme.successSoft,
              ),
              QuickAction(
                icon: Icons.person_add_alt_1_rounded,
                label: 'إضافة عضو',
                color: AppTheme.info,
                bg: AppTheme.infoSoft,
              ),
              QuickAction(
                icon: Icons.post_add_rounded,
                label: 'خطة جديدة',
                color: AppTheme.gold,
                bg: AppTheme.pearl,
              ),
            ]
            .map(
              (a) => QuickAction(
                icon: a.icon,
                label: a.label,
                color: a.color,
                bg: a.bg,
                onTap: () {},
              ),
            )
            .toList(),
  );
}

Widget _content() {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DashboardTopBar(
        userName: 'رشاد',
        onProfile: () {},
        onNotifications: () {},
      ),
      const DashboardHeroCard(
        title: 'خطة زفاف رشاد',
        statusLabel: 'قيد التخطيط',
        tasksDone: 3,
        tasksTotal: 10,
        city: 'صنعاء',
        // No weddingDate -> avoids the 1s countdown Timer in the test harness.
      ),
      const SizedBox(height: 18),
      _padded(
        const DashboardSnapshotRow(
          totalBudget: 1000000,
          spent: 50000,
          currency: 'YER',
          tasksDone: 3,
          tasksTotal: 10,
          vendorCount: 12,
          paymentCount: 8,
          guestCount: 246,
        ),
      ),
      const SizedBox(height: 18),
      _padded(_quickActions()),
      const SizedBox(height: 18),
      _padded(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ParticipantsCard(
                    count: 2,
                    onAddMember: () {},
                    participants: const [
                      ParticipantInfo(
                        name: 'مستخدم مشارك',
                        roleLabel: 'مدير',
                        isManager: true,
                        phone: '777700001',
                      ),
                      ParticipantInfo(
                        name: 'أحمد علي',
                        roleLabel: 'مساهم',
                        isManager: false,
                        phone: '777700002',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SharedPlansCard(subtitle: '1 خطة مشتركة', onOpen: () {}),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AlertsCard(
                onViewAll: () {},
                alerts: const [
                  DashboardAlert(
                    title: 'قسط قريب الاستحقاق',
                    body: 'لديك قسط بقيمة 100,000 YER يستحق خلال 3 أيام',
                    icon: Icons.calendar_today_outlined,
                    tone: AlertTone.pink,
                  ),
                  DashboardAlert(
                    title: 'مصروفات مرتفعة',
                    body: 'لقد وصلت المصروفات إلى 5% من إجمالي الميزانية',
                    icon: Icons.trending_up_rounded,
                    tone: AlertTone.cream,
                  ),
                  DashboardAlert(
                    title: 'مهمة قريبة',
                    body: 'تأكيد حجز القاعة بتاريخ 13 يونيو 2026',
                    icon: Icons.checklist_rounded,
                    tone: AlertTone.green,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
    ],
  );
}

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.ivory,
          body: _scaledCanvas(_content()),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('dashboard — full design width (843)', (tester) async {
    await _pumpAt(tester, const Size(900, 1700));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/dashboard_full.png'),
    );
  });

  testWidgets('dashboard — narrow phone width (420)', (tester) async {
    await _pumpAt(tester, const Size(420, 1700));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/dashboard_phone.png'),
    );
  });
}
