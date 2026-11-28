import '../../../core/l10n/aarast_text.dart';

/// Who reads a group of notices: the couple's side (a groom, a bride, a
/// member of their team), only the plan's owner, only a member of someone
/// else's plan, only a provider, or nobody (the server writes none today).
enum NoticeAudience { couple, planOwner, planMember, provider, nobody }

/// The settings page's reader, as their account stands: the audiences
/// whose notices they can get.
class NoticeReader {
  const NoticeReader._(
    this.audiences, {
    this.alsoProvider = false,
    this.bridePlan = false,
  });

  /// The couple's page: a plan's side, the owner's money when they own a
  /// plan, a member's notices when they help in someone else's, and one
  /// phrase for a provider's customers when the account has a provider
  /// profile ([alsoProvider]): his notices are under the same switch.
  /// [bridePlan]: the open plan is a bride's, so its guests are «الضيفات».
  factory NoticeReader.couple({
    required bool ownsPlan,
    required bool memberOfPlan,
    required bool hasProviderProfile,
    bool bridePlan = false,
  }) => NoticeReader._(
    {
      NoticeAudience.couple,
      if (ownsPlan) NoticeAudience.planOwner,
      if (memberOfPlan) NoticeAudience.planMember,
    },
    alsoProvider: hasProviderProfile,
    bridePlan: bridePlan,
  );

  /// The provider's own page: his business only.
  static const provider = NoticeReader._({NoticeAudience.provider});

  final Set<NoticeAudience> audiences;
  final bool alsoProvider;
  final bool bridePlan;

  bool get ownsPlan => audiences.contains(NoticeAudience.planOwner);
}

/// A group of notice types said in one phrase on the settings page, in the
/// order the phrases are said. Each notice type of the server falls in one
/// group per side (`noticeGroupsOf`); a type with no group is a test
/// failure (`notice_coverage_test.dart` reads the server's own answer).
enum NoticeGroup {
  taskAssigned(NoticeAudience.couple),
  taskReminders(NoticeAudience.couple),
  countdown(NoticeAudience.couple),
  payments(NoticeAudience.couple),
  loans(NoticeAudience.planOwner),
  promised(NoticeAudience.planOwner),
  budget(NoticeAudience.planOwner),
  bookingReminder(NoticeAudience.couple),
  offers(NoticeAudience.couple),
  chats(NoticeAudience.couple),
  bookingNews(NoticeAudience.couple),
  reviewReply(NoticeAudience.couple),
  customerRequests(NoticeAudience.provider),
  customerChats(NoticeAudience.provider),
  offerAnswers(NoticeAudience.provider),
  customerBookings(NoticeAudience.provider),
  reviews(NoticeAudience.provider),
  invitations(NoticeAudience.couple),
  guestReplies(NoticeAudience.couple),
  memberAccess(NoticeAudience.planMember),
  planStatus(NoticeAudience.planMember),
  teamDecisions(NoticeAudience.provider),
  featured(NoticeAudience.provider),

  /// `SYNC_REQUIRED` and `GENERAL`: in the enum, but no writer on the
  /// server makes one, so the page does not promise them.
  appNews(NoticeAudience.nobody);

  const NoticeGroup(this.audience);

  final NoticeAudience audience;

  /// The phrase, written to follow «يشمل» or «تصلك دائمًا:»; the guests
  /// follow the plan's side ([bridePlan]), not the reader.
  String words(AppText text, {bool bridePlan = false}) => switch (this) {
    taskAssigned => text.coverageTaskAssigned,
    taskReminders => text.coverageTaskReminders,
    countdown => text.coverageCountdown,
    payments => text.coveragePayments,
    loans => text.coverageLoans,
    promised => text.coveragePromised,
    budget => text.coverageBudget,
    bookingReminder => text.coverageBookingReminder,
    offers => text.coverageOffers,
    chats => text.coverageChats,
    bookingNews => text.coverageBookingNews,
    reviewReply => text.coverageReviewReply,
    customerRequests => text.coverageCustomerRequests,
    customerChats => text.coverageCustomerChats,
    offerAnswers => text.coverageOfferAnswers,
    customerBookings => text.coverageCustomerBookings,
    reviews => text.coverageReviews,
    invitations => text.coverageInvitations,
    guestReplies => text.coverageGuestReplies(bridePlan ? 'bride' : 'groom'),
    memberAccess => text.coverageMemberAccess,
    planStatus => text.coveragePlanStatus,
    teamDecisions => text.coverageTeamDecisions,
    featured => text.coverageFeatured,
    appNews => text.coverageAppNews,
  };
}

