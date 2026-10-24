part of 'budget_category_details_screen.dart';

/// What the item was given, what was agreed and what was paid.
class _CategorySummary extends StatelessWidget {
  const _CategorySummary({required this.category, required this.plain});

  final BudgetCategory category;
  final String Function(num value) plain;

  @override
  Widget build(BuildContext context) {
    final allocated = moneyValue(category.allocatedAmount);
    final agreed = moneyValue(category.confirmedCost);
    final paid = moneyValue(category.paid);
    final ratio = agreed <= 0 ? 0.0 : (paid / agreed).clamp(0.0, 1.0);
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
          Text(
            value,
            style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
          ),
        ],
      ),
    );
    return JourneyBox(
      key: const ValueKey('category-summary'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            context.say('حطيت له', 'حطيتِ له'),
            category.allocatedAmount == null
                ? context.say('ما حددت', 'ما حددتِ')
                : plain(allocated),
          ),
          row(context.say('اتفقت على', 'اتفقتِ على'), plain(agreed)),
          row(context.say('دفعت', 'دفعتِ'), plain(paid)),
          row('باقي عليك', plain(moneyValue(category.outstanding))),
          if (agreed > 0) ...[
            const SizedBox(height: 8),
            JourneyBar(value: ratio, color: context.accent.primary),
          ],
        ],
      ),
    );
  }
}

/// w18: the item went over what it was given.
class _OverCard extends StatelessWidget {
  const _OverCard({
    required this.over,
    required this.agreed,
    required this.allocated,
  });

  final String over;
  final String agreed;
  final String allocated;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('category-over'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AarastV3Color.danger, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                LucideIcons.alertTriangle,
                size: 20,
                color: AarastV3Color.danger,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'زادت $over عن المحطوط',
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
                    weight: JourneyType.bold,
                    color: AarastV3Color.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              '$agreed من $allocated',
              style: JourneyType.of(
                JourneyType.display,
                weight: JourneyType.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const JourneyBar(value: 1, color: AarastV3Color.danger),
        ],
      ),
    );
  }
}

/// w18's ways out: grow the budget by what it went over, take it from
/// another item, or leave it (the warning then stays).
class _OverChoices extends StatelessWidget {
  const _OverChoices({
    required this.over,
    required this.overLabel,
    required this.budgetAfter,
    required this.onGrow,
    required this.onMove,
  });

  final num over;
  final String overLabel;
  final String budgetAfter;
  final VoidCallback onGrow;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneyChoiceCard(
          key: const ValueKey('category-over-grow'),
          title: '${context.say('زِد', 'زيدي')} الميزانية $overLabel',
          subtitle: 'تصير ميزانية عرسك $budgetAfter',
          leading: Icon(LucideIcons.trendingUp, color: context.accent.primary),
          onTap: onGrow,
        ),
        const SizedBox(height: 8),
        JourneyChoiceCard(
          key: const ValueKey('category-over-move'),
          title: context.say('خذها من بند ثاني', 'خذيها من بند ثاني'),
          subtitle: context.say(
            'تنقص من بند ما احتاج كل اللي حطيته له',
            'تنقص من بند ما احتاج كل اللي حطيتيه له',
          ),
          leading: Icon(
            LucideIcons.arrowLeftRight,
            color: context.accent.primary,
          ),
          onTap: onMove,
        ),
        const SizedBox(height: 8),
        Text(
          '${context.say('لو خليتها', 'لو خليتيها')} كذا، المجموع يطلع فوق الميزانية بـ $overLabel.',
          style: JourneyType.of(
            JourneyType.small,
            color: AarastV3Color.textMuted,
          ),
        ),
      ],
    );
  }
}

