import 'package:flutter/material.dart';

import 'package:lucide_icons/lucide_icons.dart';

import '../../core/contacts/contact_picker_service.dart';
import '../../core/phone/phone_number_utils.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/aarast_toast.dart';
import '../../core/widgets/aarast_ui.dart';
import '../models/contact_phone_draft.dart';

class ContactPhoneField extends StatefulWidget {
  const ContactPhoneField({
    required this.phoneController,
    this.nameController,
    this.label = 'رقم الجوال',
    this.hintText = 'مثال: 77xxxxxxx',
    this.optional = true,
    this.requireYemeni = false,
    this.enabled = true,
    this.helperText,
    this.duplicateMessage,
    this.duplicateIsBlocking = true,
    this.planContacts = const [],
    this.onDraftChanged,
    super.key,
  });

  final TextEditingController phoneController;
  final TextEditingController? nameController;
  final String label;
  final String hintText;
  final bool optional;
  final bool requireYemeni;
  final bool enabled;
  final String? helperText;
  final String? duplicateMessage;
  final bool duplicateIsBlocking;
  final List<ContactPhoneDraft> planContacts;
  final ValueChanged<ContactPhoneDraft>? onDraftChanged;

  @override
  State<ContactPhoneField> createState() => _ContactPhoneFieldState();
}

class _ContactPhoneFieldState extends State<ContactPhoneField> {
  bool _isPicking = false;

  PhoneNumberAnalysis get _analysis => PhoneNumberUtils.analyze(
    widget.phoneController.text,
    required: !widget.optional,
    requireYemeni: widget.requireYemeni,
  );

  @override
  Widget build(BuildContext context) {
    final analysis = _analysis;
    final statusMessage = widget.duplicateMessage ?? _statusMessage(analysis);
    final statusColor = widget.duplicateMessage != null
        ? widget.duplicateIsBlocking
              ? Theme.of(context).colorScheme.error
              : AppTheme.warning
        : analysis.isWarning
        ? AppTheme.warning
        : analysis.isValid
        ? AppTheme.success
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.phoneController,
          enabled: widget.enabled,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
          onChanged: (value) {
            setState(() {});
            widget.onDraftChanged?.call(
              ContactPhoneDraft.fromInput(
                name: widget.nameController?.text ?? '',
                rawPhone: value,
                source: ContactPhoneSource.manual,
                requireYemeni: widget.requireYemeni,
              ),
            );
          },
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hintText,
            prefixIcon: const Icon(LucideIcons.phone),
          ),
          validator: (value) {
            final validation = PhoneNumberUtils.analyze(
              value,
              required: !widget.optional,
              requireYemeni: widget.requireYemeni,
            );
            if (validation.isInvalid) {
              return validation.message ?? PhoneNumberUtils.invalidMessage;
            }
            if (widget.duplicateIsBlocking && widget.duplicateMessage != null) {
              return widget.duplicateMessage;
            }
            return null;
          },
        ),
        const SizedBox(height: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  statusMessage,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Wrap(
                spacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: !widget.enabled || _isPicking
                        ? null
                        : _pickContact,
                    icon: _isPicking
                        ? const AarastInlineSpinner(dimension: 16)
                        : const Icon(LucideIcons.contact, size: 18),
                    label: const Text('اختيار من جهات الاتصال'),
                  ),
                  if (widget.planContacts.isNotEmpty)
                    TextButton.icon(
                      onPressed: !widget.enabled || _isPicking
                          ? null
                          : _pickPlanContact,
                      icon: const Icon(LucideIcons.users, size: 18),
                      label: const Text('اختيار من جهات الخطة'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String? _statusMessage(PhoneNumberAnalysis analysis) {
    if (analysis.isEmpty) {
      return widget.helperText ??
          (widget.optional ? PhoneNumberUtils.optionalPhoneMessage : null);
    }
    if (analysis.isWarning || analysis.isValid) return analysis.message;
    return widget.helperText;
  }

  Future<void> _pickContact() async {
    setState(() => _isPicking = true);
    try {
      final contact = await ContactPickerService.pickContact(context);
      if (contact == null || !mounted) return;
      _applyDraft(contact);
    } catch (error) {
      if (!mounted) return;
      AarastToast.showError(context, contactPickerErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _pickPlanContact() async {
    final selected = await showAarastBottomSheet<ContactPhoneDraft>(
      context: context,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              children: [
                const Text(
                  'اختيار من جهات الخطة',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 8),
                for (final contact in widget.planContacts)
                  ListTile(
                    leading: const Icon(LucideIcons.user),
                    title: Text(
                      contact.name.isEmpty ? 'جهة اتصال' : contact.name,
                    ),
                    subtitle: AarastPhoneText(
                      phone:
                          contact.displayPhone ??
                          contact.normalizedPhone ??
                          contact.rawPhone,
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(contact),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    _applyDraft(selected);
  }

  void _applyDraft(ContactPhoneDraft contact) {
    final phone = contact.normalizedPhone ?? contact.rawPhone;
    widget.phoneController.text = phone;
    widget.phoneController.selection = TextSelection.collapsed(
      offset: phone.length,
    );

    final selectedName = contact.name.trim();
    if (widget.nameController != null && selectedName.isNotEmpty) {
      widget.nameController!.text = selectedName;
      widget.nameController!.selection = TextSelection.collapsed(
        offset: selectedName.length,
      );
    }

    widget.onDraftChanged?.call(contact);
    setState(() {});
  }
}
