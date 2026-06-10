import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../providers/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
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
            const _LoginDecorations(),
            LayoutBuilder(
              builder: (context, constraints) {
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        constraints.maxHeight < 680 ? 18 : 34,
                        20,
                        24,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _BrandMark(),
                            const SizedBox(height: 22),
                            Text(
                              'تسجيل الدخول',
                              textAlign: TextAlign.center,
                              style: textTheme.headlineSmall?.copyWith(
                                color: AppTheme.dInk,
                                fontWeight: FontWeight.w900,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'ادخل بحسابك لمتابعة تنظيم زواجك بوضوح وأناقة.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: AppTheme.dInkSoft,
                                fontWeight: FontWeight.w600,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 26),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: AppTheme.premiumCardDecoration(
                                radius: AppTheme.radiusXl,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
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
                                    controller: _passwordController,
                                    textAlign: TextAlign.right,
                                    obscureText: _obscurePassword,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) => _submit(),
                                    decoration: InputDecoration(
                                      labelText: 'كلمة المرور',
                                      prefixIcon: const Icon(
                                        Icons.lock_rounded,
                                      ),
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
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'نسيت كلمة المرور؟',
                                      style: textTheme.labelMedium?.copyWith(
                                        color: AppTheme.dGoldDeep,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
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
                                    label: 'تسجيل الدخول',
                                    isLoading: auth.isSubmitting,
                                    onPressed: _submit,
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: auth.isSubmitting
                                        ? null
                                        : () {
                                            auth.clearError();
                                            context.go(AppRouter.register);
                                          },
                                    child: const Text(
                                      'ليس لديك حساب؟ إنشاء حساب',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'أعرست يساعدك ترتب الميزانية، المهام، الديون، والمشاركات من مكان واحد.',
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
    final success = await auth.login(
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      context.go(AppRouter.home);
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
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            gradient: AppTheme.heroGradient,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppTheme.dMaroonDeep.withAlpha(45),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.favorite_rounded,
            color: AppTheme.dGold2,
            size: 34,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'أعرست',
          textAlign: TextAlign.center,
          style: textTheme.displaySmall?.copyWith(
            color: AppTheme.dMaroon,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 76,
          height: 4,
          decoration: BoxDecoration(
            gradient: AppTheme.goldGradient,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }
}

class _LoginDecorations extends StatelessWidget {
  const _LoginDecorations();

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
              top: 110,
              left: -70,
              child: _DecorativeCircle(
                size: 150,
                color: AppTheme.dMaroon.withAlpha(18),
              ),
            ),
            Positioned(
              bottom: -80,
              right: -56,
              child: _DecorativeCircle(
                size: 190,
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