class _CategoryMenu extends StatelessWidget {
  const _CategoryMenu({required this.onEdit, required this.onRemove});

  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<bool>(
      key: const ValueKey('money-category-overflow'),
      tooltip: 'إجراءات البند',
      icon: const Icon(LucideIcons.moreHorizontal),
      onSelected: (edit) => edit ? onEdit() : onRemove(),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: true,
          child: Row(
            children: [
              Icon(LucideIcons.pencil, size: 18),
              SizedBox(width: 10),
              Flexible(child: Text('تعديل البند')),
            ],
          ),
        ),
        PopupMenuItem(
          key: const ValueKey('money-category-remove'),
          value: false,
          child: Row(
            children: [
              const Icon(
                LucideIcons.trash2,
                size: 18,
                color: AarastV3Color.danger,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  context.say('شيل البند', 'شيلي البند'),
                  style: const TextStyle(color: AarastV3Color.danger),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _RemoveChoice { remove, keepWithoutAmount }

/// x15 «تشيل بند …؟». Removing is a hard delete today («ينحذف البند»), and
/// its share goes back to the reserve (C15), not out of the budget.
class _RemoveCategorySheet extends StatefulWidget {
  const _RemoveCategorySheet({
    required this.name,
    required this.agreements,
    required this.allocated,
  });

  final String name;
  final int agreements;

  /// What the item was given, or null when nothing.
  final String? allocated;

  @override
  State<_RemoveCategorySheet> createState() => _RemoveCategorySheetState();
}

class _RemoveCategorySheetState extends State<_RemoveCategorySheet> {
  _RemoveChoice _choice = _RemoveChoice.remove;

  @override
  Widget build(BuildContext context) {
    final blocked = widget.agreements > 0;
    return JourneySheetBody(
      title: blocked
          ? '${context.say('ما تقدر تشيل', 'ما تقدرين تشيلين')} ${widget.name}'
          : '${context.say('تشيل', 'تشيلين')} بند ${widget.name}؟',
      subtitle: blocked
          ? 'عليه ${arabicCount(widget.agreements, one: 'اتفاق واحد', two: 'اتفاقين', few: 'اتفاقات', many: 'اتفاق')}. ${context.say('شيلها أو انقلها', 'شيليها أو انقليها')} لبند ثاني أول.'
          : widget.allocated == null
          ? context.say('ما حطيت له مبلغ', 'ما حطيتِ له مبلغ')
          : '${context.say('حطيت', 'حطيتِ')} له ${widget.allocated}، وما عليه اتفاقات',
      children: [
        if (!blocked) ...[
          if (widget.allocated != null) ...[
            JourneyBox(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.wallet,
                    size: 18,
                    color: context.accent.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'يرجع ${widget.allocated} للاحتياط',
                      style: JourneyType.of(
                        JourneyType.body,
                        weight: JourneyType.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          JourneyChoiceCard(
            key: const ValueKey('category-remove-delete'),
            title: context.say('شيله', 'شيليه'),
            subtitle: 'ينحذف البند',
            leading: const Icon(
              LucideIcons.trash2,
              color: AarastV3Color.danger,
            ),
            selected: _choice == _RemoveChoice.remove,
            onTap: () => setState(() => _choice = _RemoveChoice.remove),
          ),
          if (widget.allocated != null) ...[
            const SizedBox(height: 8),
            JourneyChoiceCard(
              key: const ValueKey('category-remove-keep'),
              title: context.say('خلّه، بس بدون مبلغ', 'خلّيه، بس بدون مبلغ'),
              subtitle: 'لو بتتكفل فيه العائلة مثلًا',
              leading: Icon(
                LucideIcons.minusCircle,
                color: context.accent.primary,
              ),
              selected: _choice == _RemoveChoice.keepWithoutAmount,
              onTap: () =>
                  setState(() => _choice = _RemoveChoice.keepWithoutAmount),
            ),
          ],
          const SizedBox(height: 14),
        ],
        JourneyButton(
          key: const ValueKey('category-remove-confirm'),
          label: blocked
              ? 'تمام'
              : _choice == _RemoveChoice.remove
              ? context.say('شيل البند', 'شيلي البند')
              : context.say('خلّه بدون مبلغ', 'خلّيه بدون مبلغ'),
          background: !blocked && _choice == _RemoveChoice.remove
              ? AarastV3Color.danger
              : context.accent.primary,
          expand: true,
          large: true,
          onPressed: () => Navigator.pop(context, blocked ? null : _choice),
        ),
      ],
    );
  }
}
