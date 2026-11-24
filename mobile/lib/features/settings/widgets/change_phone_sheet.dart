import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/forms/latin_digits_formatter.dart';

/// The proof that the account's holder asks the change (RA-BE-141): the
/// code sent to the current number, or the password.
typedef PhoneChangeProof = ({String? currentCode, String? currentPassword});

/// g09 «تغيير رقم الجوال», a journey sheet from «حسابي»: the number now, the
/// new one, and a code on WhatsApp to the new number. RA-BE-141: with it,
/// the password of an account that has one, or else a code sent to the
/// current number at the same time. Confirming moves the account and signs
/// out every device, this one too, so the next sign-in is with the new
/// number. The plan and its participants stay as they are. [currentPhone]
/// is shown as given («+967 777 123 456»).
Future<void> showChangePhoneSheet(
  BuildContext context, {
  required String? currentPhone,
  required bool hasPassword,
  required Future<({String? error, String? notice})> Function(String newPhone)
  requestCode,
  required Future<({String? error, String? notice})> Function()
  requestCurrentCode,
  required Future<String?> Function(
    String newPhone,
    String code,
    PhoneChangeProof proof,
  )
  confirmCode,
}) {
  return showJourneySheet<void>(
    context: context,
    builder: (_) => _ChangePhoneSheet(
      currentPhone: currentPhone,
      hasPassword: hasPassword,
      requestCode: requestCode,
      requestCurrentCode: requestCurrentCode,
      confirmCode: confirmCode,
    ),
  );
}

class _ChangePhoneSheet extends StatefulWidget {
  const _ChangePhoneSheet({
    required this.currentPhone,
    required this.hasPassword,
    required this.requestCode,
    required this.requestCurrentCode,
    required this.confirmCode,
  });

  final String? currentPhone;

  /// The password proves the change; without one, a code to [currentPhone].
  final bool hasPassword;

  /// Sends the code. An Arabic `error` keeps the sheet on the number;
  /// without one the code step opens, saying `notice` when the code is not
  /// known to have arrived.
  final Future<({String? error, String? notice})> Function(String newPhone)
  requestCode;

  /// Sends the code to the current number (an account without a password).
  final Future<({String? error, String? notice})> Function() requestCurrentCode;

  /// Moves the account; returns an Arabic error or null (then signs out).
  final Future<String?> Function(
    String newPhone,
    String code,
    PhoneChangeProof proof,
  )
  confirmCode;

  @override
  State<_ChangePhoneSheet> createState() => _ChangePhoneSheetState();
}

class _ChangePhoneSheetState extends State<_ChangePhoneSheet> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _proof = TextEditingController();
  String? _sentTo;

  /// What the current number's code request said, when it did not go well.
  String? _proofNote;
  String? _proofError;

  /// Said in place of «أرسلنا لك رمز» when the code is not known to have
  /// arrived (its answer was lost, or it is the one asked a moment ago).
  String? _notice;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _proof.dispose();
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
    if (asked.error != null) {
      setState(() {
        _busy = false;
        _error = asked.error;
      });
      return;
    }
    // RA-BE-141: without a password, the current number gets its code now.
    final current = widget.hasPassword
        ? null
        : await widget.requestCurrentCode();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _sentTo = input;
      _notice = asked.notice;
      _proofNote = current?.error ?? current?.notice;
    });
  }

  Future<void> _confirm() async {
    final sentTo = _sentTo;
    final code = _code.text.trim();
    if (sentTo == null) return;
    final proof = _proof.text;
    final codeError = RegExp(r'^[0-9]{4,8}$').hasMatch(code)
        ? null
        : context.say(
            'اكتب الرمز اللي وصلك على واتساب',
            'اكتبي الرمز اللي وصلك على واتساب',
          );
    final proofError = widget.hasPassword
        ? (proof.isEmpty
              ? context.say('اكتب كلمة المرور', 'اكتبي كلمة المرور')
              : null)
        : (RegExp(r'^[0-9]{4,8}$').hasMatch(proof.trim())
              ? null
              : context.say(
                  'اكتب الرمز اللي وصل لرقمك الحالي',
                  'اكتبي الرمز اللي وصل لرقمك الحالي',
                ));
    if (codeError != null || proofError != null) {
      setState(() {
        _error = codeError;
        _proofError = proofError;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _proofError = null;
    });
    final error = await widget.confirmCode(
      sentTo,
      code,
      widget.hasPassword
          ? (currentCode: null, currentPassword: proof)
          : (currentCode: proof.trim(), currentPassword: null),
    );
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
        ] else ...[
          JourneyTextField(
            key: const Key('change-phone-code'),
            label: 'رمز الرقم الجديد',
            controller: _code,
            large: true,
            autofocus: true,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            inputFormatters: [LatinDigitsFormatter()],
            errorText: _error,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AarastV3Field.gap),
          // RA-BE-141: the proof that this is the account's holder.
          if (widget.hasPassword)
            JourneyTextField(
              key: const Key('change-phone-password'),
              label: 'كلمة المرور',
              controller: _proof,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              errorText: _proofError,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _busy ? null : _confirm(),
            )
          else
            JourneyTextField(
              key: const Key('change-phone-current-code'),
              label: 'رمز رقمك الحالي',
              controller: _proof,
              large: true,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.right,
              inputFormatters: [LatinDigitsFormatter()],
              helper: _proofNote ?? 'أرسلناه على واتساب على $current',
              helperColor: AarastV3Color.textMuted,
              errorText: _proofError,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _busy ? null : _confirm(),
            ),
        ],
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
