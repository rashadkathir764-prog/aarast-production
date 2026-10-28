/// D63 (w05): what deleting the account takes with it, as the server reads it.
class AccountDeletionImpact {
  const AccountDeletionImpact({
    required this.graceDays,
    required this.ownedPlans,
    required this.memberOfPlans,
    required this.provider,
    required this.blockedByUpcomingBookings,
  });

  factory AccountDeletionImpact.fromJson(Map<String, dynamic> json) {
    final plans = json['ownedPlans'];
    final provider = json['provider'];
    return AccountDeletionImpact(
      graceDays: _int(json['graceDays']),
      ownedPlans: plans is List
          ? [
              for (final plan in plans)
                if (plan is Map<String, dynamic>)
                  DeletionPlanImpact.fromJson(plan),
            ]
          : const [],
      memberOfPlans: _int(json['memberOfPlans']),
      provider: provider is Map<String, dynamic>
          ? DeletionProviderImpact(
              businessName: provider['businessName']?.toString() ?? '',
              upcomingBookings: _int(provider['upcomingBookings']),
            )
          : null,
      blockedByUpcomingBookings:
          json['blockedBy']?.toString() == 'PROVIDER_HAS_UPCOMING_BOOKINGS',
    );
  }

  final int graceDays;
  final List<DeletionPlanImpact> ownedPlans;
  final int memberOfPlans;
  final DeletionProviderImpact? provider;

  /// B-33: a provider with weddings still to do cannot ask yet.
  final bool blockedByUpcomingBookings;

  /// The members told across the owned plans, by first name, once each.
  List<String> get memberNames => [
    for (final name in {for (final plan in ownedPlans) ...plan.memberNames})
      name,
  ];

  int get upcomingBookings =>
      ownedPlans.fold(0, (total, plan) => total + plan.upcomingBookings);
}

class DeletionPlanImpact {
  const DeletionPlanImpact({
    required this.id,
    required this.title,
    required this.memberNames,
    required this.upcomingBookings,
  });

  factory DeletionPlanImpact.fromJson(Map<String, dynamic> json) {
    final names = json['memberNames'];
    return DeletionPlanImpact(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      memberNames: names is List
          ? [for (final name in names) name.toString()]
          : const [],
      upcomingBookings: _int(json['upcomingBookings']),
    );
  }

  final String id;
  final String title;
  final List<String> memberNames;
  final int upcomingBookings;
}

class DeletionProviderImpact {
  const DeletionProviderImpact({
    required this.businessName,
    required this.upcomingBookings,
  });

  final String businessName;
  final int upcomingBookings;
}

int _int(Object? value) => switch (value) {
  final int number => number,
  final num number => number.toInt(),
  _ => int.tryParse(value?.toString() ?? '') ?? 0,
};
