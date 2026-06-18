import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class ContactPickerException implements Exception {
  const ContactPickerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ContactPickerService {
  const ContactPickerService._();

  static Future<String?> pickPhoneNumber(BuildContext context) async {
    final permission = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    if (!_isGranted(permission)) {
      throw const ContactPickerException('تم رفض صلاحية جهات الاتصال');
    }

    final contact = await FlutterContacts.native.showPicker(
      properties: {ContactProperty.phone},
    );
    if (contact == null) return null;

    final phones = _phoneNumbers(contact);
    if (phones.isEmpty) {
      throw const ContactPickerException('لا يوجد رقم هاتف لهذه الجهة');
    }
    if (phones.length == 1) return phones.first;

    if (!context.mounted) return null;
    return showModalBottomSheet<String>(
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
                    'اختاري رقم الهاتف',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  for (final phone in phones)
                    ListTile(
                      leading: const Icon(Icons.phone_outlined),
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
