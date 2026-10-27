part of 'aarast_dashboard_view.dart';

// G23 «ايش ناقص»: the six things the owner named, from the server's reading
// of the plan's money items. Shown while one of them is still open; each row
// opens the money, where the item is.

class _JourneyEssentials extends StatelessWidget {
  const _JourneyEssentials({required this.essentials, required this.onOpen});

  final List<DashboardEssential> essentials;
  final VoidCallback onOpen;

  static bool shows(List<DashboardEssential> essentials) => essentials.any(
    (item) => item.status == DashboardEssentialStatus.missing,
  );

  @override
  Widget build(BuildContext context) {
    final rows = essentials
        .where((item) => item.status != DashboardEssentialStatus.none)
        .toList();
    final open = rows.where((item) => !item.isSettled).length;
    return Column(
      key: const ValueKey('aarast-dashboard-essentials'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneySectionTitle(
          open == 1 ? 'باقي شي واحد أساسي' : 'ايش ناقص · $open من ${rows.length}',
        ),
        JourneyBox(
          padding: EdgeInsets.zero,
          child: JourneyList(
            children: [
              for (final item in rows)
                JourneyListRow(
                  key: ValueKey('aarast-dashboard-essential-${item.key}'),
                  icon: _icon(item.key),
                  color: item.isSettled
                      ? AarastV3Color.mint
                      : context.accent.primary,
                  soft: item.isSettled
                      ? AarastV3Color.mintSoft
                      : context.accent.primarySoft,
                  title: _title(context, item.key),
                  subtitle: switch (item.status) {
                    DashboardEssentialStatus.booked => 'محجوز',
                    DashboardEssentialStatus.agreed => 'متفق عليه',
                    _ => context.say('ما اتفقت بعد', 'ما اتفقتِ بعد'),
                  },
                  trailing: Icon(
                    item.isSettled ? LucideIcons.check : LucideIcons.chevronLeft,
                    size: 18,
                    color: item.isSettled
                        ? AarastV3Color.mint
                        : AarastV3Color.textFaint,
                  ),
                  onTap: onOpen,
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _title(BuildContext context, String key) => switch (key) {
    'VENUE' => context.planWord('القاعة', 'الصالة'),
    'DRESS' => context.planWord('البدلة والكسوة', 'الفستان'),
    'PHOTO' => 'التصوير',
    'GOLD' => 'الذهب والشبكة',
    'HOME' => 'الشقة وتجهيز المنزل',
    'HONEYMOON' => 'شهر العسل',
    _ => key,
  };

  static IconData _icon(String key) => switch (key) {
    'VENUE' => LucideIcons.building2,
    'DRESS' => LucideIcons.shirt,
    'PHOTO' => LucideIcons.camera,
    'GOLD' => LucideIcons.gem,
    'HOME' => LucideIcons.home,
    'HONEYMOON' => LucideIcons.plane,
    _ => LucideIcons.circle,
  };
}
