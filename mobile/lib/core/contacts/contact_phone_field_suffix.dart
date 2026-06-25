import 'package:flutter/material.dart';

import '../../shared/models/contact_phone_draft.dart';
import 'contact_picker_service.dart';

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
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.contacts_outlined),
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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(contactPickerErrorMessage(error))),
        );
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }
}
