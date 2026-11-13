part of 'create_task_screen.dart';

// «لمين؟» as keys: «أنا» (`me`), a plan member (`member:<userId>`), a person
// already given a task (`name:<name>`), or «شخص ثاني» typed in.

const _whoMe = 'me';
const _memberPrefix = 'member:';
const _namePrefix = 'name:';

/// A person already responsible for a task, offered again with their number.
typedef _KnownPerson = ({
  String name,
  String? phone,
  ContactPhoneSource source,
});

/// Who is responsible, as it will be saved.
typedef _Responsible = ({
  String? assigneeUserId,
  String? assigneeName,
  String? assigneePhone,
  String? assigneeRole,
  String? responsibleName,
  String? responsiblePhone,
  String? responsibleSource,
});

extension _CreateTaskWho on _CreateTaskScreenState {
  /// Manual responsible people from the plan's other tasks, by name.
  Map<String, _KnownPerson> _knownPeople(TaskTimelineProvider provider) {
    final people = <String, _KnownPerson>{};
    for (final task in provider.tasks) {
      if (task.weddingPlanId != widget.weddingPlanId) continue;
      if (task.hasResponsibleParticipant) continue;
      final name = task.responsibleName?.trim();
      if (name == null || name.isEmpty || isSelfTaskLabel(name)) continue;
      people.putIfAbsent(
        name,
        () => (
          name: name,
          phone: task.responsiblePhone,
          source: contactPhoneSourceFromTask(task),
        ),
      );
    }
    return people;
  }

  /// «أنا», the other members, then the people already given tasks.
  List<(String, String)> _whoChoices(
    TaskTimelineProvider provider,
    List<SharedMember> members,
    String? currentUserId,
  ) {
    final choices = <(String, String)>[(_whoMe, 'أنا')];
    for (final member in members) {
      if (member.userId == currentUserId) continue;
      choices.add(('$_memberPrefix${member.userId}', member.displayName));
    }
    // A member the edited task points to but the list has not loaded yet.
    final assignee = _assigneeUserId;
    if (assignee != null &&
        assignee != currentUserId &&
        !choices.any((choice) => choice.$1 == '$_memberPrefix$assignee')) {
      choices.add(('$_memberPrefix$assignee', _assigneeName ?? 'عضو مشارك'));
    }
    for (final name in _knownPeople(provider).keys) {
      choices.add(('$_namePrefix$name', name));
    }
    return choices;
  }

  /// The «لمين؟» key an existing task opens with.
  String _whoForTask(WeddingTask task, String? currentUserId) {
    final assignee = task.assigneeUserId;
    if (assignee != null && assignee.isNotEmpty) {
      return assignee == currentUserId ? _whoMe : '$_memberPrefix$assignee';
    }
    final name = task.responsibleName?.trim();
    if (name == null || name.isEmpty || isSelfTaskLabel(name)) return _whoMe;
    return '$_namePrefix$name';
  }

  /// What the chosen person saves as, or null (with the field's message)
  /// when «شخص ثاني» has no name or «أنا» cannot be matched to the account.
  _Responsible? _responsibleFor(
    TaskTimelineProvider provider,
    List<SharedMember> members,
    String? currentUserId,
  ) {
    const nobody = (
      assigneeUserId: null,
      assigneeName: null,
      assigneePhone: null,
      assigneeRole: null,
      responsibleName: null,
      responsiblePhone: null,
      responsibleSource: null,
    );
    final who = _who;
    if (who == _whoMe) {
      // A guest's plan has no accounts: «أنا» is simply nobody else.
      if (AuthActionGuard.isLocalGuestPlanId(widget.weddingPlanId)) {
        return nobody;
      }
      final self = findCurrentSharedMember(members, currentUserId);
      if (self == null) {
        // RA-MO-194: «أنا» is the reader's own account, known without the
        // list of participants. Saving waited for that list and stopped
        // with «ما قدرنا نلقى حسابك في الخطة» while it had not arrived:
        // without a connection, on a first open, and for a helper whose
        // list failed whole. The account's id is what is saved either way.
        if (currentUserId == null || currentUserId.isEmpty) {
          AarastToast.showError(
            context,
            context.say(
              'ما قدرنا نلقى حسابك. جرّب مرة ثانية.',
              'ما قدرنا نلقى حسابك. جرّبي مرة ثانية.',
            ),
          );
          return null;
        }
        return (
          assigneeUserId: currentUserId,
          assigneeName: context.read<AuthController?>()?.user?.name,
          assigneePhone: null,
          assigneeRole: null,
          responsibleName: null,
          responsiblePhone: null,
          responsibleSource: null,
        );
      }
      return (
        assigneeUserId: self.userId,
        assigneeName: self.displayName,
        assigneePhone: self.user?.phone,
        assigneeRole: self.role,
        responsibleName: null,
        responsiblePhone: null,
        responsibleSource: null,
      );
    }
    if (who.startsWith(_memberPrefix)) {
      final userId = who.substring(_memberPrefix.length);
      SharedMember? member;
      for (final item in members) {
        if (item.userId == userId) member = item;
      }
      return (
        assigneeUserId: userId,
        assigneeName: member?.displayName ?? _assigneeName,
        assigneePhone: member?.user?.phone ?? _assigneePhone,
        assigneeRole: member?.role ?? _assigneeRole,
        responsibleName: null,
        responsiblePhone: null,
        responsibleSource: null,
      );
    }
    if (who.startsWith(_namePrefix)) {
      final person = _knownPeople(provider)[who.substring(_namePrefix.length)];
      if (person != null) {
        return (
          assigneeUserId: null,
          assigneeName: null,
          assigneePhone: null,
          assigneeRole: null,
          responsibleName: person.name,
          responsiblePhone: person.phone,
          responsibleSource: person.source.name,
        );
      }
    }
    final name = _otherNameController.text.trim();
    if (name.isEmpty || isSelfTaskLabel(name)) {
      if (isSelfTaskLabel(name)) {
        _mutateDraft(() => _who = _whoMe);
        return _responsibleFor(provider, members, currentUserId);
      }
      _mutateDraft(
        () => _otherNameError = context.say('اكتب اسمه', 'اكتبي اسمه'),
      );
      return null;
    }
    return (
      assigneeUserId: null,
      assigneeName: null,
      assigneePhone: null,
      assigneeRole: null,
      responsibleName: name,
      responsiblePhone: PhoneNumberUtils.normalizeOptional(
        _otherPhoneController.text,
      ),
      responsibleSource: _otherSource.name,
    );
  }
}
