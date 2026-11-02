import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/network/api_client.dart' show ApiException;
import '../../../core/phone/phone_links.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthActionGuard;
import '../../wedding_plans/wedding_plans_api.dart' show publishGuestPlanPulse;
import '../data/guests_api.dart';
import '../models/guest.dart';
import '../providers/guests_provider.dart';
import '../utils/guest_display.dart';
import '../widgets/guest_form_sheet.dart';

/// e07 «تفاصيل ضيف»: who, their group and number, their answer (which can
/// be set by hand), a call and a WhatsApp chat, and their invitation. The
/// dated timeline (sent, opened, answered) and the rafd are not drawn: the
/// guest record keeps neither.
class GuestDetailsScreen extends StatefulWidget {
  const GuestDetailsScreen({
    required this.weddingPlanId,
    required this.guestId,
    super.key,
  });

  final String weddingPlanId;
  final String guestId;

  @override
  State<GuestDetailsScreen> createState() => _GuestDetailsScreenState();
}

class _GuestDetailsScreenState extends State<GuestDetailsScreen> {
  bool _sending = false;

  bool get _isLocalPlan =>
      AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<GuestsProvider>();
      if (_guest(provider) == null) provider.loadGuests(widget.weddingPlanId);
    });
  }

  Guest? _guest(GuestsProvider provider) {
    for (final guest in provider.guests) {
      if (guest.id == widget.guestId) return guest;
    }
    return null;
  }

  void _back() => context.popOrGo(AppRouter.guestList(widget.weddingPlanId));

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuestsProvider>();
    final guest = _guest(provider);

    final Widget body;
    if (guest == null && provider.isLoading) {
      body = const JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.guests,
      );
    } else if (guest == null) {
      body = JourneyListState(
        phase: provider.loadErrorMessage == null
            ? JourneyListPhase.empty
            : JourneyListPhase.error,
        section: JourneySection.guests,
        emptyIcon: LucideIcons.userX,
        emptyTitle: context.planWord(
          'هذا الضيف ما عاد موجود',
          'هذي الضيفة ما عادت موجودة',
        ),
        emptyAction: context.say('ارجع', 'ارجعي'),
        onEmptyAction: _back,
        onRetry: () => provider.loadGuests(widget.weddingPlanId),
      );
    } else {
      body = _details(provider, guest);
    }

    return AarastScreenFrame(
      maxWidth: 600,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: JourneySubHeader(
              title: '',
              onBack: _back,
              trailing: guest == null
                  ? null
                  : PopupMenuButton<bool>(
                      key: const ValueKey('guest-menu'),
                      tooltip: context.planWord(
                        'خيارات الضيف',
                        'خيارات الضيفة',
                      ),
                      enabled: !provider.isSubmitting,
                      icon: const Icon(LucideIcons.moreHorizontal),
                      onSelected: (edit) =>
                          edit ? _edit(provider, guest) : _delete(guest),
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          key: const ValueKey('guest-menu-edit'),
                          value: true,
                          child: Text(
                            // The reader edits; the guest is the plan's.
                            '${context.say('عدّل', 'عدّلي')} '
                            '${context.planWord('بياناته', 'بياناتها')}',
                          ),
                        ),
                        PopupMenuItem(
                          key: const ValueKey('guest-menu-delete'),
                          value: false,
                          child: Text(
                            // «شيله», «شيلها», «شيليه», «شيليها».
                            '${context.say('شيل', 'شيلي')}'
                            '${context.planWord('ه', 'ها')} من القائمة',
                            style: const TextStyle(color: AarastV3Color.danger),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [body],
            ),
          ),
        ],
      ),
    );
  }

  Widget _details(GuestsProvider provider, Guest guest) {
    final (color, soft) = guestReplyColors(guest);
    final phone = guest.phone;
    final name = guest.name.trim();
    final status = guest.isConfirmed
        ? 'CONFIRMED'
        : guest.isDeclined
        ? 'DECLINED'
        : 'INVITED';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: JourneyAvatar(
            letter: name.isEmpty ? '؟' : name.characters.first,
            color: context.accent.primary,
            size: 64,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name.isEmpty ? 'بدون اسم' : name,
          textAlign: TextAlign.center,
          style: JourneyType.of(JourneyType.display, weight: JourneyType.bold),
        ),
        Text(
          [
            guestGroupLabel(guest, provider.groups),
            if (guest.side != 'UNKNOWN') guestSideLabel(guest.side),
            if (phone != null && phone.trim().isNotEmpty)
              PhoneNumberUtils.directionalDisplay(phone) ?? phone,
          ].join(' · '),
          textAlign: TextAlign.center,
          style: JourneyType.of(
            JourneyType.body,
            color: AarastV3Color.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: JourneyTag(
            key: const ValueKey('guest-reply-tag'),
            label: guestReplyLabel(guest, context.journeyProfile),
            color: color,
            soft: soft,
          ),
        ),
        if (guest.hasPhone) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: JourneyButton(
                  key: const ValueKey('guest-call'),
                  label: context.say('اتصل', 'اتصلي'),
                  icon: LucideIcons.phone,
                  background: AarastV3Color.paper,
                  foreground: AarastV3Color.ink,
                  expand: true,
                  onPressed: () => _launch(phoneCallUri(phone)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: JourneyButton(
                  key: const ValueKey('guest-whatsapp'),
                  label: 'واتساب',
                  icon: LucideIcons.messageCircle,
                  background: AarastV3Color.mintSoft,
                  foreground: AarastV3Color.mint,
                  expand: true,
                  onPressed: whatsAppChatUri(phone) == null
                      ? null
                      : () => _launch(whatsAppChatUri(phone)),
                ),
              ),
            ],
          ),
        ],
        const JourneySectionTitle('الرد'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (value, label) in [
              ('CONFIRMED', context.planWord('أكّد', 'أكّدت')),
              ('DECLINED', context.planWord('اعتذر', 'اعتذرت')),
              ('INVITED', context.planWord('ما ردّ', 'ما ردّت')),
            ])
              JourneyChip(
                key: ValueKey('guest-reply-$value'),
                label: label,
                selected: status == value,
                selectedColor: context.accent.primary,
                onTap: provider.isSubmitting || status == value
                    ? null
                    : () => _setReply(provider, guest, value),
              ),
          ],
        ),
        if (guest.isConfirmed && guest.companionsCount > 0) ...[
          const SizedBox(height: 6),
          Text(
            '${context.say('معه', 'معها')} ${guest.companionsCount} · ${arabicSeats(guest.seatsCount)}',
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
        ],
        if (!_isLocalPlan && !guest.id.startsWith('local-guest-')) ...[
          const JourneySectionTitle('الدعوة'),
          JourneyBox(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  guest.invitationStatus == 'NOT_SENT'
                      ? LucideIcons.mail
                      : LucideIcons.mailCheck,
                  color: context.accent.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    guest.invitationStatus == 'NOT_SENT'
                        ? context.planWord(
                            'ما انرسلت له دعوة',
                            'ما انرسلت لها دعوة',
                          )
                        : context.planWord(
                            'انرسلت له الدعوة',
                            'انرسلت لها الدعوة',
                          ),
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
                if (guest.hasPhone)
                  JourneyButton(
                    key: const ValueKey('guest-send-invitation'),
                    label: guest.invitationStatus == 'NOT_SENT'
                        ? context.say('أرسلها', 'أرسليها')
                        : 'رابط جديد',
                    background: context.accent.primary,
                    loading: _sending,
                    onPressed: _sending ? null : () => _sendInvitation(guest),
                  ),
              ],
            ),
          ),
          if (!guest.hasPhone)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                // The reader adds; the guest is the plan's.
                '${context.say('أضف', 'أضيفي')} '
                '${context.planWord('رقمه عشان توصله', 'رقمها عشان توصلها')} '
                'الدعوة على واتساب.',
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.brandAccentStrong,
                ),
              ),
            ),
        ],
        if ((guest.notes ?? '').trim().isNotEmpty) ...[
          const JourneySectionTitle('ملاحظة'),
          JourneyBox(
            padding: const EdgeInsets.all(14),
            child: Text(
              guest.notes!.trim(),
              style: JourneyType.of(JourneyType.body),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _launch(Uri? uri) async {
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      AarastToast.showError(context, 'ما قدرنا نفتحه من جوالك');
    }
  }

  void _pulse(GuestsProvider provider) {
    publishGuestPlanPulse(
      context,
      weddingPlanId: widget.weddingPlanId,
      summary: provider.summary,
    );
  }

  Future<void> _setReply(
    GuestsProvider provider,
    Guest guest,
    String status,
  ) async {
    final ok = await provider.updateGuest(
      guest: guest,
      status: status,
      attendanceStatus: guestAttendanceForStatus(status),
    );
    if (!mounted) return;
    if (ok) {
      _pulse(provider);
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'ما قدرنا نحفظ الرد',
      );
    }
  }

  /// The guest's own link, from this phone's WhatsApp (V1 checklist 4.7).
  /// A new link replaces the old one, so the old one stops working.
  Future<void> _sendInvitation(Guest guest) async {
    final api = context.read<GuestsApi>();
    final provider = context.read<GuestsProvider>();
    setState(() => _sending = true);
    try {
      final link = await api.createInvitationLink(guest.id);
      final opened = await launchUrl(
        link.whatsAppUri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!opened) {
        AarastToast.showError(context, 'ما قدرنا نفتح واتساب في هذا الجوال');
      }
      await provider.loadGuests(widget.weddingPlanId);
    } on ApiException catch (error) {
      if (mounted) AarastToast.showError(context, error.message);
    } catch (_) {
      if (mounted) {
        AarastToast.showError(context, 'ما قدرنا نجهّز رابط الدعوة');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _edit(GuestsProvider provider, Guest guest) async {
    final scope = 'guest:${widget.weddingPlanId}:${guest.id}';
    final result = await showJourneySheet<GuestFormResult>(
      context: context,
      useRootNavigator: true,
      builder: (_) => GuestFormSheet(
        guest: guest,
        draftScope: scope,
        existingGuests: provider.guests,
        groups: provider.groups,
        blockDuplicatePhone: !_isLocalPlan,
        onCreateGroup: _isLocalPlan
            ? null
            : (name) async {
                final ok = await provider.createGroup(
                  widget.weddingPlanId,
                  name,
                );
                return ok ? provider.groups.last.id : null;
              },
      ),
    );
    if (result == null || !mounted) return;
    final ok = await provider.updateGuest(
      guest: guest,
      name: result.name,
      phone: result.phone ?? '',
      groupId: result.groupId ?? '',
      side: result.side,
      status: result.status,
      attendanceStatus: guestAttendanceForStatus(result.status),
      seatsCount: result.seatsCount,
      companionsCount: result.companionsCount,
      notes: result.notes,
    );
    if (!mounted) return;
    if (ok) {
      _pulse(provider);
      await context.read<AarastFormDraftStore?>()?.clear(scope);
      if (mounted) AarastToast.showSuccess(context, 'انحفظ');
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ??
            context.planWord('ما قدرنا نحفظ الضيف', 'ما قدرنا نحفظ الضيفة'),
      );
    }
  }

  Future<void> _delete(Guest guest) async {
    final provider = context.read<GuestsProvider>();
    final confirmed = await showJourneySheet<bool>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title: '${context.say('تشيل', 'تشيلين')} ${guest.name}؟',
        subtitle: context.planWord(
          'ينشال من قائمة الضيوف ورابطه ما يعود يشتغل.',
          'تنشال من قائمة الضيفات ورابطها ما يعود يشتغل.',
        ),
        children: [
          JourneyButton(
            key: const ValueKey('guest-delete-confirm'),
            label:
                '${context.say('شيل', 'شيلي')}${context.planWord('ه', 'ها')}',
            background: AarastV3Color.danger,
            expand: true,
            large: true,
            onPressed: () => Navigator.pop(sheetContext, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await provider.deleteGuest(guest);
    if (!mounted) return;
    if (ok) {
      _pulse(provider);
      AarastToast.showSuccess(
        context,
        context.planWord('انشال الضيف', 'انشالت الضيفة'),
      );
      _back();
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ??
            context.planWord('ما قدرنا نشيله', 'ما قدرنا نشيلها'),
      );
    }
  }
}
