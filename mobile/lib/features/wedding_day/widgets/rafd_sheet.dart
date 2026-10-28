import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/amount_words.dart';
import '../../../core/widgets/aarast_pressable.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/rafd.dart';
import '../providers/rafd_provider.dart';

/// b06 «سجّل رفد» (the bride's «سجّلي هدية»): who and how much, kept on the
/// phone at once and sent when the network allows (D66). The sheet stays
/// open for the next one.
Future<void> showRafdSheet(
  BuildContext context, {
  required String weddingPlanId,
  required RafdProvider provider,
}) {
  return showJourneySheet<void>(
    context: context,
    builder: (_) =>
        RafdSheet(weddingPlanId: weddingPlanId, provider: provider),
  );
}

class RafdSheet extends StatefulWidget {
  const RafdSheet({
    required this.weddingPlanId,
    required this.provider,
    super.key,
  });

  final String weddingPlanId;
  final RafdProvider provider;

  @override
  State<RafdSheet> createState() => _RafdSheetState();
}

class _RafdSheetState extends State<RafdSheet> {
  final _name = TextEditingController();
  int _amount = 0;
  String? _error;
  String? _saved;
  bool _saving = false;

  static const _quick = [5000, 10000, 20000, 50000];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _setAmount(int value) {
    if (value > rafdMaxAmount) return;
    setState(() {
      _amount = value;
      _error = null;
    });
  }

  void _digit(int digit) => _setAmount(_amount * 10 + digit);

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _amount <= 0) {
      setState(
        () => _error = name.isEmpty
            ? context.say('اكتب اسم اللي رفدك', 'اكتبي اسم اللي أهدتك')
            : context.say('اكتب كم', 'اكتبي كم'),
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.provider.record(
        widget.weddingPlanId,
        giverName: name,
        amount: _amount,
      );
      if (!mounted) return;
      _name.clear();
      setState(() {
        _saved = '${context.say('انحفظ', 'انحفظت')} · $name · ${groupedAmount(_amount)}';
        _amount = 0;
        _saving = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;
    final gift = context.planWord('رفد', 'هدية');
    return JourneySheetBody(
      title: '${context.say('سجّل', 'سجّلي')} $gift',
      subtitle: 'ينحفظ في جوالك، ويوصل لما يرجع النت',
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error case final error?) ...[
            JourneyNote(
              text: error,
              icon: LucideIcons.alertCircle,
              color: AarastV3Color.danger,
              soft: AarastV3Color.dangerSoft,
            ),
            const SizedBox(height: 8),
          ] else if (_saved case final saved?) ...[
            JourneyNote(
              key: const ValueKey('rafd-saved'),
              text: saved,
              icon: LucideIcons.checkCircle,
              color: AarastV3Color.mint,
              soft: AarastV3Color.mintSoft,
            ),
            const SizedBox(height: 8),
          ],
          JourneyButton(
            key: const ValueKey('rafd-save'),
            label: context.say('حفظ وسجّل التالي', 'حفظ وسجّلي التالي'),
            background: AarastV3Color.saffron,
            foreground: AarastV3Color.ink,
            expand: true,
            large: true,
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      children: [
        JourneyTextField(
          key: const ValueKey('rafd-name'),
          label: 'من؟',
          controller: _name,
          icon: LucideIcons.user,
          hint: context.planWord('عبدالله الحمدي', 'عبير الحمدي'),
          maxLength: 80,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 10),
        Container(
          key: const ValueKey('rafd-amount'),
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
          decoration: BoxDecoration(
            color: AarastV3Color.paper,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.primary, width: 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'كم؟',
                      style: JourneyType.of(
                        JourneyType.label,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                    Text(
                      _amount == 0 ? '0' : groupedAmount(_amount),
                      style: JourneyType.of(
                        JourneyType.count,
                        weight: JourneyType.bold,
                      ),
                    ),
                    if (_amount > 0)
                      Text(
                        amountInWords(_amount),
                        style: JourneyType.of(
                          JourneyType.bodySmall,
                          weight: JourneyType.bold,
                          color: accent.primary,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                'ر.ي',
                style: JourneyType.of(
                  JourneyType.lead,
                  color: AarastV3Color.textMuted,
                ),
              ),
              IconButton(
                key: const ValueKey('rafd-backspace'),
                tooltip: 'امسح رقم',
                onPressed: _amount == 0 ? null : () => _setAmount(_amount ~/ 10),
                icon: const Icon(LucideIcons.delete, size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in _quick)
              JourneyChip(
                key: ValueKey('rafd-quick-$value'),
                label: groupedAmount(value),
                selected: _amount == value,
                onTap: () => _setAmount(value),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _Keypad(
          onDigit: _digit,
          onThousand: () => _setAmount((_amount == 0 ? 1 : _amount) * 1000),
          onMillion: () => _setAmount((_amount == 0 ? 1 : _amount) * 1000000),
        ),
      ],
    );
  }
}

/// b06's keypad: the digits, and «ألف» and «مليون» that multiply.
class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onThousand,
    required this.onMillion,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onThousand;
  final VoidCallback onMillion;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, VoidCallback onTap, {bool unit = false}) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: AarastPressable(
              key: ValueKey('rafd-key-$label'),
              onTap: onTap,
              semanticLabel: label,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: unit ? context.accent.primarySoft : AarastV3Color.paper,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  label,
                  style: JourneyType.of(
                    JourneyType.title,
                    weight: JourneyType.bold,
                    color: unit ? context.accent.primary : AarastV3Color.ink,
                  ),
                ),
              ),
            ),
          ),
        );
    Widget digit(int value) => key('$value', () => onDigit(value));
    return Column(
      children: [
        Row(
          children: [
            key('ألف', onThousand, unit: true),
            digit(3),
            digit(2),
            digit(1),
          ],
        ),
        Row(
          children: [
            key('مليون', onMillion, unit: true),
            digit(6),
            digit(5),
            digit(4),
          ],
        ),
        Row(children: [digit(0), digit(9), digit(8), digit(7)]),
      ],
    );
  }
}
