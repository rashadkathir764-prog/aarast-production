import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';

/// What the provider wrote for the service he joins with.
typedef ProviderJoiningServiceInput = ({
  String title,
  String price,
  String about,
});

/// «خدمتك وسعرها» in a sheet (p09, B-10): before approval the provider
/// fixes only the name, the price and the words of the service he joined
/// with, or adds it when his profile has none. [onSave] says why it was not
/// saved, or null once saved.
Future<void> showProviderJoiningServiceSheet(
  BuildContext context, {
  required String? title,
  required String? price,
  required String? about,
  required String? note,
  required Future<String?> Function(ProviderJoiningServiceInput input) onSave,
}) {
  return showJourneySheet<void>(
    context: context,
    builder: (_) => _JoiningServiceSheet(
      title: title,
      price: price,
      about: about,
      note: note,
      onSave: onSave,
    ),
  );
}

class _JoiningServiceSheet extends StatefulWidget {
  const _JoiningServiceSheet({
    required this.title,
    required this.price,
    required this.about,
    required this.note,
    required this.onSave,
  });

  final String? title;
  final String? price;
  final String? about;
  final String? note;
  final Future<String?> Function(ProviderJoiningServiceInput input) onSave;

  @override
  State<_JoiningServiceSheet> createState() => _JoiningServiceSheetState();
}

class _JoiningServiceSheetState extends State<_JoiningServiceSheet> {
  late final _title = TextEditingController(text: widget.title ?? '');
  late final _price = TextEditingController(text: _wholeAmount(widget.price));
  late final _about = TextEditingController(text: widget.about ?? '');
  bool _attempted = false;
  bool _saving = false;
  String? _error;

  /// The stored amount («150000.00») as the digits the field takes.
  static String _wholeAmount(String? amount) {
    final whole = (amount ?? '').trim().split('.').first;
    return RegExp(r'^\d+$').hasMatch(whole) && whole != '0' ? whole : '';
  }

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _about.dispose();
    super.dispose();
  }

  bool get _valid =>
      _title.text.trim().length >= 2 &&
      (int.tryParse(_price.text.trim()) ?? 0) > 0;

  Future<void> _save() async {
    if (!_valid) {
      setState(() => _attempted = true);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave((
      title: _title.text.trim(),
      price: _price.text.trim(),
      about: _about.text.trim(),
    ));
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    return JourneySheetBody(
      title: 'خدمتك وسعرها',
      subtitle: 'تقدر تعدّل اسمها وسعرها وايش تشمل لين نوافق.',
      children: [
        if (note != null) ...[
          JourneyNote(
            text: note,
            icon: LucideIcons.messageSquare,
            color: AarastV3Color.danger,
            soft: AarastV3Color.dangerSoft,
          ),
          const SizedBox(height: 10),
        ],
        JourneyTextField(
          key: const Key('provider-service-sheet-title'),
          label: 'اسم الخدمة',
          controller: _title,
          textInputAction: TextInputAction.next,
          errorText: _attempted && _title.text.trim().length < 2
              ? 'اكتب اسم خدمتك'
              : null,
          onChanged: (_) {
            if (_attempted) setState(() {});
          },
        ),
        const SizedBox(height: 10),
        JourneyTextField(
          key: const Key('provider-service-sheet-price'),
          label: 'السعر',
          controller: _price,
          suffix: 'ر.ي',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.next,
          errorText: _attempted && (int.tryParse(_price.text.trim()) ?? 0) <= 0
              ? 'اكتب سعر خدمتك'
              : null,
          onChanged: (_) {
            if (_attempted) setState(() {});
          },
        ),
        const SizedBox(height: 10),
        JourneyTextField(
          key: const Key('provider-service-sheet-about'),
          label: 'ايش تشمل (اختياري)',
          controller: _about,
          textInputAction: TextInputAction.done,
          minLines: 2,
          maxLines: 4,
        ),
        if (_error case final error?) ...[
          const SizedBox(height: 10),
          JourneyNote(
            key: const Key('provider-service-sheet-error'),
            text: error,
            icon: LucideIcons.alertCircle,
            color: AarastV3Color.danger,
            soft: AarastV3Color.dangerSoft,
          ),
        ],
        const SizedBox(height: 14),
        JourneyButton(
          key: const Key('provider-service-sheet-save'),
          label: 'احفظ',
          expand: true,
          large: true,
          loading: _saving,
          onPressed: _save,
        ),
      ],
    );
  }
}
