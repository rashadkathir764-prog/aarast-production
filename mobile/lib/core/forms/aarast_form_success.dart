import 'package:flutter/material.dart';

import '../widgets/aarast_toast.dart';

/// One quiet success receipt with an optional next useful action.
///
/// Forms that already navigate to their truthful destination may omit
/// [nextLabel]. The receipt then confirms the mutation without adding a dialog.
class AarastFormSuccess {
  const AarastFormSuccess._();

  static void show(
    BuildContext context, {
    required String message,
    String? nextLabel,
    VoidCallback? onNext,
  }) {
    assert((nextLabel == null) == (onNext == null));
    AarastToast.showSuccess(
      context,
      message,
      action: nextLabel == null
          ? null
          : SnackBarAction(label: nextLabel, onPressed: onNext!),
    );
  }
}
