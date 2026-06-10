import pathlib
import re

path = pathlib.Path('mobile/lib/features/wedding_plans/widgets/new_dashboard_widgets.dart')
content = path.read_text(encoding='utf-8')

content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:flutter/foundation.dart';\nimport 'dart:io';\nimport 'package:google_fonts/google_fonts.dart';")
content = content.replace('final VoidCallback onPlans;', 'final VoidCallback onVendors;')
content = re.sub(r'CustomPaint\([^)]*painter: _RingsPainter\(\)[^)]*\)', 'const Icon(Icons.favorite, color: AppTheme.dMaroon)', content)

# Remove the duplicates!
# Find the start of the duplicated DashboardTopBar (the one we appended earlier at the end)
idx1 = content.find('Future<void> showAccountSheet')
if idx1 != -1:
    idx2 = content.find('Future<void> showAccountSheet', idx1 + 10)
    if idx2 != -1:
        content = content[:idx2]

path.write_text(content, encoding='utf-8')
