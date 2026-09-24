part of 'invite_decision_screen.dart';

class _PhoneStep extends StatelessWidget {
  const _PhoneStep({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return ListView(
      children: [
        const _InviteWelcomeHero(
          icon: LucideIcons.mailCheck,
          eyebrow: 'دعوة خاصة لك',
          title: 'انضم إلى خطة تمت دعوتك إليها',
          message:
              'تحقق من رقمك لعرض الخطة ودورك والصلاحيات الممنوحة لك بأمان.',
        ),
        const SizedBox(height: 14),
        AarastCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _FieldLabel('رقم الهاتف'),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  key: const Key('invite-phone-field'),
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: '777 123 456',
                    prefixIcon: Icon(LucideIcons.smartphone),
                  ),
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
              if (auth.errorMessage != null) ...[
                const SizedBox(height: 12),
                _InlineError(auth.errorMessage!),
              ],
              const SizedBox(height: 12),
              const _PrivacyLine(),
              const SizedBox(height: 18),
              AarastButton(
                key: const Key('invite-request-otp-button'),
                label: 'إرسال رمز التحقق',
                icon: LucideIcons.messageSquare,
                isLoading: auth.isSubmitting,
                onPressed: auth.isSubmitting ? null : onSubmit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InviteJourneyProgress extends StatelessWidget {
  const _InviteJourneyProgress({required this.step});

  final _InviteAccessStep step;

  @override
  Widget build(BuildContext context) {
    final activeIndex = switch (step) {
      _InviteAccessStep.phone => 0,
      _InviteAccessStep.accountSetup => 1,
      _InviteAccessStep.otp => 1,
      _InviteAccessStep.invites => 2,
    };
    const labels = ['رقم الهاتف', 'التحقق', 'الدعوة'];

    return Semantics(
      label: 'المرحلة ${activeIndex + 1} من 3: ${labels[activeIndex]}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            for (var index = 0; index < labels.length; index++) ...[
              if (index > 0)
                Expanded(
                  child: Container(
                    height: 1,
                    color: index <= activeIndex
                        ? AppTheme.focus
                        : AppTheme.border,
                  ),
                ),
              _InviteJourneyMarker(
                label: labels[index],
                index: index,
                activeIndex: activeIndex,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InviteJourneyMarker extends StatelessWidget {
  const _InviteJourneyMarker({
    required this.label,
    required this.index,
    required this.activeIndex,
  });

  final String label;
  final int index;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final isActive = index == activeIndex;
    final isComplete = index < activeIndex;
    final color = isActive || isComplete
        ? AppTheme.brand
        : AppTheme.textSecondary;

    return SizedBox(
      width: 58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: AppTheme.motionFast,
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.brand
                  : isComplete
                  ? AppTheme.brandMuted
                  : AppTheme.canvas,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive || isComplete
                    ? AppTheme.focus
                    : AppTheme.border,
              ),
            ),
            child: isComplete
                ? const Icon(LucideIcons.check, size: 15, color: AppTheme.brand)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteWelcomeHero extends StatelessWidget {
  const _InviteWelcomeHero({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.gapLg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.focus.withValues(alpha: 0.36)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.surfaceRaised,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.focus),
            ),
            child: Icon(icon, color: AppTheme.brand, size: 25),
          ),
          const SizedBox(height: 10),
          Text(
            eyebrow,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.brand,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
              fontFamily: AppTheme.displayFontFamily,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.shieldCheck, size: 18, color: AppTheme.success),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'لن نعرض تفاصيل الخطة قبل مطابقة الرقم بالدعوة.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountSetupStep extends StatelessWidget {
  const _AccountSetupStep({
    required this.nameController,
    required this.passwordController,
    required this.passwordConfirmationController,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onContinue,
    required this.onChangePhone,
  });

  final TextEditingController nameController;
  final TextEditingController passwordController;
  final TextEditingController passwordConfirmationController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onContinue;
  final VoidCallback onChangePhone;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return ListView(
      key: const ValueKey('invite-account-setup-step'),
      children: [
        const _InviteWelcomeHero(
          icon: LucideIcons.badgeCheck,
          eyebrow: 'حساب دائم للمساهم',
          title: 'أنشئ بيانات الدخول',
          message:
              'ستستخدم رقم الهاتف وكلمة المرور هذه للدخول لاحقًا دون طلب رمز تحقق جديد.',
        ),
        const SizedBox(height: 14),
        AarastCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _InviteAccountSetupNotice(),
              const SizedBox(height: 14),
              AuthTextField(
                key: const ValueKey('invite-account-name-field'),
                controller: nameController,
                label: 'اسم المساهم',
                hint: 'الاسم الذي سيظهر داخل الخطة',
                icon: LucideIcons.user,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              AuthTextField(
                key: const ValueKey('invite-account-password-field'),
                controller: passwordController,
                label: 'كلمة المرور',
                hint: '6 أحرف على الأقل',
                icon: LucideIcons.lock,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.next,
                suffixIcon: AuthObscureToggle(
                  obscured: obscurePassword,
                  onPressed: onTogglePassword,
                ),
              ),
              const SizedBox(height: 12),
              AuthTextField(
                key: const ValueKey(
                  'invite-account-password-confirmation-field',
                ),
                controller: passwordConfirmationController,
                label: 'تأكيد كلمة المرور',
                hint: 'أعد كتابة كلمة المرور',
                icon: LucideIcons.lock,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => onContinue(),
              ),
              if (auth.errorMessage != null) ...[
                const SizedBox(height: 12),
                _InlineError(auth.errorMessage!),
              ],
              const SizedBox(height: 18),
              AarastButton(
                key: const ValueKey('invite-account-setup-continue'),
                label: 'متابعة إلى رمز التحقق',
                icon: LucideIcons.arrowLeft,
                onPressed: auth.isSubmitting ? null : onContinue,
              ),
              const SizedBox(height: 10),
              AarastButton(
                label: 'تغيير الرقم',
                variant: AarastButtonVariant.ghost,
                onPressed: auth.isSubmitting ? null : onChangePhone,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    required this.controller,
    required this.phone,
    required this.state,
    required this.resendSeconds,
    required this.onCodeChanged,
    required this.onVerify,
    required this.onResend,
    required this.onChangePhone,
    required this.onCreateAppAccount,
    required this.reviewInviteAfterVerification,
    required this.deliveryConfirmed,
    this.otpNoticeMessage,
  });

  final TextEditingController controller;
  final String phone;
  final AarastOtpFieldState state;
  final int resendSeconds;
  final ValueChanged<String> onCodeChanged;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onChangePhone;
  final VoidCallback onCreateAppAccount;
  final bool reviewInviteAfterVerification;
  final bool deliveryConfirmed;
  final String? otpNoticeMessage;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final missingAppAccount =
        auth.errorCode == 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF';
    return ListView(
      children: [
        _InviteWelcomeHero(
          icon: LucideIcons.messageCircle,
          eyebrow: 'التحقق من الهوية',
          title: 'أدخل رمز التحقق',
          message: deliveryConfirmed
              ? 'تم تسليم الرمز إلى واتساب على '
                    '${PhoneNumberUtils.isolateLtr(_maskedPhone(phone))}'
              : 'طلبنا إرسال الرمز إلى '
                    '${PhoneNumberUtils.isolateLtr(_maskedPhone(phone))}، '
                    'لكن لم نتأكد من وصوله بعد.',
        ),
        const SizedBox(height: 14),
        if (otpNoticeMessage != null) ...[
          _InviteNotice(
            icon: LucideIcons.code2,
            title: 'حالة إرسال الرمز',
            message: otpNoticeMessage!,
          ),
          const SizedBox(height: 16),
        ],
        AarastCard(
          // عند نجاح الرمز تتحوّل البطاقة كاملة إلى لوحة ✓ الخضراء.
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 280),
            child: state == AarastOtpFieldState.success
                ? AarastOtpSuccessPanel(
                    subtitle: reviewInviteAfterVerification
                        ? 'تم توثيق رقمك — جارٍ عرض الدعوة لتختار قبولها أو رفضها.'
                        : 'تم توثيق رقمك — جارٍ عرض دعواتك.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _FieldLabel('رمز التحقق'),
                      AarastOtpField(
                        controller: controller,
                        state: state,
                        enabled: !auth.isSubmitting,
                        fieldKey: const Key('invite-otp-field'),
                        onChanged: onCodeChanged,
                        onCompleted: (_) => onVerify(),
                      ),
                      if (auth.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        _InlineError(auth.errorMessage!),
                      ],
                      const SizedBox(height: 18),
                      if (missingAppAccount)
                        AarastButton(
                          key: const ValueKey('invite-create-app-account'),
                          label: 'إنشاء حساب التطبيق والمتابعة',
                          icon: LucideIcons.userPlus,
                          onPressed: phone.isEmpty ? null : onCreateAppAccount,
                        )
                      else
                        AarastButton(
                          key: const Key('invite-verify-otp-button'),
                          label: reviewInviteAfterVerification
                              ? 'تأكيد الرمز ومراجعة الدعوة'
                              : 'تأكيد الرمز',
                          icon: LucideIcons.checkCircle2,
                          isLoading: auth.isSubmitting,
                          onPressed: auth.isSubmitting ? null : onVerify,
                        ),
                      const SizedBox(height: 10),
                      if (missingAppAccount)
                        AarastButton(
                          label: 'تغيير الرقم',
                          variant: AarastButtonVariant.ghost,
                          onPressed: auth.isSubmitting ? null : onChangePhone,
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: AarastButton(
                                key: const ValueKey('invite-otp-resend-button'),
                                label: resendSeconds > 0
                                    ? 'إعادة الإرسال خلال $resendSeconds ث'
                                    : 'إعادة إرسال الرمز',
                                variant: AarastButtonVariant.secondary,
                                onPressed:
                                    auth.isSubmitting || resendSeconds > 0
                                    ? null
                                    : onResend,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AarastButton(
                                label: 'تغيير الرقم',
                                variant: AarastButtonVariant.ghost,
                                onPressed: auth.isSubmitting
                                    ? null
                                    : onChangePhone,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _InvitesStep extends StatelessWidget {
  const _InvitesStep({
    required this.openedInvite,
    required this.onOpenInvite,
    required this.onCloseInvite,
    required this.onAccept,
    required this.onDecline,
    required this.onOpenAcceptedPlan,
    required this.onChangePhone,
    required this.onRetry,
  });

  final PlanInvite? openedInvite;
  final ValueChanged<PlanInvite> onOpenInvite;
  final VoidCallback onCloseInvite;
  final ValueChanged<PlanInvite> onAccept;
  final ValueChanged<PlanInvite> onDecline;
  final ValueChanged<PlanInvite> onOpenAcceptedPlan;
  final VoidCallback onChangePhone;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SharingProvider>();
    if (provider.isLoading) {
      return AarastSkeleton.list(rows: 3, rowHeight: 120, withHeader: false);
    }

    if (openedInvite != null) {
      return _InviteDetails(
        invite: openedInvite!,
        isSubmitting: provider.isSubmitting,
        errorMessage: provider.errorMessage,
        onAccept: () => onAccept(openedInvite!),
        onDecline: () => onDecline(openedInvite!),
        onOpenAcceptedPlan: () => onOpenAcceptedPlan(openedInvite!),
        onBack: onCloseInvite,
      );
    }

    final invites = provider.myInvites;
    if (invites.isEmpty) {
      return _NoInviteState(
        message:
            provider.errorMessage ??
            'لا توجد دعوة مرتبطة بهذا الرقم. تأكد من الرقم أو اطلب من صاحب الخطة إرسال دعوة جديدة.',
        onChangePhone: onChangePhone,
        onRetry: onRetry,
      );
    }

    return ListView.separated(
      itemCount: invites.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final invite = invites[index];
        return _InviteListCard(
          invite: invite,
          onTap: () {
            if (invite.hasActiveMembership) {
              onOpenAcceptedPlan(invite);
              return;
            }
            onOpenInvite(invite);
          },
        );
      },
    );
  }
}
