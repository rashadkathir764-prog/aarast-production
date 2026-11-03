import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../auth/auth_api.dart' show isApplicationPasswordWithinByteLimit;

/// D75 «كلمة المرور», a journey sheet from «حسابي»: an account made by
/// number and WhatsApp code adds a password here, a second way in when a
/// code does not arrive; one that has a password changes it with the
/// current one (the account's other devices are signed out).
Future<void> showSetPasswordSheet(
  BuildContext context, {
  required bool hasPassword,
  required Future<String?> Function(String newPassword, String? current) save,
}) {
  return showJourneySheet<void>(
    context: context,
    builder: (_) => _SetPasswordSheet(hasPassword: hasPassword, save: save),
  );
}

class _SetPasswordSheet extends StatefulWidget {
  const _SetPasswordSheet({required this.hasPassword, required this.save});

  final bool hasPassword;
  final Future<String?> Function(String newPassword, String? current) save;

  @override
  State<_SetPasswordSheet> createState() => _SetPasswordSheetState();
}

class _SetPasswordSheetState extends State<_SetPasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;
  bool _attempted = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  String? get _currentError {
    if (!_attempted || !widget.hasPassword) return null;
    return _current.text.isEmpty ? 'اكتب كلمة المرور الحالية' : null;
  }

  String? get _nextError {
    if (!_attempted) return null;
    final value = _next.text;
    if (value.length < 6) return '6 أحرف أو أكثر';
    if (!isApplicationPasswordWithinByteLimit(value)) {
      return 'طويلة، خلّها أقصر';
    }
    return null;
  }

  Future<void> _submit() async {
    setState(() {
      _attempted = true;
      _error = null;
    });
    if (_currentError != null || _nextError != null) return;
    setState(() => _busy = true);
    final error = await widget.save(
      _next.text,
      widget.hasPassword ? _current.text : null,
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
    final error = _error;
    return JourneySheetBody(
      title: widget.hasPassword ? 'تغيير كلمة المرور' : 'إضافة كلمة مرور',
      subtitle: widget.hasPassword
          ? 'أجهزتك الثانية تطلع من الحساب بعد التغيير.'
          : 'طريق ثاني للدخول، لو الرمز ما وصل على واتساب.',
      children: [
        if (widget.hasPassword) ...[
          JourneyTextField(
            key: const ValueKey('set-password-current'),
            label: 'كلمة المرور الحالية',
            controller: _current,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            errorText: _currentError,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AarastV3Field.gap),
        ],
        JourneyTextField(
          key: const ValueKey('set-password-new'),
          label: 'كلمة المرور الجديدة',
          controller: _next,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          helper: '6 أحرف أو أكثر',
          helperColor: AarastV3Color.textMuted,
          errorText: _nextError,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _submit(),
        ),
        if (error != null) ...[
          const SizedBox(height: AarastV3Space.x3),
          JourneyNote(
            text: error,
            icon: LucideIcons.alertCircle,
            color: AarastV3Color.danger,
            soft: AarastV3Color.dangerSoft,
          ),
        ],
        const SizedBox(height: AarastV3Space.x4),
        JourneyButton(
          key: const ValueKey('set-password-save'),
          label: 'احفظ',
          expand: true,
          large: true,
          loading: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}
