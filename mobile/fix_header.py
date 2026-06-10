import re

filepath = r"d:\projects\aarast\mobile\lib\features\wedding_plans\widgets\new_dashboard_widgets.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

pattern = r"class NewDashboardTopHeader extends StatelessWidget \{.*?\n\s*\}\n"

new_header = """class NewDashboardTopHeader extends StatelessWidget {
  const NewDashboardTopHeader({
    required this.userName,
    this.onProfile,
    this.onNotifications,
    this.hasNotificationDot = true,
    super.key,
  });

  final String userName;
  final VoidCallback? onProfile;
  final VoidCallback? onNotifications;
  final bool hasNotificationDot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Greeting and Logo (Right side in RTL)
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _BrandMark(),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'مساء الخير، ${userName.split(' ').first}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.dInk,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('🤎', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Action icons (Left side in RTL)
          Row(
            children: [
              _IconButton(
                icon: Icons.notifications_none_rounded,
                onTap: onNotifications,
                showDot: hasNotificationDot,
                badgeCount: '3',
              ),
              const SizedBox(width: 10),
              _IconButton(
                icon: Icons.person_outline_rounded,
                onTap: onProfile,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
"""

content = re.sub(pattern, new_header, content, flags=re.DOTALL)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Header fixed!")
