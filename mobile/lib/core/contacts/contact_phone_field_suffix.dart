import 'package:flutter/material.dart';

import 'package:lucide_icons/lucide_icons.dart';

import '../../shared/models/contact_phone_draft.dart';
import '../widgets/aarast_toast.dart';
import 'contact_picker_service.dart';
import '../experience_v3/aarast_v3_foundations.dart';

class ContactPhoneFieldSuffix extends StatefulWidget {
  const ContactPhoneFieldSuffix({
    required this.controller,
    this.enabled = true,
    this.nameController,
    this.onContactSelected,
    this.onPhoneSelected,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final TextEditingController? nameController;
  final ValueChanged<ContactPhoneDraft>? onContactSelected;
  final ValueChanged<String>? onPhoneSelected;

  @override
  State<ContactPhoneFieldSuffix> createState() =>
      _ContactPhoneFieldSuffixState();
}

class _ContactPhoneFieldSuffixState extends State<ContactPhoneFieldSuffix> {
  bool _isPicking = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'اختيار من جهات الاتصال',
      onPressed: !widget.enabled || _isPicking ? null : _pickPhone,
      icon: _isPicking
          ? const SizedBox(
              width: AarastV3Space.x4,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(LucideIcons.contact),
    );
  }

  Future<void> _pickPhone() async {
    setState(() => _isPicking = true);
    try {
      final contact = await ContactPickerService.pickContact(context);
      if (contact == null || !mounted) return;
      final phone = contact.normalizedPhone ?? contact.rawPhone;
      widget.controller.text = phone;
      widget.controller.selection = TextSelection.collapsed(
        offset: widget.controller.text.length,
      );
      final selectedName = contact.name.trim();
      if (widget.nameController != null && selectedName.isNotEmpty) {
        widget.nameController!.text = selectedName;
        widget.nameController!.selection = TextSelection.collapsed(
          offset: selectedName.length,
        );
      }
      widget.onContactSelected?.call(contact);
      widget.onPhoneSelected?.call(phone);
    } catch (error) {
      if (!mounted) return;
      AarastToast.showError(context, contactPickerErrorMessage(error));
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }
}