/// Each notice type of the server, by the side that receives it. A type
/// written for both a customer and a provider (an offer accepted, a
/// message) has a group on each side. Read in the backend: the
/// `*Notification` builders in `src/marketplace/` and `plan-reminders.ts`.
const Map<String, List<NoticeGroup>> _groupsByType = {
  'TASK_ASSIGNED': [NoticeGroup.taskAssigned],
  'TASK_DUE_SOON': [NoticeGroup.taskReminders],
  'TASK_OVERDUE': [NoticeGroup.taskReminders],
  'WEDDING_COUNTDOWN': [NoticeGroup.countdown],
  'PAYMENT_SCHEDULE_DUE_SOON': [NoticeGroup.payments],
  'PAYMENT_SCHEDULE_OVERDUE': [NoticeGroup.payments],
  'LOAN_REPAYMENT_DUE_SOON': [NoticeGroup.loans],
  'LOAN_REPAYMENT_OVERDUE': [NoticeGroup.loans],
  'FUNDING_EXPECTED': [NoticeGroup.promised],
  'BUDGET_CATEGORY_EXCEEDED': [NoticeGroup.budget],
  'BOOKING_REMINDER': [NoticeGroup.bookingReminder],
  'QUOTE_REQUEST_SUBMITTED': [NoticeGroup.offers, NoticeGroup.customerRequests],
  'QUOTE_OFFER_RECEIVED': [NoticeGroup.offers],
  'QUOTE_ACCEPTED': [NoticeGroup.offers, NoticeGroup.offerAnswers],
  'QUOTE_REJECTED': [NoticeGroup.offers, NoticeGroup.offerAnswers],
  'QUOTE_REQUEST_EXPIRING': [NoticeGroup.customerRequests],
  'BOOKING_REQUESTED': [NoticeGroup.customerRequests],
  'CHAT_MESSAGE_RECEIVED': [NoticeGroup.chats, NoticeGroup.customerChats],
  'CONVERSATION_REPORT_CLOSED': [NoticeGroup.chats, NoticeGroup.customerChats],
  'BOOKING_NEWS': [NoticeGroup.bookingNews, NoticeGroup.customerBookings],
  'REVIEW_RECEIVED': [NoticeGroup.reviews],
  'REVIEW_REPLIED': [NoticeGroup.reviewReply],
  'SHARING_INVITATION': [NoticeGroup.invitations],
  'SHARING_INVITE_ACCEPTED': [NoticeGroup.invitations],
  'SHARING_INVITE_DECLINED': [NoticeGroup.invitations],
  'SHARING_UPDATED': [NoticeGroup.memberAccess],
  'PLAN_UPDATED': [NoticeGroup.planStatus],
  'GUEST_RESPONDED': [NoticeGroup.guestReplies],
  'PROVIDER_APPROVED': [NoticeGroup.teamDecisions],
  'PROVIDER_NEEDS_CHANGES': [NoticeGroup.teamDecisions],
  'PROVIDER_REJECTED': [NoticeGroup.teamDecisions],
  'PROVIDER_SUSPENDED': [NoticeGroup.teamDecisions],
  'PROVIDER_IN_REVIEW': [NoticeGroup.teamDecisions],
  'PROVIDER_CLAIM_DECIDED': [NoticeGroup.teamDecisions],
  'PORTFOLIO_REVIEWED': [NoticeGroup.teamDecisions],
  'PROVIDER_PROFILE_CHANGE_REVIEWED': [NoticeGroup.teamDecisions],
  'LISTING_PLAN_CHANGED': [NoticeGroup.featured],
  'SYNC_REQUIRED': [NoticeGroup.appNews],
  'GENERAL': [NoticeGroup.appNews],
};

/// The groups [type] is said in; empty for a type this phone has no words
/// for (a newer server), which is then left out of the lines.
List<NoticeGroup> noticeGroupsOf(String type) =>
    _groupsByType[type] ?? const [];

/// «يشمل …» for the notice [types] under one switch, as [reader] gets
/// them; null when none of them reaches this reader.
String? coverageIncludesLine(
  List<String> types,
  NoticeReader reader, {
  AppText? text,
}) {
  final words = text ?? aarastText;
  final parts = _phrases(types, reader, words);
  if (reader.alsoProvider &&
      types.any(
        (type) => noticeGroupsOf(
          type,
        ).any((group) => group.audience == NoticeAudience.provider),
      )) {
    parts.add(words.coverageYourCustomers);
  }
  if (parts.isEmpty) return null;
  return words.coverageIncludes(_join(parts, words));
}

/// «تصلك دائمًا: …» for the notice types no switch governs; null when
/// none of them reaches this reader.
String? coverageAlwaysLine(
  List<String> types,
  NoticeReader reader, {
  AppText? text,
}) {
  final words = text ?? aarastText;
  final parts = _phrases(types, reader, words);
  if (parts.isEmpty) return null;
  return words.coverageAlways(_join(parts, words));
}

/// The phrases of [types] that reach [reader], once each, in the groups'
/// order.
List<String> _phrases(List<String> types, NoticeReader reader, AppText words) {
  final groups = {
    for (final type in types)
      for (final group in noticeGroupsOf(type))
        if (reader.audiences.contains(group.audience)) group,
  };
  return [
    for (final group in NoticeGroup.values)
      if (groups.contains(group))
        group.words(words, bridePlan: reader.bridePlan),
  ];
}

/// «أ»، «أ وب»، «أ، وب، وج».
String _join(List<String> parts, AppText words) {
  if (parts.length == 2) return words.coveragePair(parts[0], parts[1]);
  return parts.skip(1).fold(parts.first, words.coverageNext);
}
