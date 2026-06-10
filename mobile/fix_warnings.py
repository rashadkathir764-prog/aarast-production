import re

filepath = r"d:\projects\aarast\mobile\lib\features\wedding_plans\widgets\new_dashboard_widgets.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix withOpacity -> withAlpha or withValues
# Dart 3.7 deprecates withOpacity, suggests withValues. But withAlpha is also safe. Let's use withValues(alpha: ...)
content = content.replace('withOpacity(0.3)', 'withValues(alpha: 0.3)')
content = content.replace('withOpacity(0.1)', 'withValues(alpha: 0.1)')
content = content.replace('withOpacity(0.4)', 'withValues(alpha: 0.4)')
content = content.replace('withOpacity(0.2)', 'withValues(alpha: 0.2)')

# Fix unnecessary string interpolation
content = content.replace("'${formatNumber(budgetTotal)}'", "formatNumber(budgetTotal)")

# Fix unused _HeroMetaRow (remove it)
content = re.sub(r'class _HeroMetaRow extends StatelessWidget \{.*?\n\}\n', '', content, flags=re.DOTALL)

# Fix unused variables (pendingTasks, dueInstallments, debtsTotal, obligations)
content = re.sub(r'\s*final pendingTasks = .*?;', '', content)
content = re.sub(r'\s*final dueInstallments = .*?;', '', content)
content = re.sub(r'\s*final debtsTotal = .*?;', '', content)
content = re.sub(r'\s*final obligations = .*?;', '', content)

# Fix unused spark parameter (line 1598) - let's find it.
# It's probably in a custom painter.
content = re.sub(r',\s*bool spark = false', '', content)
content = re.sub(r'bool spark = false,', '', content)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Warnings fixed")
