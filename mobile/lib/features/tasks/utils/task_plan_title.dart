import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;

/// The plan's name as the reader's chosen plan has it, for words that leave
/// the app (a shared progress, a task sent to its person); null when the
/// chosen plan is another one or has no name.
String? taskPlanTitle(BuildContext context, String weddingPlanId) {
  final selected = context.read<AccountContextController?>()?.selectedContext;
  if (selected?.weddingPlanId?.toString() != weddingPlanId) return null;
  final name = selected?.displayName.trim() ?? '';
  return name.isEmpty ? null : name;
}
