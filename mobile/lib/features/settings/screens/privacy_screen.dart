import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../auth/auth_api.dart' show AuthController;
import '../../wedding_plans/wedding_plans_api.dart' show AssistantConsent;
import '../data/settings_api.dart';
import '../widgets/account_data_download.dart';

/// w40 «الخصوصية» (D63): what leaves the phone and what others read. Crash
/// reports are this phone's choice; the assistant's consent is the one it
/// asks before its first question (shown only where the assistant answers
/// the reader); the name on reviews is kept on the server. Then the copy of
/// the account's data and the way to w05. «الأجهزة» (w04) is not built.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({this.downloadOpener, super.key});

  /// Replaces the browser in tests.
  final DownloadLinkOpener? downloadOpener;

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool? _reviewFirstNameOnly;
  bool _reviewSaving = false;
  bool? _assistantConsent;
  int? _assistantDailyLimit;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<SettingsApi>();
    final userId = context.read<AuthController>().user?.id;
    final planId = context
        .read<AccountContextController?>()
        ?.selectedContext
        ?.weddingPlanId;
    ApiClient? client;
    try {
      client = context.read<ApiClient>();
    } on ProviderNotFoundException {
      client = null;
    }
    try {
      final firstOnly = await api.reviewFirstNameOnly();
      if (mounted) setState(() => _reviewFirstNameOnly = firstOnly);
    } on ApiException catch (error) {
      if (mounted) AarastToast.showError(context, error.message);
    }
    final consent = await AssistantConsent.isGiven(userId);
    int? limit;
    if (client != null && planId != null && planId.isNotEmpty) {
      try {
        limit = await AssistantConsent.dailyLimit(client, planId);
      } on ApiException {
        // Without the network the assistant row waits; nothing else depends on it.
        limit = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _assistantConsent = consent;
      _assistantDailyLimit = limit;
    });
  }

  Future<void> _setReviewName(bool value) async {
    setState(() => _reviewSaving = true);
    try {
      final saved = await context.read<SettingsApi>().setReviewFirstNameOnly(
        value,
      );
      if (mounted) setState(() => _reviewFirstNameOnly = saved);
    } on ApiException catch (error) {
      if (mounted) AarastToast.showError(context, error.message);
    } finally {
      if (mounted) setState(() => _reviewSaving = false);
    }
  }

  Future<void> _setAssistant(bool value) async {
    final userId = context.read<AuthController>().user?.id;
    await AssistantConsent.set(userId, value);
    if (mounted) setState(() => _assistantConsent = value);
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    final opener = widget.downloadOpener;
    if (opener == null) {
      await downloadAccountData(context);
    } else {
      await downloadAccountData(context, open: opener);
    }
    if (mounted) setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<DevicePreferences?>();
    final reviewFirstOnly = _reviewFirstNameOnly;
    final assistantLimit = _assistantDailyLimit;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        padding: AarastV3Density.pageInsets,
        children: [
          JourneySubHeader(
            title: 'الخصوصية',
            onBack: () =>
                context.canPop() ? context.pop() : context.go(AppRouter.more),
          ),
          JourneyBox(
            padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x1),
            child: Column(
              children: [
                if (preferences != null)
                  _Toggle(
                    key: const ValueKey('privacy-crash-reports'),
                    title: 'أرسل تقارير الأعطال',
                    subtitle: 'بدون أسماء ولا مبالغ. تساعدنا نصلّح',
                    value: preferences.crashReports,
                    onChanged: preferences.setCrashReports,
                  ),
                if (assistantLimit != null && _assistantConsent != null)
                  _Toggle(
                    key: const ValueKey('privacy-assistant'),
                    title: 'المساعد الذكي',
                    subtitle:
                        '${arabicCount(assistantLimit, one: 'سؤال واحد', two: 'سؤالين', few: 'أسئلة', many: 'سؤال')} في اليوم',
                    value: _assistantConsent!,
                    onChanged: _setAssistant,
                  ),
                _Toggle(
                  key: const ValueKey('privacy-review-name'),
                  title: 'اسمي في التقييمات',
                  subtitle: reviewFirstOnly == false
                      ? 'اسمك كامل'
                      : 'الاسم الأول بس',
                  value: reviewFirstOnly ?? true,
                  onChanged: reviewFirstOnly == null || _reviewSaving
                      ? null
                      : _setReviewName,
                ),
              ],
            ),
          ),
          const SizedBox(height: AarastV3Space.x3),
          JourneyList(
            children: [
              JourneyListRow(
                key: const ValueKey('privacy-download'),
                icon: LucideIcons.download,
                color: context.accent.primary,
                soft: context.accent.primarySoft,
                title: context.say('نزّل بياناتي', 'نزّلي بياناتي'),
                subtitle: 'ملف فيه خطتك كاملة',
                trailing: _downloading
                    ? AarastInlineSpinner(
                        dimension: 18,
                        color: context.accent.primary,
                      )
                    : null,
                onTap: _downloading ? null : _download,
              ),
              JourneyListRow(
                key: const ValueKey('privacy-delete-account'),
                icon: LucideIcons.userX,
                color: AarastV3Color.danger,
                soft: AarastV3Color.dangerSoft,
                title: 'حذف الحساب',
                subtitle: 'بعد 30 يوم',
                onTap: () => context.push(AppRouter.deleteAccount),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AarastV3Space.x3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
                    weight: JourneyType.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              ],
            ),
          ),
          JourneyToggle(
            value: value,
            onChanged: onChanged,
            semanticLabel: title,
          ),
        ],
      ),
    );
  }
}
