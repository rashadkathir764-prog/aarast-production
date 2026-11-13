import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/security/app_lock_controller.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController, AccountContextRole;
import '../../auth/auth_api.dart'
    show AuthActionGuard, AuthController, AuthStatus;
import '../../settings/settings_api.dart'
    show showChangePhoneSheet, showSetPasswordSheet;
import '../../sharing/sharing_api.dart'
    show participantOwnRoleWord, participantPhone;
import '../widgets/logout_sheet.dart';
import '../widgets/participant_account_sections.dart';
import '../../wedding_plans/wedding_plans_api.dart'
    show DashboardSummaryProvider, showPlanSwitcherSheet, showPostponeSheet;

part 'more_screen.rows.dart';

/// A fixed dimension of this layout, not a spacing step (D74).
const _moreAvatarBox = 54.0;

/// g02 «حسابي»: who you are, your wedding, how the app looks, safety and
/// privacy, and the account (C51 adds «الحساب»: notifications, plans,
/// help, sign out). «الأرقام» and «الوضع الليلي» are left out (D23).
/// A participant sees q10 at the top instead: the name and number, the
/// plans helped in, their own plan, and the open plan's record and leave.
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
    final participant =
        selected != null &&
        selected.isPlan &&
        selected.role == AccountContextRole.contributor;
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
        padding: AarastV3Density.pageInsets,
        children: [
          JourneySubHeader(
            title: 'حسابي',
            subtitle: participant
                ? [
                    if ((user?.name ?? '').trim().isNotEmpty) user!.name.trim(),
                    ?participantPhone(user?.phone),
                  ].join(' · ')
                : null,
            onBack: () =>
                context.canPop() ? context.pop() : context.go(AppRouter.home),
          ),
          if (participant)
            ParticipantAccountSections(
              current: selected,
              roleLabel: plan?.permissions.role == null
                  ? null
                  : participantOwnRoleWord(
                      plan!.permissions.role,
                      feminine: context.journeyProfile.feminine,
                    ),
              recordedCount: plan?.contributionHistory.values.fold<int>(
                0,
                (total, count) => total + count,
              ),
            )
          else
            _ProfileCard(
              name: user?.name ?? '',
              phone: user?.phone,
              avatarUrl: user?.avatarUrl,
              busy: auth.isSubmitting,
              onEditAvatar: hasAccount ? () => _changeAvatar(context) : null,
            ),
          // «عرسي» belongs to the plan's owner. D112 (Q-21): not on a plan
          // in the memories; its day, its participants and its postponing
          // are all changes, and a memory takes none.
          if (planId != null &&
              planId.isNotEmpty &&
              selected?.isOwnerMemory != true &&
              plan?.permissions.isOwner == true) ...[
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
                  value: plan == null || plan.otherParticipants == 0
                      ? null
                      : '${plan.otherParticipants}',
                  onTap: () => context.push(AppRouter.sharing(planId)),
                ),
                // g03 moves a set day; without one, w10 picks it.
                _Row(
                  key: const ValueKey('account-postpone'),
                  icon: LucideIcons.calendarClock,
                  title: 'تأجيل العرس',
                  onTap: plan?.weddingDate == null
                      ? () => context.push(AppRouter.planCenter(planId))
                      : () => showPostponeSheet(
                          context,
                          planId: planId,
                          weddingDate: plan!.weddingDate!,
                        ),
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
                  title: context.say('أخفِ المبالغ', 'أخفي المبالغ'),
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
                    currentPhone: PhoneNumberUtils.display(user.phone),
                    requestCode: auth.requestPhoneChange,
                    confirmCode: auth.confirmPhoneChange,
                  ),
                ),
              if (hasAccount)
                _Row(
                  key: const ValueKey('account-password'),
                  icon: LucideIcons.keyRound,
                  title: 'كلمة المرور',
                  value: user.hasPassword ? 'موجودة' : 'ما فيه',
                  onTap: () => showSetPasswordSheet(
                    context,
                    hasPassword: user.hasPassword,
                    save: auth.setPassword,
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
              // w40 (D63, L8): privacy, the data download and w05.
              if (hasAccount)
                _Row(
                  key: const ValueKey('account-privacy'),
                  icon: LucideIcons.shieldCheck,
                  title: 'الخصوصية',
                  onTap: () => context.push(AppRouter.privacy),
                ),
              // A participant's plans are listed above (q10).
              if (!participant)
                _Row(
                  key: const ValueKey('account-plans'),
                  icon: LucideIcons.layers,
                  title: 'خططك',
                  onTap: () => showPlanSwitcherSheet(context),
                ),
              _Row(
                key: const ValueKey('account-help'),
                icon: LucideIcons.lifeBuoy,
                title: 'المساعدة',
                onTap: () => context.push(AppRouter.support),
              ),
              // D84: what the app measured about reaching the server, with
              // a report to copy; for everyone, account or not.
              _Row(
                key: const ValueKey('account-connection'),
                icon: LucideIcons.activity,
                title: 'فحص الاتصال',
                onTap: () => context.push(AppRouter.connectionCheck),
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

  /// g11 «الخروج»: out of this phone, or w05 to delete the account after
  /// its 30 days (C4, D63); changes not yet sent are named first, because
  /// signing out wipes them from this phone (C59).
  static Future<void> _logout(BuildContext context) async {
    OfflineSyncService? sync;
    try {
      sync = context.read<OfflineSyncService>();
    } on ProviderNotFoundException {
      sync = null;
    }
    final choice = await showJourneySheet<LogoutChoice>(
      context: context,
      builder: (sheetContext) => LogoutSheet(sync: sync),
    );
    if (!context.mounted) return;
    switch (choice) {
      case LogoutChoice.signOut:
        await context.read<AuthController>().logout();
      case LogoutChoice.deleteAccount:
        await context.push(AppRouter.deleteAccount);
      case null:
        break;
    }
  }

  Future<void> _changeAvatar(BuildContext context) async {
    if (!await AuthActionGuard.requireAccount(
      context,
      reason: context.say(
        'ادخل حسابك أول عشان تغيّر صورتك.',
        'ادخلي حسابك أول عشان تغيّرين صورتك.',
      ),
    )) {
      return;
    }
    if (!context.mounted) return;

    final source = await showJourneySheet<ImageSource>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title: null,
        children: [
          JourneyList(
            children: [
              JourneyListRow(
                icon: LucideIcons.camera,
                color: context.accent.primary,
                soft: context.accent.primarySoft,
                title: context.say('صوّر', 'صوّري'),
                subtitle: 'بالكاميرا',
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              JourneyListRow(
                icon: LucideIcons.image,
                color: context.accent.primary,
                soft: context.accent.primarySoft,
                title: context.say('اختر صورة', 'اختاري صورة'),
                subtitle: 'من المعرض',
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ],
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
      AarastToast.showError(
        context,
        context.say(
          'اختر صورة JPG أو PNG أو WebP.',
          'اختاري صورة JPG أو PNG أو WebP.',
        ),
      );
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
      padding: const EdgeInsets.fromLTRB(
        AarastV3Space.x1,
        AarastV3Space.x4,
        AarastV3Space.x1,
        AarastV3Space.x2,
      ),
      child: Text(
        title,
        style: JourneyType.of(
          JourneyType.bodySmall,
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
    final letter = name.trim().isEmpty ? '' : name.trim().characters.first;
    final url = avatarUrl;
    // g02: a 54 avatar, 14 from a 19 bold name over a 14 muted phone.
    final Widget avatar = SizedBox.square(
      dimension: _moreAvatarBox,
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
                  size: 48,
                ),
              ),
            )
          : JourneyAvatar(
              letter: letter,
              color: AarastV3Color.saffron,
              size: 48,
            ),
    );
    return JourneyBox(
      padding: const EdgeInsets.all(AarastV3Space.x4),
      child: Row(
        children: [
          onEditAvatar == null
              ? avatar
              : Tooltip(
                  message: 'تعديل صورة الحساب',
                  child: AarastPressable(
                    key: const ValueKey('account-avatar'),
                    onTap: onEditAvatar,
                    borderRadius: BorderRadius.circular(AarastV3Radius.pill),
                    child: avatar,
                  ),
                ),
          const SizedBox(width: AarastV3Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.trim().isEmpty ? 'ضيف' : name.trim(),
                  style: JourneyType.of(
                    JourneyType.prominent,
                    weight: JourneyType.bold,
                  ),
                ),
                if (phone != null && phone!.trim().isNotEmpty)
                  Text(
                    PhoneNumberUtils.display(phone) ?? phone!.trim(),
                    textDirection: TextDirection.ltr,
                    style: JourneyType.of(
                      JourneyType.bodySmall,
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
