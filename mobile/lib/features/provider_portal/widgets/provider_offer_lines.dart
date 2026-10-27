import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../marketplace/marketplace_api.dart' show QuoteOfferLine;

/// B-07: «يشمل · ما يشمل · إضافة» lines of an offer, and its delivery days
/// (B-23). The customer reads them under the price.
class ProviderOfferLinesEditor extends StatefulWidget {
  const ProviderOfferLinesEditor({
    required this.lines,
    required this.onChanged,
    super.key,
  });

  final List<QuoteOfferLine> lines;
  final ValueChanged<List<QuoteOfferLine>> onChanged;

  @override
  State<ProviderOfferLinesEditor> createState() =>
      _ProviderOfferLinesEditorState();
}

const _kindWords = {
  'INCLUDED': 'يشمل',
  'EXCLUDED': 'ما يشمل',
  'EXTRA': 'إضافة',
};

class _ProviderOfferLinesEditorState extends State<ProviderOfferLinesEditor> {
  final _label = TextEditingController();
  final _amount = TextEditingController();
  String _kind = 'INCLUDED';
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _add() {
    final label = _label.text.trim();
    final amount = _amount.text.trim().replaceAll(',', '');
    if (label.isEmpty) {
      setState(() => _error = 'اكتب السطر.');
      return;
    }
    if (_kind == 'EXTRA' &&
        amount.isNotEmpty &&
        (num.tryParse(amount) == null || num.parse(amount) <= 0)) {
      setState(() => _error = 'سعر الإضافة رقم أكبر من صفر.');
      return;
    }
    widget.onChanged([
      ...widget.lines,
      QuoteOfferLine(
        label: label,
        kind: _kind,
        amount: _kind == 'EXTRA' && amount.isNotEmpty ? amount : null,
      ),
    ]);
    _label.clear();
    _amount.clear();
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('provider-offer-lines'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'تفاصيل العرض',
          style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < widget.lines.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                JourneyTag(
                  label: _kindWords[widget.lines[index].kind] ?? '',
                  color: widget.lines[index].isExcluded
                      ? AarastV3Color.danger
                      : AarastV3Color.mint,
                  soft: widget.lines[index].isExcluded
                      ? AarastV3Color.dangerSoft
                      : AarastV3Color.mintSoft,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    [
                      widget.lines[index].label,
                      ?widget.lines[index].amount,
                    ].join(' · '),
                    style: JourneyType.of(JourneyType.body),
                  ),
                ),
                IconButton(
                  key: Key('provider-offer-line-remove-$index'),
                  tooltip: 'شيل السطر',
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () => widget.onChanged([
                    for (var i = 0; i < widget.lines.length; i++)
                      if (i != index) widget.lines[i],
                  ]),
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 8,
          children: [
            for (final kind in _kindWords.keys)
              JourneyChip(
                key: Key('provider-offer-line-kind-$kind'),
                label: _kindWords[kind]!,
                selected: _kind == kind,
                onTap: () => setState(() => _kind = kind),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: JourneyTextField(
                key: const Key('provider-offer-line-label'),
                label: 'مثل: ألبوم 40 صورة',
                controller: _label,
                errorText: _error,
              ),
            ),
            if (_kind == 'EXTRA') ...[
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: JourneyTextField(
                  key: const Key('provider-offer-line-amount'),
                  label: 'سعرها',
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: JourneyTextAction(
            key: const Key('provider-offer-line-add'),
            label: 'أضف السطر',
            icon: LucideIcons.plus,
            onPressed: _add,
          ),
        ),
      ],
    );
  }
}

/// B-23: the delivery promise after the wedding (none, a week, two weeks, a
/// month, two months).
const providerOfferDeliveryChoices = [null, 7, 14, 30, 60];

String providerOfferDeliveryLabel(int? days) => switch (days) {
  null => 'بدون',
  7 => 'أسبوع',
  14 => 'أسبوعين',
  30 => 'شهر',
  60 => 'شهرين',
  _ => '$days يوم',
};
