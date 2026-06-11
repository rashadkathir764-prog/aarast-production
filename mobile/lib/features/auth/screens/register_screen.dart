import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_wedding_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final textTheme = Theme.of(context).textTheme;

    return AuthWeddingScaffold(
      leading: AuthBackButton(
        onPressed: () => context.go(AppRouter.onboarding),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const AuthBrandMark(compact: true),
            const SizedBox(height: 24),
            Text(
              'إنشاء حساب',
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                color: AppTheme.dInk,
                fontWeight: FontWeight.w900,
                height: 1.18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ابدئي رحلتك بخطة زفاف واضحة ومرتبة.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppTheme.dInkSoft,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            AuthPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthTextField(
                    controller: _nameController,
                    label: 'الاسم الكامل',
                    icon: Icons.person_rounded,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'الاسم مطلوب';
                      }
                      if (value.trim().length < 3) {
                        return 'الاسم قصير جداً';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _phoneController,
                    label: 'رقم الهاتف',
                    hint: 'مثال: 77xxxxxxx',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'رقم الهاتف مطلوب';
                      }
                      if (value.trim().length < 7) {
                        return 'رقم الهاتف غير صحيح';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _emailController,
                    label: 'البريد الإلكتروني اختياري',
                    icon: Icons.mail_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _passwordController,
                    label: 'كلمة المرور',
                    icon: Icons.lock_rounded,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'إظهار كلمة المرور'
                          : 'إخفاء كلمة المرور',
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'كلمة المرور مطلوبة';
                      }
                      if (value.length < 6) {
                        return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                      }
                      return null;
                    },
                  ),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    AuthInlineError(message: auth.errorMessage!),
                  ],
                  const SizedBox(height: 20),
                  PrimaryActionButton(
                    label: 'إنشاء حساب',
                    icon: Icons.person_add_alt_1_rounded,
                    isLoading: auth.isSubmitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AuthFooterLink(
              prefix: 'لديك حساب بالفعل؟',
              action: 'تسجيل الدخول',
              onTap: () {
                if (auth.isSubmitting) return;
                auth.clearError();
                context.go(AppRouter.login);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    final email = _emailController.text.trim();
    final success = await auth.register(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: email.isEmpty ? null : email,
      password: _passwordController.text,
    );

    if (success && mounted) {
      context.go(AppRouter.otp);
    }
  }
}
