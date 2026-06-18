import 'package:flutter/material.dart';

import 'contact_picker_service.dart';

class ContactPhoneFieldSuffix extends StatefulWidget {
  const ContactPhoneFieldSuffix({
    required this.controller,
    this.enabled = true,
    this.onPhoneSelected,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
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
      final phone = await ContactPickerService.pickPhoneNumber(context);
      if (phone == null || !mounted) return;
      widget.controller.text = phone;
      widget.controller.selection = TextSelection.collapsed(
        offset: widget.controller.text.length,
      );
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
