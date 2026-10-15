import 'package:flutter/widgets.dart';

/// Takes focus away from the text field being edited before a picker, sheet
/// or dialog opens.
///
/// Unfocusing the field itself (not its scope) also drops it from the page's
/// focus history, so closing the overlay does not hand focus — and the
/// keyboard — back to it. `FocusScope.of(context).unfocus()` does not: the
/// scope keeps the field as its last focused child and restores it.
void releaseFieldFocus() {
  FocusManager.instance.primaryFocus?.unfocus();
}
