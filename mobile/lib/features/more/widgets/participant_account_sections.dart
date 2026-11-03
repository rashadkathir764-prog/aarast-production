import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart' show ApiException;
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show
        AccountContext,
        AccountContextController,
        AccountContextPermissions,
        AccountContextPersona,
        AccountContextRole;
import '../../auth/auth_api.dart' show AuthController;
import '../../sharing/sharing_api.dart' show PlanLeaveCoordinator;

/// q10 «حسابي» for a participant: the plans you help in, your own plan (or
/// starting one), and, for the plan open now, what you recorded and leaving
/// it. The account's own settings follow from g02.
class ParticipantAccountSections extends StatefulWidget {
  const ParticipantAccountSections({
    required this.current,
    this.roleLabel,
    this.recordedCount,
    super.key,
  });

  /// The participant's plan open now.
  final AccountContext current;

  /// «مساعد», read from the open plan's home.
  final String? roleLabel;

  /// How many things the participant recorded in the open plan.
  final int? recordedCount;

  @override
  State<ParticipantAccountSections> createState() =>
      _ParticipantAccountSectionsState();
}

class _ParticipantAccountSectionsState
    extends State<ParticipantAccountSections> {
  /// One id per leave, kept across retries so the server sees one request.
  String? _leaveRequestId;

  Future<void> _open(AccountContext path) async {
    final router = GoRouter.of(context);
    final controller = context.read<AccountContextController>();
    if (!path.isAvailable) {
      router.push(AppRouter.sharedPlanState(path.weddingPlanId!));
      return;
    }
    if (controller.selectedContext?.contextKey != path.contextKey &&
        !await controller.select(path.contextKey)) {
      return;
    }
    router.go(AppRouter.home);
  }

  Future<void> _leave() async {
    final current = widget.current;
    final planId = current.weddingPlanId!;
    final planTitle = current.displayName;
    final router = GoRouter.of(context);
    final userId = context.read<AuthController>().user?.id;
    final coordinator = context.read<PlanLeaveCoordinator>();
    final controller = context.read<AccountContextController>();
    final reader = context.journeyProfile;

    Future<void> leaveOnce() async {
      final membership = controller.selectedContext;
      if (userId == null ||
          userId.trim().isEmpty ||
          membership?.role != AccountContextRole.contributor ||
          membership?.weddingPlanId != planId ||
          membership?.membershipId == null ||
          membership?.membershipAuthorityVersion == null) {
        throw StateError('The current participant membership is needed');
      }
      await coordinator.leavePlan(
        userId: userId,
        weddingPlanId: planId,
        expectedMemberId: membership!.membershipId!,
        expectedAuthorityVersion: membership.membershipAuthorityVersion!,
        clientRequestId: _leaveRequestId ??= _newUuidV4(),
        refreshAccountContexts: () async {
          await controller.exitWorkspace();
          await controller.refresh();
        },
      );
    }

    final left = await showJourneySheet<bool>(
      context: context,
      profile: reader,
      builder: (sheetContext) => _LeaveSheet(
        planTitle: planTitle,
        reader: reader,
        onLeave: () async {
          try {
            await leaveOnce();
          } on ApiException catch (error) {
            if (error.serverCode != _membershipChangedCode) rethrow;
            // J2-10: the owner changed the rights after this path was
            // read. That request is answered for good, so the leave is
            // asked again once, as a new request with the fresh version.
            _leaveRequestId = null;
            await controller.refresh();
            await leaveOnce();
          }
        },
      ),
    );
    if (left != true) return;
    _leaveRequestId = null;
    // Leaving clears the open path, which may close this page first; the
    // app's router still reaches the home and its path choice, and the
    // toast goes on its navigator.
    final navigator = router.routerDelegate.navigatorKey.currentState;
    router.go(AppRouter.home);
    if (navigator != null && navigator.mounted) {
      AarastToast.showInfo(
        navigator.context,
        'طلعت من $planTitle',
        overlay: navigator.overlay,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AccountContextController>();
    final current = widget.current;
    final planId = current.weddingPlanId!;
    final helped = [
      for (final path in controller.contexts)
        if (path.role == AccountContextRole.contributor) path,
    ];
    final own = [
      for (final path in controller.contexts)
        if (path.role == AccountContextRole.owner && path.isAvailable) path,
    ];
    final count = widget.recordedCount;
    // B5: every line here is said to the reader, as who they are.
    final reader = context.journeyProfile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const JourneySectionTitle('الخطط اللي أشارك فيها'),
        JourneyList(
          children: [
            for (final path in helped)
              _PlanRow(
                key: ValueKey('participant-plan-${path.contextKey}'),
                path: path,
                line: _helpedLine(
                  path,
                  reader,
                  role: path.contextKey == current.contextKey
                      ? widget.roleLabel
                      : null,
                ),
                tag: !path.isAvailable
                    ? 'في الذكريات'
                    : path.contextKey == current.contextKey
                    ? widget.roleLabel ?? reader.say('مشارك', 'مشاركة')
                    : reader.say('مشارك', 'مشاركة'),
                onTap: () => _open(path),
              ),
          ],
        ),
        const JourneySectionTitle('خطتي'),
        JourneyList(
          children: [
            if (own.isEmpty)
              JourneyListRow(
                key: const ValueKey('participant-start-own-plan'),
                icon: LucideIcons.plus,
                color: AarastV3Color.brandAccentStrong,
                soft: AarastV3Color.brandAccentSoft,
                title: reader.say('ابدأ خطة عرسك', 'ابدئي خطة عرسك'),
                subtitle: 'بنفس حسابك',
                onTap: () => context.push(AppRouter.createWeddingPlan),
              )
            else
              for (final path in own)
                _PlanRow(
                  key: ValueKey('participant-plan-${path.contextKey}'),
                  path: path,
                  line: reader.say('خطتك', 'خطتكِ'),
                  tag: path.persona == AccountContextPersona.bride
                      ? 'عروسة'
                      : 'عريس',
                  onTap: () => _open(path),
                ),
          ],
        ),
        JourneySectionTitle('في ${current.displayName}'),
        JourneyList(
          children: [
            JourneyListRow(
              key: const ValueKey('participant-recorded'),
              icon: LucideIcons.history,
              color: AarastV3Color.textMuted,
              soft: AarastV3Color.canvas,
              title: 'اللي سجّلته',
              subtitle: count == null
                  ? 'يبقى باسمك'
                  : '${arabicCount(count, one: 'حركة', two: 'حركتين', few: 'حركات', many: 'حركة')} · تبقى باسمك',
              onTap: () => context.push(AppRouter.contributionHistory(planId)),
            ),
            if (current.permissions.canInviteMembers)
              JourneyListRow(
                key: const ValueKey('participant-members'),
                icon: LucideIcons.users,
                color: AarastV3Color.primary,
                soft: AarastV3Color.primarySoft,
                title: 'المشاركين',
                subtitle: reader.say('تضيف ناس للخطة', 'تضيفين ناس للخطة'),
                onTap: () => context.push(AppRouter.sharing(planId)),
              ),
            JourneyListRow(
              key: const ValueKey('participant-leave'),
              icon: LucideIcons.logOut,
              color: AarastV3Color.danger,
              soft: AarastV3Color.dangerSoft,
              title: reader.say('اطلع من الخطة', 'اطلعي من الخطة'),
              subtitle: reader.say(
                'تقدر ترجع لو أرسل لك دعوة ثانية',
                'تقدرين ترجعين لو أرسل لك دعوة ثانية',
              ),
              onTap: _leave,
            ),
          ],
        ),
      ],
    );
  }
}

