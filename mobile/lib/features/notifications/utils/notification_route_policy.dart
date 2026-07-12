bool isSafeNotificationRouteTarget(String target) {
  if (!target.startsWith('/') || target.contains('://')) return false;
  return target == '/providers' ||
      target.startsWith('/providers/') ||
      target.startsWith('/conversations/') ||
      target.startsWith('/invites/') ||
      target.startsWith('/wedding-plans/');
}
