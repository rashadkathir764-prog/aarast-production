import re

filepath = r"d:\projects\aarast\mobile\lib\features\wedding_plans\widgets\new_dashboard_widgets.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# I will find the InkResponse block and replace everything until the end of the class.
pattern = r"return InkResponse\(\s*onTap: onTap,\s*radius: 36,\s*child: SizedBox\(\s*width: 60,.*?\)\s*:\s*content,\s*\),\s*\);\s*\}\s*\}"

replacement = """return InkResponse(
      onTap: onTap,
      radius: 36,
      child: SizedBox(
        width: 60,
        child: content,
      ),
    );
  }
}"""

content = re.sub(pattern, replacement, content, flags=re.DOTALL)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Syntax fixed")