/// «المهام والضيوف»: the sections a plan opens to you, from its flags.
String _helpedLine(AccountContext path, JourneyProfile reader, {String? role}) {
  if (!path.isAvailable) return 'العرس تم';
  final sections = _openSections(path.permissions);
  final line = sections.isEmpty
      ? reader.say('تتابع الخطة بس', 'تتابعين الخطة بس')
      : sections.join(' و');
  return role == null ? line : '$role · $line';
}

List<String> _openSections(AccountContextPermissions permissions) => [
  if (permissions.canManageTasks) 'المهام',
  if (permissions.canManageGuests) 'الضيوف',
  if (permissions.canManageProviders) 'المزودين',
  if (permissions.canViewMoney) 'المال',
];

/// One plan: a letter in the plan's colour, its name, its line and a tag.
class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.path,
    required this.line,
    required this.tag,
    required this.onTap,
    super.key,
  });

  final AccountContext path;
  final String line;
  final String tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = !path.isAvailable
        ? AarastV3Color.textMuted
        : path.role == AccountContextRole.owner
        ? AarastV3Color.brandAccentStrong
        : path.persona == AccountContextPersona.bride
        ? AarastV3Color.rose
        : AarastV3Color.primary;
    final name = path.displayName.trim();
    final source = name.startsWith('عرس ') ? name.substring(4).trim() : name;
    return AarastPressable(
      onTap: onTap,
      semanticLabel: '$name، $line، $tag',
      child: Padding(
        padding: const EdgeInsets.all(AarastV3Space.x3),
        child: Row(
          children: [
            JourneyAvatar(
              letter: source.isEmpty ? 'ع' : source.characters.first,
              color: color,
              size: 40,
            ),
            const SizedBox(width: AarastV3Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                    ),
                  ),
                  Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: JourneyType.of(
                      JourneyType.label,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AarastV3Space.x2),
            JourneyTag(
              label: tag,
              color: color,
              soft: color.withValues(alpha: 0.12),
            ),
          ],
        ),
      ),
    );
  }
}

