import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthController;
import '../data/settings_api.dart';
import '../models/account_deletion_impact.dart';
import '../widgets/account_data_download.dart';

/// w05 «حذف الحساب» (D63): what goes with the account, a copy of it first,
/// and «احذف حسابي» once «حذف» is typed. The account waits 30 days (w06)
/// before it is erased, and can take it back until then. A provider with
/// weddings still to do is told to hand them over first (B-33).
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({this.downloadOpener, super.key});

  /// Replaces the browser in tests.
  final DownloadLinkOpener? downloadOpener;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _confirmation = TextEditingController();
  AccountDeletionImpact? _impact;
  String? _loadError;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final impact = await context.read<SettingsApi>().deletionImpact();
      if (mounted) setState(() => _impact = impact);
    } on ApiException catch (error) {
      if (mounted) setState(() => _loadError = error.message);
    }
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

  Future<void> _delete() async {
    final auth = context.read<AuthController>();
    final error = await auth.requestAccountDeletion();
    if (!mounted) return;
    if (error != null) {
      AarastToast.showError(context, error);
      return;
    }
    // The app now shows w06 over everything; the stack starts from home
    // when the request is taken back.
    context.go(AppRouter.home);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final impact = _impact;
    final typed = _confirmation.text.trim() == 'حذف';
    final canDelete =
        impact != null &&
        !impact.blockedByUpcomingBookings &&
        typed &&
        !auth.isSubmitting;
    final firstName = (auth.user?.name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .first;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: JourneyPage(
        bottom: JourneyButton(
          key: const ValueKey('delete-account-confirm'),
          label: 'احذف حسابي',
          background: AarastV3Color.danger,
          expand: true,
          large: true,
          loading: auth.isSubmitting,
          onPressed: canDelete ? _delete : null,
        ),
        children: [
          JourneySubHeader(
            title: 'حذف الحساب',
            onBack: () =>
                context.canPop() ? context.pop() : context.go(AppRouter.more),
          ),
          const SizedBox(height: 8),
          const Center(
            child: JourneyIconTile(
              icon: LucideIcons.userX,
              color: AarastV3Color.danger,
              soft: AarastV3Color.dangerSoft,
              size: 64,
              radius: 24,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              firstName.isEmpty
                  ? context.say('متأكد؟', 'متأكدة؟')
                  : context.say(
                      'متأكد يا $firstName؟',
                      'متأكدة يا $firstName؟',
                    ),
              style: JourneyType.of(
                JourneyType.pageTitle,
                weight: JourneyType.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (impact == null && _loadError == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: AarastInlineSpinner(dimension: 24),
              ),
            )
          else if (impact == null)
            _LoadFailed(message: _loadError!, onRetry: _load)
          else ...[
            _Effects(impact: impact),
            if (impact.blockedByUpcomingBookings) ...[
              const SizedBox(height: 12),
              JourneyNote(
                key: const ValueKey('delete-account-blocked'),
                icon: LucideIcons.calendarX,
                color: AarastV3Color.danger,
                soft: AarastV3Color.dangerSoft,
                text: context.say(
                  'عندك ${_bookings(impact.provider?.upcomingBookings ?? 0)} جاية كمزود. سلّمها أو ألغها قبل ما تحذف حسابك.',
                  'عندك ${_bookings(impact.provider?.upcomingBookings ?? 0)} جاية كمزودة. سلّميها أو ألغيها قبل ما تحذفين حسابك.',
                ),
              ),
            ],
            const SizedBox(height: 12),
            JourneyBox(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.download,
                    size: 20,
                    color: context.accent.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      impact.ownedPlans.isEmpty
                          ? context.say(
                              'نزّل نسخة من بياناتك قبل الحذف',
                              'نزّلي نسخة من بياناتك قبل الحذف',
                            )
                          : context.say(
                              'نزّل نسخة من خطتك قبل الحذف',
                              'نزّلي نسخة من خطتك قبل الحذف',
                            ),
                      style: JourneyType.of(
                        JourneyType.bodyLarge,
                        weight: JourneyType.bold,
                      ),
                    ),
                  ),
                  _SoftAction(
                    key: const ValueKey('delete-account-download'),
                    label: context.say('نزّلها', 'نزّليها'),
                    busy: _downloading,
                    onTap: _downloading ? null : _download,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            JourneyTextField(
              key: const ValueKey('delete-account-input'),
              label: context.say('اكتب «حذف» للتأكيد', 'اكتبي «حذف» للتأكيد'),
              controller: _confirmation,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
    );
  }

  static String _bookings(int count) => arabicCount(
    count,
    one: 'حجز واحد',
    two: 'حجزين',
    few: 'حجوزات',
    many: 'حجز',
  );
}

/// The lines of w05: what goes, who is told, and the 30 days.
class _Effects extends StatelessWidget {
  const _Effects({required this.impact});

  final AccountDeletionImpact impact;

  @override
  Widget build(BuildContext context) {
    final names = impact.memberNames;
    return JourneyBox(
      key: const ValueKey('delete-account-effects'),
      child: Column(
        children: [
          _Effect(
            icon: LucideIcons.trash2,
            text: impact.ownedPlans.isEmpty
                ? 'حسابك وبياناتك تنحذف كلها'
                : 'خطتك ومالك ومهامك وضيوفك تنحذف كلها',
          ),
          if (names.isNotEmpty)
            _Effect(
              icon: LucideIcons.users,
              text: names.length == 1
                  ? '${names.single} يطلع من الخطة، ويوصله إشعار'
                  : '${_joined(names)} يطلعون من الخطة، ويوصلهم إشعار',
            ),
          if (impact.upcomingBookings > 0)
            const _Effect(
              icon: LucideIcons.store,
              text: 'الحجوزات المؤكدة تنلغي، ونبلّغ المزودين',
            ),
          if (impact.provider != null && !impact.blockedByUpcomingBookings)
            const _Effect(
              icon: LucideIcons.briefcase,
              text: 'ملفك كمزود ينحذف، ونبلّغ اللي طلبوا منك',
            ),
          _Effect(
            icon: LucideIcons.clock,
            color: context.accent.primary,
            text: context.say(
              'عندك ${arabicDays(impact.graceDays)} ترجع فيها لو غيّرت رأيك',
              'عندك ${arabicDays(impact.graceDays)} ترجعين فيها لو غيّرتِ رأيك',
            ),
          ),
        ],
      ),
    );
  }

  /// «صالح والوالد», «صالح وأحمد والوالد».
  static String _joined(List<String> names) =>
      '${names.sublist(0, names.length - 1).join(' و')} و${names.last}';
}

class _Effect extends StatelessWidget {
  const _Effect({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color ?? AarastV3Color.danger),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: JourneyType.of(JourneyType.body))),
        ],
      ),
    );
  }
}

class _SoftAction extends StatelessWidget {
  const _SoftAction({
    required this.label,
    required this.onTap,
    required this.busy,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.accent.primarySoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: busy
              ? AarastInlineSpinner(
                  dimension: 16,
                  color: context.accent.primary,
                )
              : Text(
                  label,
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                    color: context.accent.primary,
                  ),
                ),
        ),
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        JourneyNote(
          icon: LucideIcons.wifiOff,
          color: AarastV3Color.amber,
          soft: AarastV3Color.amberSoft,
          text: message,
        ),
        const SizedBox(height: 10),
        JourneyButton(
          key: const ValueKey('delete-account-retry'),
          label: 'حاول مرة ثانية',
          icon: LucideIcons.refreshCw,
          expand: true,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
