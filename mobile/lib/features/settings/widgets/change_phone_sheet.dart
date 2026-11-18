import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/forms/latin_digits_formatter.dart';

/// g09 «تغيير رقم الجوال», a journey sheet from «حسابي»: the number now, the
/// new one, and a code on WhatsApp to the new number. Confirming moves the
/// account and signs out every device, this one too, so the next sign-in is
/// with the new number. The plan and its participants stay as they are.
/// [currentPhone] is shown as given («+967 777 123 456»).
Future<void> showChangePhoneSheet(
  BuildContext context, {
  required String? currentPhone,
  required Future<({String? error, String? notice})> Function(String newPhone)
  requestCode,
  required Future<String?> Function(String newPhone, String code) confirmCode,
}) {
  return showJourneySheet<void>(
    context: context,
    builder: (_) => _ChangePhoneSheet(
      currentPhone: currentPhone,
      requestCode: requestCode,
      confirmCode: confirmCode,
    ),
  );
}

class _ChangePhoneSheet extends StatefulWidget {
  const _ChangePhoneSheet({
    required this.currentPhone,
    required this.requestCode,
    required this.confirmCode,
  });

  final String? currentPhone;

  /// Sends the code. An Arabic `error` keeps the sheet on the number;
  /// without one the code step opens, saying `notice` when the code is not
  /// known to have arrived.
  final Future<({String? error, String? notice})> Function(String newPhone)
  requestCode;

  /// Moves the account; returns an Arabic error or null (then signs out).
  final Future<String?> Function(String newPhone, String code) confirmCode;

  @override
  State<_ChangePhoneSheet> createState() => _ChangePhoneSheetState();
}

class _ChangePhoneSheetState extends State<_ChangePhoneSheet> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? _sentTo;

  /// Said in place of «أرسلنا لك رمز» when the code is not known to have
  /// arrived (its answer was lost, or it is the one asked a moment ago).
  String? _notice;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final input = _phone.text.trim();
    if (!isValidYemeniPhoneInput(input)) {
      setState(
        () => _error = context.say(
          'اكتب رقم جوال يمني صحيح، مثل 771234567',
          'اكتبي رقم جوال يمني صحيح، مثل 771234567',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final asked = await widget.requestCode(input);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = asked.error;
      if (asked.error == null) {
        _sentTo = input;
        _notice = asked.notice;
      }
    });
  }

  Future<void> _confirm() async {
    final sentTo = _sentTo;
    final code = _code.text.trim();
    if (sentTo == null) return;
    if (!RegExp(r'^[0-9]{4,8}$').hasMatch(code)) {
      setState(
        () => _error = context.say(
          'اكتب الرمز اللي وصلك على واتساب',
          'اكتبي الرمز اللي وصلك على واتساب',
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.confirmCode(sentTo, code);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _sentTo;
    final current = widget.currentPhone?.trim() ?? '';
    return JourneySheetBody(
      title: 'تغيير رقم الجوال',
      subtitle: sentTo == null
          ? null
          : _notice ?? 'أرسلنا لك رمز على واتساب على $sentTo',
      bottom: JourneyButton(
        key: const ValueKey('change-phone-submit'),
        label: sentTo == null
            ? context.say('أرسل الرمز للرقم الجديد', 'أرسلي الرمز للرقم الجديد')
            : context.say('غيّر الرقم', 'غيّري الرقم'),
        expand: true,
        large: true,
        loading: _busy,
        onPressed: sentTo == null ? _send : _confirm,
      ),
      children: [
        if (sentTo == null) ...[
          if (current.isNotEmpty) ...[
            _CurrentPhone(phone: current),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AarastV3Space.x2),
              child: Icon(
                LucideIcons.arrowDown,
                size: AarastV3Icon.lg,
                color: AarastV3Color.textFaint,
              ),
            ),
          ],
          JourneyTextField(
            key: const Key('change-phone-number'),
            label: 'الرقم الجديد',
            controller: _phone,
            large: true,
            autofocus: true,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
            ],
            errorText: _error,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _send(),
          ),
          const SizedBox(height: AarastV3Space.x4),
          JourneyNote(
            icon: LucideIcons.shieldCheck,
            text: context.say(
              'خطتك ومشاركينك يبقون مثل ما هم. بنطلعك من كل الأجهزة وتدخل من جديد بالرقم الجديد.',
              'خطتك ومشاركينك يبقون مثل ما هم. بنطلعك من كل الأجهزة وتدخلين من جديد بالرقم الجديد.',
            ),
          ),
        ] else
          JourneyTextField(
            key: const Key('change-phone-code'),
            label: 'الرمز',
            controller: _code,
            large: true,
            autofocus: true,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            inputFormatters: [LatinDigitsFormatter()],
            errorText: _error,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _confirm(),
          ),
      ],
    );
  }
}

/// «رقمك الحالي» as g09 draws it: the field's look, read only.
class _CurrentPhone extends StatelessWidget {
  const _CurrentPhone({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'رقمك الحالي، $phone',
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('change-phone-current'),
        padding: AarastV3Density.actionInsets,
        decoration: BoxDecoration(
          color: AarastV3Color.paper,
          borderRadius: BorderRadius.circular(AarastV3Radius.card),
          border: Border.all(color: AarastV3Color.line),
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.smartphone,
              size: AarastV3Icon.md,
              color: AarastV3Color.textMuted,
            ),
            const SizedBox(width: AarastV3Space.x2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'رقمك الحالي',
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                  Text(
                    phone,
                    textDirection: TextDirection.ltr,
                    style: JourneyType.of(
                      JourneyType.lead,
                      weight: JourneyType.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