const _membershipChangedCode = 'MEMBERSHIP_CHANGED_SINCE_LEAVE_REQUEST';

/// «تطلع من عرس محمد؟»: leaving asks once; a failed leave says what
/// happened and stays. Only a failure that never reached the server is
/// blamed on the connection.
class _LeaveSheet extends StatefulWidget {
  const _LeaveSheet({
    required this.planTitle,
    required this.reader,
    required this.onLeave,
  });

  final String planTitle;

  /// B5: the sheet speaks to the reader as who they are.
  final JourneyProfile reader;
  final Future<void> Function() onLeave;

  @override
  State<_LeaveSheet> createState() => _LeaveSheetState();
}

class _LeaveSheetState extends State<_LeaveSheet> {
  bool _leaving = false;
  String? _error;

  Future<void> _leave() async {
    setState(() {
      _leaving = true;
      _error = null;
    });
    try {
      await widget.onLeave();
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _leaving = false;
          _error = _failureMessage(error);
        });
      }
    }
  }

  /// The server's refusal as it said it; the connection only when nothing
  /// was answered.
  String _failureMessage(Object error) {
    final say = widget.reader.say;
    if (error is ApiException) {
      if (error.serverCode == _membershipChangedCode) {
        return say(
          'تغيّرت صلاحياتك قبل شوي، حدّثنا الخطة. جرّب الخروج مرة ثانية.',
          'تغيّرت صلاحياتك قبل شوي، حدّثنا الخطة. جرّبي الخروج مرة ثانية.',
        );
      }
      final status = error.statusCode;
      if (status != null && status >= 400 && status < 500) {
        return error.message;
      }
    }
    return say(
      'ما قدرنا نطلعك من الخطة. تأكد من النت وجرّب مرة ثانية.',
      'ما قدرنا نطلعك من الخطة. تأكدي من النت وجرّبي مرة ثانية.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final say = widget.reader.say;
    return JourneySheetBody(
      title: say(
        'تطلع من ${widget.planTitle}؟',
        'تطلعين من ${widget.planTitle}؟',
      ),
      subtitle: say(
        'تقدر ترجع لو أرسل لك دعوة ثانية',
        'تقدرين ترجعين لو أرسل لك دعوة ثانية',
      ),
      children: [
        if (_error case final error?) ...[
          JourneyNote(
            key: const ValueKey('participant-leave-error'),
            text: error,
            icon: LucideIcons.alertCircle,
            color: AarastV3Color.danger,
            soft: AarastV3Color.dangerSoft,
          ),
          const SizedBox(height: AarastV3Space.x3),
        ],
        JourneyButton(
          key: const ValueKey('participant-leave-confirm'),
          label: say('اطلع من الخطة', 'اطلعي من الخطة'),
          background: AarastV3Color.danger,
          expand: true,
          large: true,
          loading: _leaving,
          onPressed: _leave,
        ),
        const SizedBox(height: AarastV3Space.x1),
        Center(
          child: JourneyTextAction(
            label: 'رجوع',
            onPressed: _leaving ? null : () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

/// A random version 4 id for the leave request, so a retry is the same one.
String _newUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}
