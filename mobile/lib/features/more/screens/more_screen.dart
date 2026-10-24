import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/security/app_lock_controller.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../auth/auth_api.dart'
    show AuthActionGuard, AuthController, AuthStatus;
import '../../settings/settings_api.dart' show showChangePhoneSheet;
import '../widgets/logout_sheet.dart';
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummaryProvider;

/// g02 «حسابي»: who you are, your wedding, how the app looks, safety and
/// privacy, and the account (C51 adds «الحساب»: notifications, plans,
/// help, sign out). «الأرقام» and «الوضع الليلي» are left out (D23).
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  static const _avatarMaxBytes = 5 * 1024 * 1024;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final hasAccount = auth.status == AuthStatus.authenticated && user != null;
    final selected = context
        .watch<AccountContextController?>()
        ?.selectedContext;
    final planId = selected?.weddingPlanId;
    final summary = context.watch<DashboardSummaryProvider?>()?.summary;
    final plan = summary != null && summary.planId == planId ? summary : null;
    final preferences = context.watch<DevicePreferences?>();
    AppLockController? lock;
    try {
      lock = context.watch<AppLockController>();
    } on ProviderNotFoundException {
      lock = null;
    }

    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          JourneySubHeader(
            title: 'حسابي',
            onBack: () =>
                context.canPop() ? context.pop() : context.go(AppRouter.home),
          ),
          _ProfileCard(
            name: user?.name ?? '',
            phone: user?.phone,
            avatarUrl: user?.avatarUrl,
            busy: auth.isSubmitting,
            onEditAvatar: hasAccount ? () => _changeAvatar(context) : null,
          ),
          if (planId != null && planId.isNotEmpty) ...[
            const _GroupTitle('عرسي'),
            JourneyList(
              dividers: false,
              children: [
                _Row(
                  key: const ValueKey('account-wedding-date'),
                  icon: LucideIcons.calendarDays,
                  title: 'موعد العرس',
                  value: plan?.weddingDate == null
                      ? null
                      : formatArabicDayMonth(plan!.weddingDate!),
                  onTap: () => context.push(AppRouter.planCenter(planId)),
                ),
                _Row(
                  key: const ValueKey('account-participants'),
                  icon: LucideIcons.users,
                  title: 'المشاركين',
                  value: plan == null ? null : '${plan.participantCount}',
                  onTap: () => context.push(AppRouter.sharing(planId)),
                ),
                _Row(
                  key: const ValueKey('account-postpone'),
                  icon: LucideIcons.calendarClock,
                  title: 'تأجيل العرس',
                  onTap: () => context.push(AppRouter.planCenter(planId)),
                ),
              ],
            ),
          ],
          if (preferences != null) ...[
            const _GroupTitle('شكل التطبيق'),
            JourneyList(
              dividers: false,
              children: [
                _Row(
                  key: const ValueKey('account-hijri'),
                  icon: LucideIcons.moon,
                  title: 'التاريخ الهجري جنب الميلادي',
                  switchValue: preferences.showHijri,
                  onSwitch: preferences.setShowHijri,
                ),
                _Row(
                  key: const ValueKey('account-large-text'),
                  icon: LucideIcons.type,
                  title: 'خط كبير',
                  switchValue: preferences.largeText,
                  onSwitch: preferences.setLargeText,
                ),
                _Row(
                  key: const ValueKey('account-data-saver'),
                  icon: LucideIcons.image,
                  title: 'توفير البيانات',
                  switchValue: preferences.dataSaver,
                  onSwitch: preferences.setDataSaver,
                ),
              ],
            ),
          ],
          const _GroupTitle('الأمان والخصوصية'),
          JourneyList(
            dividers: false,
            children: [
              if (preferences != null)
                _Row(
                  key: const ValueKey('account-hide-amounts'),
                  icon: LucideIcons.eyeOff,
                  title: 'أخفِ المبالغ',
                  switchValue: preferences.hideAmounts,
                  onSwitch: preferences.setHideAmounts,
                ),
              if (hasAccount && lock != null && lock.userId != null)
                _Row(
                  key: const ValueKey('account-app-lock'),
                  icon: LucideIcons.lock,
                  title: 'قفل التطبيق',
                  value: lock.isEnabled ? 'رمز' : 'مطفي',
                  onTap: () => context.push(AppRouter.lockSettings),
                ),
              if (hasAccount)
                _Row(
                  key: const ValueKey('account-change-phone'),
                  icon: LucideIcons.smartphone,
                  title: 'تغيير رقم الجوال',
                  onTap: () => showChangePhoneSheet(
                    context,
                    requestCode: auth.requestPhoneChange,
                    confirmCode: auth.confirmPhoneChange,
                  ),
                ),
            ],
          ),
          const _GroupTitle('الحساب'),
          JourneyList(
            dividers: false,
            children: [
              if (hasAccount)
                _Row(
                  key: const ValueKey('account-notifications'),
                  icon: LucideIcons.bell,
                  title: 'التنبيهات',
                  onTap: () => context.push(AppRouter.settings),
                ),
              _Row(
                key: const ValueKey('account-plans'),
                icon: LucideIcons.layers,
                title: 'خططك',
                onTap: () => context.push(AppRouter.weddingPlans),
              ),
              _Row(
                key: const ValueKey('account-help'),
                icon: LucideIcons.lifeBuoy,
                title: 'المساعدة',
                onTap: () => context.push(AppRouter.support),
              ),
              if (hasAccount)
                _Row(
                  key: const ValueKey('account-logout'),
                  icon: LucideIcons.logOut,
                  title: 'الخروج',
                  color: AarastV3Color.danger,
                  onTap: () => _logout(context),
                )
              else
                _Row(
                  key: const ValueKey('account-login'),
                  icon: LucideIcons.logIn,
                  title: 'تسجيل الدخول',
                  onTap: () => context.push(AppRouter.login),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// g11 «الخروج». Deleting the account stays out until its 30-day grace
  /// exists (C4); changes not yet sent are named first, because signing out
  /// wipes them from this phone (C59).
  static Future<void> _logout(BuildContext context) async {
    OfflineSyncService? sync;
    try {
      sync = context.read<OfflineSyncService>();
    } on ProviderNotFoundException {
      sync = null;
    }
    final confirmed = await showAarastBottomSheet<bool>(
      context: context,
      backgroundColor: AarastV3Color.canvas,
      showDragHandle: true,
      // The C59 warning makes it taller than the default nine-sixteenths.
      isScrollControlled: true,
      builder: (sheetContext) => LogoutSheet(sync: sync),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthController>().logout();
    }
  }

  Future<void> _changeAvatar(BuildContext context) async {
    if (!await AuthActionGuard.requireAccount(
      context,
      reason: 'ادخل حسابك أول عشان تغيّر صورتك.',
    )) {
      return;
    }
    if (!context.mounted) return;

    final source = await showAarastBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: JourneyList(
            children: [
              JourneyListRow(
                icon: LucideIcons.camera,
                color: AarastV3Color.primary,
                soft: AarastV3Color.primarySoft,
                title: 'صوّر',
                subtitle: 'بالكاميرا',
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              JourneyListRow(
                icon: LucideIcons.image,
                color: AarastV3Color.primary,
                soft: AarastV3Color.primarySoft,
                title: 'اختر صورة',
                subtitle: 'من المعرض',
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 86,
      maxWidth: 1600,
    );
    if (file == null || !context.mounted) return;

    final size = await file.length();
    if (!context.mounted) return;
    if (size > _avatarMaxBytes) {
      AarastToast.showError(context, 'الصورة أكبر من 5 ميجا.');
      return;
    }
    final contentType = _avatarContentType(file);
    if (contentType == null) {
      AarastToast.showError(context, 'اختر صورة JPG أو PNG أو WebP.');
      return;
    }
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;

    final auth = context.read<AuthController>();
    final ok = await auth.updateAvatar(
      bytes: bytes,
      fileName: _avatarFileName(file),
      contentType: contentType,
    );
    if (!context.mounted) return;
    if (ok) {
      AarastToast.showSuccess(context, 'تغيّرت صورتك.');
    } else {
      AarastToast.showError(
        context,
        auth.errorMessage ?? 'ما قدرنا نغيّر الصورة.',
      );
    }
  }

  static String? _avatarContentType(XFile file) {
    final mimeType = file.mimeType?.trim().toLowerCase();
    if (mimeType == 'image/jpeg' ||
        mimeType == 'image/png' ||
        mimeType == 'image/webp') {
      return mimeType;
    }
    final name = _avatarFileName(file).toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    return null;
  }

  static String _avatarFileName(XFile file) {
    final name = file.name.trim();
    if (name.isNotEmpty) return name;
    final pathParts = file.path.split(RegExp(r'[\\/]'));
    final fromPath = pathParts.isEmpty ? '' : pathParts.last.trim();
    return fromPath.isEmpty ? 'avatar.jpg' : fromPath;
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 20, 6, 8),
      child: Text(
        title,
        style: JourneyType.of(
          JourneyType.body,
          weight: JourneyType.bold,
          color: AarastV3Color.textMuted,
        ),
      ),
    );
  }
}

/// The name, the phone, and the avatar (pressing it changes the photo).
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.phone,
    required this.avatarUrl,
    required this.busy,
    required this.onEditAvatar,
  });

  final String name;
  final String? phone;
  final String? avatarUrl;
  final bool busy;
  final VoidCallback? onEditAvatar;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? 'ا' : name.trim().characters.first;
    final url = avatarUrl;
    final Widget avatar = SizedBox.square(
      dimension: 64,
      child: busy
          ? const Center(child: AarastInlineSpinner())
          : url != null && url.isNotEmpty
          ? ClipOval(
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => JourneyAvatar(
                  letter: letter,
                  color: AarastV3Color.saffron,
                  size: 64,
                ),
              ),
            )
          : JourneyAvatar(
              letter: letter,
              color: AarastV3Color.saffron,
              size: 64,
            ),
    );
    return JourneyBox(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          onEditAvatar == null
              ? avatar
              : Tooltip(
                  message: 'تعديل صورة الحساب',
                  child: AarastPressable(
                    key: const ValueKey('account-avatar'),
                    onTap: onEditAvatar,
                    borderRadius: BorderRadius.circular(32),
                    child: avatar,
                  ),
                ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.trim().isEmpty ? 'ضيف' : name.trim(),
                  style: JourneyType.of(
                    JourneyType.title,
                    weight: JourneyType.bold,
                  ),
                ),
                if (phone != null && phone!.trim().isNotEmpty)
                  Text(
                    _groupedPhone(phone!.trim()),
                    textDirection: TextDirection.ltr,
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One row: an icon, a title, then a value with an arrow or a switch.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.switchValue,
    this.onSwitch,
    this.color = AarastV3Color.primary,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitch;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final toggle = switchValue;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: JourneyType.of(
                JourneyType.body,
                weight: JourneyType.bold,
                color: color == AarastV3Color.primary
                    ? AarastV3Color.text
                    : color,
              ),
            ),
          ),
          if (toggle != null)
            JourneyToggle(value: toggle, onChanged: onSwitch)
          else ...[
            if (value != null)
              Text(
                value!,
                style: JourneyType.of(
                  JourneyType.body,
                  color: AarastV3Color.textMuted,
                ),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(
                LucideIcons.chevronLeft,
                size: 18,
                color: AarastV3Color.textMuted,
              ),
            ],
          ],
        ],
      ),
    );
    // A switch row flips from anywhere on it.
    final switchChanged = onSwitch;
    final VoidCallback? tap = toggle != null && switchChanged != null
        ? () => switchChanged(!toggle)
        : onTap;
    if (tap == null) return row;
    return AarastPressable(onTap: tap, child: row);
  }
}

/// «+967 777 123 456», the way a Yemeni number is read out.
String _groupedPhone(String phone) {
  final match = RegExp(r'^\+967(\d{3})(\d{3})(\d{3})$').firstMatch(phone);
  if (match == null) return phone;
  return '+967 ${match[1]} ${match[2]} ${match[3]}';
}
