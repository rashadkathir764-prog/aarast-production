import 'dart:async';

import 'package:flutter/widgets.dart';

import 'aarast_form_draft_store.dart';

typedef AarastDraftExtrasReader = Map<String, dynamic> Function();
typedef AarastDraftExtrasRestorer = void Function(Map<String, dynamic> data);

/// يربط حقول أي نموذج غير حساس بمخزن المسودات المشفّر.
///
/// الحقول النصية تُراقب تلقائيًا، بينما تستدعي الشاشات [changed] بعد تعديل
/// التاريخ أو القوائم والاختيارات. لا تستخدم هذه الطبقة مع كلمات المرور أو OTP.
class AarastFormDraftBinding {
  AarastFormDraftBinding({
    required AarastFormDraftStore? store,
    required String scope,
    required Map<String, TextEditingController> fields,
    this.readExtras,
    this.restoreExtras,
    this.onStatusChanged,
  }) : _fields = Map.unmodifiable(fields),
       _coordinator = AarastFormDraftCoordinator(
         store: store,
         scope: scope,
         onStatusChanged: onStatusChanged,
       ) {
    for (final controller in _fields.values) {
      controller.addListener(_schedule);
    }
  }

  final Map<String, TextEditingController> _fields;
  final AarastDraftExtrasReader? readExtras;
  final AarastDraftExtrasRestorer? restoreExtras;
  final VoidCallback? onStatusChanged;
  final AarastFormDraftCoordinator _coordinator;

  bool _restoring = false;
  bool _disposed = false;

  AarastFormDraftStatus get status => _coordinator.status;

  Future<bool> restore() async {
    final data = await _coordinator.restore();
    if (_disposed || data == null) return false;
    _restoring = true;
    try {
      for (final entry in _fields.entries) {
        final value = data[entry.key];
        if (value != null) entry.value.text = value.toString();
      }
      restoreExtras?.call(data);
    } finally {
      _restoring = false;
    }
    onStatusChanged?.call();
    return true;
  }

  /// يُستدعى بعد تغيير قيمة غير نصية مثل التاريخ أو Dropdown.
  void changed() => _schedule();

  Future<void> clear() => _coordinator.clear();

  void _schedule() {
    if (_disposed || _restoring) return;
    _coordinator.schedule({
      for (final entry in _fields.entries) entry.key: entry.value.text,
      ...?readExtras?.call(),
    });
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final controller in _fields.values) {
      controller.removeListener(_schedule);
    }
    _coordinator.dispose();
  }
}
