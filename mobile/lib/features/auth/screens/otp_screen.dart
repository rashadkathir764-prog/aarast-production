import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../widgets/auth_wedding_widgets.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _codeLength = 6;

  final List<TextEditingController> _controllers = List.generate(
    _codeLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _codeLength,
    (_) => FocusNode(),
  );

  bool _isVerifying = false;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.isEmpty) {
      if (index > 0) {
        FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
      }
      return;
    }

    if (index < _codeLength - 1) {
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
      return;
    }

    _focusNodes[index].unfocus();
    _verifyOtp();
  }

  Future<void> _verifyOtp() async {
    final code = _controllers.map((controller) => controller.text).join();
    if (code.length < _codeLength || _isVerifying) return;

    setState(() => _isVerifying = true);
    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() => _isVerifying = false);
    context.go(AppRouter.home);
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRouter.register);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AuthWeddingScaffold(
      leading: AuthBackButton(onPressed: _goBack),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const AuthBrandMark(compact: true),
          const SizedBox(height: 24),
          const WeddingRingsBadge(size: 88),
          const SizedBox(height: 24),
          Text(
            'تأكيد رقم الهاتف',
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              color: AppTheme.dInk,
              fontWeight: FontWeight.w900,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'أدخلي رمز التحقق المرسل إلى رقم هاتفك\nلإكمال إعداد الحساب.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          AuthPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    children: List.generate(_codeLength, (index) {
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsetsDirectional.only(
                            end: index == _codeLength - 1 ? 0 : 6,
                          ),
                          child: SizedBox(
                            height: 58,
                            child: TextFormField(
                              controller: _controllers[index],
                              focusNode: _focusNodes[index],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: textTheme.titleLarge?.copyWith(
                                color: AppTheme.dMaroonDeep,
                                fontWeight: FontWeight.w900,
                              ),
                              maxLength: 1,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                counterText: '',
                                filled: true,
                                fillColor: AppTheme.dCard2,
                                contentPadding: EdgeInsets.zero,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppTheme.dLine,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppTheme.dMaroon,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              onChanged: (value) => _onChanged(value, index),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 22),
                PrimaryActionButton(
                  label: 'تأكيد الرمز',
                  icon: Icons.verified_rounded,
                  isLoading: _isVerifying,
                  onPressed: _verifyOtp,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AuthFooterLink(
            prefix: 'لم تستلمي الرمز؟',
            action: 'إعادة الإرسال',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إعادة إرسال الرمز')),
              );
            },
          ),
        ],
      ),
    );
  }
}
