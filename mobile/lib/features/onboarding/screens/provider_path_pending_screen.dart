import 'package:flutter/material.dart';

import '../widgets/guest_onboarding_step_scaffold.dart';

class ProviderPathPendingScreen extends StatelessWidget {
  const ProviderPathPendingScreen({this.onContinue, this.onBack, super.key});

  final VoidCallback? onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return GuestOnboardingStepScaffold(
      title: 'لوحة المزود',
      description:
          'هذا المسار منفصل عن لوحة تنظيم الزفاف. لا نطلب الحساب إلا عند تجهيز ملف الخدمة أو إرسال طلب مزود.',
      continueLabel: 'تجهيز ملف الخدمة',
      onContinue: onContinue,
      onBack: onBack,
      child: const Column(
        children: [
          GuestOnboardingOptionTile(
            title: 'جهّز ملف خدمتك',
            subtitle: 'أدخل بيانات النشاط والفئة والمدينة عندما تكون جاهزًا.',
            icon: Icons.badge_outlined,
            selected: true,
          ),
          SizedBox(height: 12),
          GuestOnboardingOptionTile(
            title: 'طلبات العروض ستظهر هنا',
            subtitle:
                'مسار المزود يحتاج إنشاء حساب ومراجعة طلب الانضمام قبل عرض أي طلبات أسعار.',
            icon: Icons.request_quote_outlined,
          ),
          SizedBox(height: 12),
          GuestOnboardingCard(
            child: Text(
              'يمكنك الرجوع لاختيار مسار تنظيم الزفاف في أي وقت. تجهيز ملف المزود يستخدم المسارات الحالية الآمنة فقط.',
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
