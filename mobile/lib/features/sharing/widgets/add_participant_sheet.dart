import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_duplicate_utils.dart';
import '../../../core/contacts/contact_picker_service.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_binding.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../shared/models/contact_phone_draft.dart';
import '../../auth/auth_api.dart' show AuthController;
import '../models/invite_share_content.dart';
import '../models/participant_access.dart';
import '../models/plan_role_permissions.dart';
import '../models/shared_member.dart';
import '../providers/sharing_provider.dart';
import 'invite_link_copy.dart';
import 'participant_access_editor.dart';

/// g06 «أضف مشارك»: a ready role, each section's level, then the invite goes
/// out on WhatsApp from Aarast (`POST P/invites`, 7 days). A number already
/// waiting gets a new link with the new levels instead. When WhatsApp did not
/// take it, the sheet stays open with the link to copy.
Future<void> showAddParticipantSheet(
  BuildContext context, {
  required String weddingPlanId,
  ParticipantPreset preset = ParticipantPreset.helper,
  ContactPhoneDraft? contact,
}) {
  return showJourneySheet<void>(
    context: context,
    builder: (_) => _AddParticipantSheet(
      weddingPlanId: weddingPlanId,
      preset: preset,
      contact: contact,
    ),
  );
}

class _AddParticipantSheet extends StatefulWidget {
  const _AddParticipantSheet({
    required this.weddingPlanId,
    required this.preset,
    required this.contact,
  });

  final String weddingPlanId;
  final ParticipantPreset preset;
  final ContactPhoneDraft? contact;

  @override
  State<_AddParticipantSheet> createState() => _AddParticipantSheetState();
}

