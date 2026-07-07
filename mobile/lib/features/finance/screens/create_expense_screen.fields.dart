part of 'create_expense_screen.dart';

class _SelectorField extends StatelessWidget {
  const _SelectorField({
    required this.label,
    required this.value,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppTheme.burgundy : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.burgundy : AppTheme.gold),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppTheme.muted),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronDown, color: AppTheme.muted),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AarastCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        color: selected ? AppTheme.burgundySoft : AppTheme.surface,
        border: Border.all(
          color: selected ? AppTheme.burgundy : AppTheme.border,
        ),
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.burgundy : AppTheme.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: selected ? AppTheme.burgundy : AppTheme.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (selected)
              const Icon(LucideIcons.checkCircle, color: AppTheme.burgundy),
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

FormFieldValidator<String> _required(String message) {
  return (value) => value == null || value.trim().isEmpty ? message : null;
}

FormFieldValidator<String> _positiveRequired(String message) {
  return (value) {
    final rawValue = value?.trim() ?? '';
    final parsed = _moneyValue(rawValue);
    if (parsed == null || parsed <= 0) return message;
    return null;
  };
}

String _formatDate(DateTime date) {
  return formatArabicCompactDate(date);
}

num? _moneyValue(String? value) {
  final clean = value?.replaceAll(',', '').trim() ?? '';
  if (clean.isEmpty) return null;
  return num.tryParse(clean);
}
