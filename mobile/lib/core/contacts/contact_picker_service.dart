import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../shared/models/contact_phone_draft.dart';
import '../widgets/aarast_bottom_sheet.dart';

class ContactPickerException implements Exception {
  const ContactPickerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ContactPickerService {
  const ContactPickerService._();

  static Future<ContactPhoneDraft?> pickContact(BuildContext context) async {
    final permission = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    if (!_isGranted(permission)) {
      throw const ContactPickerException('تم رفض صلاحية جهات الاتصال');
    }

    final contact = await FlutterContacts.native.showPicker(
      properties: {ContactProperty.name, ContactProperty.phone},
    );
    if (contact == null) return null;

    final phones = _phoneNumbers(contact);
    if (phones.isEmpty) {
      throw const ContactPickerException('لا يوجد رقم هاتف لهذه الجهة');
    }

    String? selectedPhone;
    if (phones.length == 1) {
      selectedPhone = phones.first;
    } else {
      if (!context.mounted) return null;
      selectedPhone = await _selectPhone(context, phones);
    }
    if (selectedPhone == null) return null;

    return ContactPhoneDraft.fromInput(
      name: contact.displayName ?? '',
      rawPhone: selectedPhone,
      source: ContactPhoneSource.deviceContact,
    );
  }

  static Future<String?> pickPhoneNumber(BuildContext context) async {
    final contact = await pickContact(context);
    return contact?.normalizedPhone ?? contact?.rawPhone;
  }

  static Future<String?> _selectPhone(
    BuildContext context,
    List<String> phones,
  ) {
    return showAarastBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'اختر رقم الهاتف',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  for (final phone in phones)
                    ListTile(
                      leading: const Icon(LucideIcons.phone),
                      title: Text(
                        phone,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.right,
                      ),
                      onTap: () => Navigator.of(sheetContext).pop(phone),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static bool _isGranted(PermissionStatus status) {
    return status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
  }

  static List<String> _phoneNumbers(Contact contact) {
    final seen = <String>{};
    final phones = <String>[];
    for (final phone in contact.phones) {
      final raw = phone.normalizedNumber?.trim().isNotEmpty == true
          ? phone.normalizedNumber!
          : phone.number;
      final value = raw.trim();
      if (value.isEmpty || !seen.add(value)) continue;
      phones.add(value);
    }
    return phones;
  }
}

String contactPickerErrorMessage(Object error) {
  if (error is ContactPickerException) return error.message;
  if (error is PlatformException) {
    return 'تعذر فتح جهات الاتصال';
  }
  return 'تعذر اختيار رقم من جهات الاتصال';
}
