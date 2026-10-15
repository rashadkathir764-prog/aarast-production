import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';

/// "Change my phone number" (V1 checklist 4.14). A code goes to the new
/// number on WhatsApp; entering it moves the account there and signs out
/// every device, so the next sign-in uses the new number and the same
/// password. A lost SIM: sign in with the old number and the password,
/// then move here.
class ChangePhoneButton extends StatelessWidget {
  const ChangePhoneButton({
    required this.requestCode,
    required this.confirmCode,
    super.key,
  });

  /// Sends the code; returns an Arabic error or null.
  final Future<String?> Function(String newPhone) requestCode;

  /// Moves the account; returns an Arabic error or null (then signs out).
  final Future<String?> Function(String newPhone, String code) confirmCode;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: TextButton.icon(
        key: const Key('settings-change-phone'),
        onPressed: () => showAarastBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: _ChangePhoneSheet(
              requestCode: requestCode,
              confirmCode: confirmCode,
            ),
          ),
        ),
        icon: const Icon(LucideIcons.smartphone),
        label: const Text('تغيير رقم الجوال'),
      ),
    );
  }
}

class _ChangePhoneSheet extends StatefulWidget {
  const _ChangePhoneSheet({required this.requestCode, required this.confirmCode});

  final Future<String?> Function(String newPhone) requestCode;
  final Future<String?> Function(String newPhone, String code) confirmCode;

  @override
  State<_ChangePhoneSheet> createState() => _ChangePhoneSheetState();
}

class _ChangePhoneSheetState extends State<_ChangePhoneSheet> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? _sentTo;
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
      setState(() => _error = 'اكتب رقم جوال يمني صحيح، مثل 77xxxxxxx.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.requestCode(input);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
      if (error == null) _sentTo = input;
    });
  }

  Future<void> _confirm() async {
    final sentTo = _sentTo;
    final code = _code.text.trim();
    if (sentTo == null) return;
    if (!RegExp(r'^[0-9]{4,8}$').hasMatch(code)) {
      setState(() => _error = 'اكتب الرمز الذي وصلك على واتساب.');
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
    final textTheme = Theme.of(context).textTheme;
    final sentTo = _sentTo;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تغيير رقم الجوال',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              sentTo == null
                  ? 'سنرسل رمزًا على واتساب للرقم الجديد. بعد التأكيد يخرج حسابك من كل الأجهزة، وتدخل بالرقم الجديد وكلمة المرور نفسها.'
                  : 'أرسلنا رمزًا على واتساب إلى $sentTo.',
              style: textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            if (sentTo == null)
              TextField(
                key: const Key('change-phone-number'),
                controller: _phone,
                enabled: !_busy,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                ],
                decoration: const InputDecoration(labelText: 'الرقم الجديد'),
              )
            else
              TextField(
                key: const Key('change-phone-code'),
                controller: _code,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'رمز التحقق'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: textTheme.bodySmall?.copyWith(color: AppTheme.danger),
              ),
            ],
            const SizedBox(height: 14),
            AarastButton(
              label: sentTo == null ? 'إرسال الرمز' : 'تأكيد وتغيير الرقم',
              icon: sentTo == null ? LucideIcons.send : LucideIcons.checkCircle2,
              isLoading: _busy,
              onPressed: _busy ? null : (sentTo == null ? _send : _confirm),
            ),
          ],
        ),
      ),
    );
  }
}
