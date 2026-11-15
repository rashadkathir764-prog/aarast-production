/// Whether [planId] names a plan kept on the phone only (made before the
/// person signed in), not an account plan the server keeps.
///
/// D25 of the guests closing round (D116): the one rule; the guests, tasks
/// and money layers and the sign-in guard each held a copy of it.
bool isLocalPlanId(String? planId) {
  final value = planId?.trim() ?? '';
  return value.isEmpty ||
      value == 'local-guest-plan' ||
      value.startsWith('guest-plan-') ||
      value.startsWith('local-guest-');
}
