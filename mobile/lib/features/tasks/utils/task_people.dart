import '../../sharing/sharing_api.dart' show SharedMember;
import '../models/wedding_task.dart';

/// The plan's members among whatever the sharing list holds.
List<SharedMember> planMembers(
  List<SharedMember> members,
  String weddingPlanId,
) => [
  for (final member in members)
    if (member.weddingPlanId == weddingPlanId) member,
];

/// A task given to a member carries only the member's account; the name,
/// phone and role come from the plan's members. Every screen that shows the
/// task names them the same way, the task page as the list (RA-MO-57: the
/// page said «عضو مشارك» with no call).
WeddingTask withMemberNamed(WeddingTask task, List<SharedMember> members) {
  if (!task.hasResponsibleParticipant) return task;
  for (final member in members) {
    if (member.userId != task.assigneeUserId) continue;
    return task.copyWith(
      assigneeName: member.displayName,
      assigneePhone: member.user?.phone,
      assigneeRole: member.role,
    );
  }
  return task;
}
