import re

filepath = r"d:\projects\aarast\mobile\lib\features\wedding_plans\widgets\new_dashboard_widgets.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Add a helper function for SnackBar to new_dashboard_widgets.dart if it doesn't exist
snackbar_helper = """void _showComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('هذه الميزة قريباً! 🚀')),
  );
}"""

if "_showComingSoon" not in content:
    # Insert it right before class _QuickActionBtn
    content = content.replace("class _QuickActionBtn extends", snackbar_helper + "\n\nclass _QuickActionBtn extends")

# Replace empty onTaps with _showComingSoon(context) in NewDashboardQuickActions
# We need to make sure we replace the ones inside NewDashboardQuickActions
quick_actions_block_pattern = r"(class NewDashboardQuickActions extends StatelessWidget \{.*?\n\s*\})"
match = re.search(quick_actions_block_pattern, content, re.DOTALL)
if match:
    block = match.group(1)
    # Replace onTap: () {}, with onTap: () => _showComingSoon(context),
    block = block.replace("onTap: () {}", "onTap: () => _showComingSoon(context)")
    content = content[:match.start()] + block + content[match.end():]

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Dashboard buttons activated!")
