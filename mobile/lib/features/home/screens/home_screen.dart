import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('اعّرست'),
        actions: [
          TextButton(
            onPressed: () async {
              await context.read<AuthController>().logout();
              if (context.mounted) context.go(AppRouter.login);
            },
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'تم تسجيل الدخول بنجاح',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.deepBurgundy,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.name ?? 'مستخدم اعّرست',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.right,
                      ),
                      if (user?.phone != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          user!.phone!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.right,
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        'ابدأ من خطط الزفاف لإعداد الخطة الأساسية ثم متابعة لوحة الخطة.',
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: () => context.go(AppRouter.weddingPlans),
                        icon: const Icon(Icons.favorite),
                        label: const Text('خطط الزفاف'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.go(AppRouter.sharedWeddingPlans),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppTheme.warmGold.withAlpha(45),
                          child: const Icon(
                            Icons.groups,
                            color: AppTheme.deepBurgundy,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'الخطط المشتركة معي',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                                textAlign: TextAlign.right,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'اعرض الخطط التي منحك أصحابها صلاحية الوصول إليها.',
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_left),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
