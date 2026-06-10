import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../providers/auth_controller.dart';

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

    return Scaffold(
      backgroundColor: AppTheme.dBg,
      body: SafeArea(
        child: Stack(
          children: [
            const _RegisterDecorations(),
            LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        constraints.maxHeight < 720 ? 18 : 30,
                        20,
                        24,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _BrandMark(),
                            const SizedBox(height: 20),
                            Text(
                              'إنشاء حساب',
                              textAlign: TextAlign.center,
                              style: textTheme.headlineSmall?.copyWith(
                                color: AppTheme.dInk,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ابدأ حسابك بسهولة وابدأ رحلة تنظيم زفافك.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppTheme.dInkSoft,
                                fontWeight: FontWeight.w600,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: AppTheme.premiumCardDecoration(
                                radius: AppTheme.radiusXl,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _nameController,
                                    textAlign: TextAlign.right,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'الاسم الكامل',
                                      prefixIcon: Icon(Icons.person_rounded),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'الاسم مطلوب';
                                      }
                                      if (value.trim().length < 3) {
                                        return 'الاسم قصير جداً';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _phoneController,
                                    textAlign: TextAlign.right,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'رقم الهاتف',
                                      hintText: 'مثال: 77xxxxxxx',
                                      prefixIcon: Icon(Icons.phone_rounded),
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'رقم الهاتف مطلوب';
                                      }
                                      if (value.trim().length < 7) {
                                        return 'رقم الهاتف غير صحيح';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _emailController,
                                    textAlign: TextAlign.right,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: 'البريد الإلكتروني اختياري',
                                      prefixIcon: Icon(Icons.mail_rounded),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextFormField(
                                    controller: _passwordController,
                                    textAlign: TextAlign.right,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    decoration: InputDecoration(
                                      labelText: 'كلمة المرور',
                                      prefixIcon:
                                          const Icon(Icons.lock_rounded),
                                      suffixIcon: IconButton(
                                        tooltip: _obscurePassword
                                            ? 'إظهار كلمة المرور'
                                            : 'إخفاء كلمة المرور',
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          });
                                        },
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_rounded
                                              : Icons.visibility_off_rounded,
                                        ),
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
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.dPinkBg,
                                        borderRadius: BorderRadius.circular(
                                          AppTheme.radiusMd,
                                        ),
                                        border: Border.all(
                                          color: AppTheme.danger.withAlpha(70),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.error_outline_rounded,
                                            color: AppTheme.danger,
                                            size: 19,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              auth.errorMessage!,
                                              textAlign: TextAlign.right,
                                              style: textTheme.bodySmall
                                                  ?.copyWith(
                                                color: AppTheme.danger,
                                                fontWeight: FontWeight.w700,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  PrimaryActionButton(
                                    label: 'إنشاء حساب',
                                    isLoading: auth.isSubmitting,
                                    onPressed: _submit,
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: auth.isSubmitting
                                        ? null
                                        : () {
                                            auth.clearError();
                                            context.go(AppRouter.login);
                                          },
                                    child: const Text(
                                      'لديك حساب بالفعل؟ تسجيل الدخول',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'كل تفاصيل زفافك في مكان واحد: خطة، ميزانية، مهام، ومتابعة يومية.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppTheme.dMuted,
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
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
    final success = await auth.register(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      context.go('/otp'); // Navigating to OTP after register, before home
    }
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            Text(
              'أعرسِت',
              textAlign: TextAlign.center,
              style: textTheme.displayMedium?.copyWith(
                color: AppTheme.dMaroonDeep,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            Positioned(
              top: -6,
              right: -12,
              child: Icon(
                Icons.favorite,
                color: AppTheme.dPinkBg,
                size: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 40, height: 1.5, color: AppTheme.dGold2),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.favorite, color: AppTheme.dGoldDeep, size: 14),
            ),
            Container(width: 40, height: 1.5, color: AppTheme.dGold2),
          ],
        ),
      ],
    );
  }
}

class _RegisterDecorations extends StatelessWidget {
  const _RegisterDecorations();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -58,
              right: -44,
              child: _DecorativeCircle(
                size: 150,
                color: AppTheme.dGold.withAlpha(32),
              ),
            ),
            Positioned(
              top: 130,
              left: -76,
              child: _DecorativeCircle(
                size: 160,
                color: AppTheme.dMaroon.withAlpha(18),
              ),
            ),
            Positioned(
              bottom: -90,
              right: -60,
              child: _DecorativeCircle(
                size: 200,
                color: AppTheme.dPinkBg.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}