class _AddParticipantSheetState extends State<_AddParticipantSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  late String _role = widget.preset.role;
  late PlanRolePermissions _permissions = widget.preset.permissions;
  bool _fromContact = false;
  bool _sending = false;
  String? _phoneError;
  String? _error;
  PlanInvite? _waiting;
  bool _reissued = false;
  AarastFormDraftBinding? _draft;

  @override
  void initState() {
    super.initState();
    final contact = widget.contact;
    if (contact != null) {
      _useContact(contact);
    } else {
      _draft = AarastFormDraftBinding(
        store: context.read<AarastFormDraftStore?>(),
        scope: 'sharing:${widget.weddingPlanId}:invite',
        fields: {'name': _name, 'phone': _phone},
        readExtras: () => {
          'role': _role,
          'canViewMoney': _permissions.canViewMoney,
          'canManageMoney': _permissions.canManageMoney,
          'canManageTasks': _permissions.canManageTasks,
          'canManageGuests': _permissions.canManageGuests,
          'canManageProviders': _permissions.canManageProviders,
        },
        // The levels come back only for the role that was tapped, so a
        // preset card always opens on what it says.
        restoreExtras: (data) {
          if (!mounted || data['role'] != _role) return;
          setState(() {
            _permissions = _permissions.copyWith(
              canViewMoney: data['canViewMoney'] as bool?,
              canManageMoney: data['canManageMoney'] as bool?,
              canManageTasks: data['canManageTasks'] as bool?,
              canManageGuests: data['canManageGuests'] as bool?,
              canManageProviders: data['canManageProviders'] as bool?,
            );
          });
        },
        onStatusChanged: () {
          if (mounted) setState(() {});
        },
      );
      unawaited(_draft!.restore());
    }
  }

  @override
  void dispose() {
    _draft?.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _useContact(ContactPhoneDraft contact) {
    _name.text = contact.name;
    _phone.text = contact.normalizedPhone ?? contact.rawPhone;
    _fromContact = true;
    _phoneError = null;
  }

  Future<void> _pickContact() async {
    try {
      final contact = await ContactPickerService.pickContact(context);
      if (!mounted || contact == null) return;
      setState(() => _useContact(contact));
    } on Object catch (error) {
      if (mounted) {
        AarastToast.showError(context, contactPickerErrorMessage(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _waiting;
    return waiting == null ? _form() : _created(waiting);
  }

  Widget _form() {
    final name = _name.text.trim();
    final phone = participantPhone(_phone.text);
    return JourneySheetBody(
      title: _fromContact && name.isNotEmpty
          ? '${context.say('أضف', 'أضيفي')} $name'
          : context.say('أضف مشارك', 'أضيفي مشارك'),
      // The number reads left to right inside the Arabic line (g06).
      subtitle: _fromContact && phone != null
          ? PhoneNumberUtils.isolateLtr(phone)
          : null,
      children: [
        if (!_fromContact) ...[
          JourneyTextField(
            key: const ValueKey('participant-name'),
            label: 'الاسم',
            hint: context.planWord('صالح', 'نورة'),
            controller: _name,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyTextField(
            key: const ValueKey('participant-phone-field'),
            label: 'رقم الجوال',
            hint: '771 554 220',
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            errorText: _phoneError,
            onChanged: (_) {
              if (_phoneError != null) setState(() => _phoneError = null);
            },
          ),
          if (ContactPickerService.isAvailable)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: JourneyTextAction(
                label: 'من جهات الاتصال',
                icon: LucideIcons.contact,
                color: context.accent.primary,
                onPressed: _sending ? null : _pickContact,
              ),
            ),
          const SizedBox(height: AarastV3Space.x3),
        ],
        ParticipantAccessEditor(
          role: _role,
          permissions: _permissions,
          enabled: !_sending,
          onPresetSelected: (preset) {
            setState(() {
              _role = preset.role;
              _permissions = preset.permissions;
            });
            _draft?.changed();
          },
          onChanged: (value) {
            setState(() {
              _permissions = value;
              _role = participantRoleForLevels(_role, value);
            });
            _draft?.changed();
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: AarastV3Space.x2),
          JourneyNote(
            key: const ValueKey('participant-error'),
            icon: LucideIcons.alertCircle,
            color: AarastV3Color.danger,
            soft: AarastV3Color.dangerSoft,
            text: _error!,
          ),
        ],
        const SizedBox(height: AarastV3Space.x3),
        JourneyButton(
          key: const ValueKey('participant-send'),
          label: context.say(
            'أرسل الدعوة على واتساب',
            'أرسلي الدعوة على واتساب',
          ),
          icon: LucideIcons.send,
          large: true,
          expand: true,
          loading: _sending,
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }

  /// WhatsApp did not take the invite: the link is shown this once.
  Widget _created(PlanInvite invite) {
    final note = switch (invite.deliveryStatus) {
      'UNCERTAIN' => context.say(
        'ما تأكدنا إنها وصلته على واتساب. انسخ الرابط وأرسله له بنفسك.',
        'ما تأكدنا إنها وصلته على واتساب. انسخي الرابط وأرسليه له بنفسك.',
      ),
      'PENDING' => context.say(
        'نرسلها له على واتساب الحين. وتقدر تنسخ الرابط وترسله بنفسك.',
        'نرسلها له على واتساب الحين. وتقدرين تنسخين الرابط وترسلينه بنفسك.',
      ),
      _ => context.say(
        'ما قدرنا نرسلها على واتساب. انسخ الرابط وأرسله له بأي طريقة.',
        'ما قدرنا نرسلها على واتساب. انسخي الرابط وأرسليه له بأي طريقة.',
      ),
    };
    final name = invite.name?.trim();
    return JourneySheetBody(
      key: const ValueKey('invite-created-view'),
      title: 'الدعوة جاهزة',
      subtitle: name == null || name.isEmpty
          ? 'يدخل برقمه ويوافق، والرابط يشتغل 7 أيام'
          : '$name يدخل برقمه ويوافق، والرابط يشتغل 7 أيام',
      children: [
        JourneyNote(
          icon: LucideIcons.alertCircle,
          color: AarastV3Color.amber,
          soft: AarastV3Color.amberSoft,
          text: note,
        ),
        const SizedBox(height: AarastV3Space.x3),
        JourneyButton(
          key: const ValueKey('invite-copy-link'),
          label: context.say('انسخ الرابط', 'انسخي الرابط'),
          icon: LucideIcons.copy,
          large: true,
          expand: true,
          onPressed: () => _copyLink(invite),
        ),
        const SizedBox(height: AarastV3Space.x1),
        JourneyTextAction(
          key: const ValueKey('invite-done'),
          label: 'تم',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Future<void> _copyLink(PlanInvite invite) async {
    final text = _reissued
        ? newInviteLinkMessage(invite)
        : InviteShareContent.fromInvite(invite).inviteLink.toString();
    final copied = await copyInviteText(context, text);
    if (!mounted || !copied) return;
    AarastToast.showSuccess(
      context,
      context.say('نسخنا الرابط، أرسله له.', 'نسخنا الرابط، أرسليه له.'),
    );
  }

  String? _checkPhone(SharingProvider provider) {
    final analysis = PhoneNumberUtils.analyze(
      _phone.text,
      required: true,
      requireYemeni: true,
    );
    if (!analysis.isValid) {
      return context.say('اكتب رقم جوال يمني صحيح', 'اكتبي رقم جوال يمني صحيح');
    }
    // J2-12: the signed-in number, compared as the duplicates are; the
    // server says the same (CANNOT_INVITE_SELF).
    final ownKey = PhoneNumberUtils.comparisonKey(_signedInPhone());
    if (ownKey != null &&
        ownKey == PhoneNumberUtils.comparisonKey(_phone.text)) {
      return 'هذا رقمك أنت، الدعوة لغيرك';
    }
    final member = ContactDuplicateUtils.findByPhone(
      provider.members.where(
        (member) => member.weddingPlanId == widget.weddingPlanId,
      ),
      candidatePhone: _phone.text,
      phoneOf: (member) => member.user?.phone,
    );
    if (member != null) return 'هذا الرقم مشارك معك من قبل';
    return null;
  }

  /// The phone of the account signed in now: the live session, else the
  /// session kept on the phone.
  String? _signedInPhone() =>
      context.read<AuthController?>()?.user?.phone ??
      context.read<AuthStorage?>()?.readUser()?.phone;

  Future<void> _send() async {
    final provider = context.read<SharingProvider>();
    final phoneError = _checkPhone(provider);
    if (phoneError != null) {
      setState(() {
        _phoneError = _fromContact ? null : phoneError;
        _error = _fromContact ? phoneError : null;
      });
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final waiting = ContactDuplicateUtils.findByPhone(
      provider.invites.where(
        (invite) =>
            invite.weddingPlanId == widget.weddingPlanId && invite.isPending,
      ),
      candidatePhone: _phone.text,
      phoneOf: (invite) => invite.phone,
    );
    if (waiting != null && !waiting.canRetryDelivery) {
      setState(() {
        _sending = false;
        _error =
            'دعوته محفوظة وأرسلناها قبل شوي. '
            '${context.say('تقدر ترسل', 'تقدرين ترسلين')} له رابط جديد بعد '
            '${waiting.deliveryRetryRemainingSeconds} ثانية.';
      });
      return;
    }
    final PlanInvite? invite;
    if (waiting != null) {
      // Same number already waiting: a new link with these levels; the old
      // link stops working (C31).
      invite = await provider.reissueInvite(
        waiting,
        role: _role,
        permissions: _permissions,
      );
    } else {
      final name = _name.text.trim();
      invite = await provider.createInvite(
        weddingPlanId: widget.weddingPlanId,
        phone: _phone.text,
        name: name.isEmpty ? null : name,
        role: _role,
        canViewMoney: _permissions.canViewMoney,
        canEditPlan: _permissions.canEditPlan,
        canManageTasks: _permissions.canManageTasks,
        canManageGuests: _permissions.canManageGuests,
        canManageProviders: _permissions.canManageProviders,
        canInviteMembers: _permissions.canInviteMembers,
        canManageMoney: _permissions.canManageMoney,
        receiveNotifications: _permissions.receiveNotifications,
      );
    }
    if (!mounted) return;
    if (invite == null) {
      setState(() {
        _sending = false;
        _error =
            provider.errorMessage ??
            context.say(
              'ما قدرنا نرسل الدعوة. جرّب مرة ثانية.',
              'ما قدرنا نرسل الدعوة. جرّبي مرة ثانية.',
            );
      });
      return;
    }
    unawaited(_draft?.clear());
    if (invite.wasDeliveredByAarast) {
      AarastToast.showSuccess(
        context,
        waiting != null
            ? newLinkDeliveredMessage
            : 'وصلته الدعوة على واتساب. يدخل برقمه ويوافق.',
      );
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _sending = false;
      _waiting = invite;
      _reissued = waiting != null;
    });
  }
}
