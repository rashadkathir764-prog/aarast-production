class OfflineTables {
  const OfflineTables._();

  static const localMeta = 'local_meta';
  static const syncQueue = 'sync_queue';
  static const currentUserProfile = 'current_user_profile';
  static const cachedWeddingPlans = 'cached_wedding_plans';
  static const cachedPlanMembers = 'cached_plan_members';
  static const cachedGuests = 'cached_guests';
  static const cachedTasks = 'cached_tasks';
  static const cachedBudgetCategories = 'cached_budget_categories';
  static const cachedCosts = 'cached_costs';
  static const cachedCostPayments = 'cached_cost_payments';
  static const cachedPaymentSchedules = 'cached_payment_schedules';
  static const cachedProviderCategories = 'cached_provider_categories';
  static const cachedCities = 'cached_cities';
  static const cachedGovernorates = 'cached_governorates';
  static const cachedDistricts = 'cached_districts';
  static const cachedProviders = 'cached_providers';
  static const cachedProviderServices = 'cached_provider_services';
  static const cachedProviderPackages = 'cached_provider_packages';
  static const cachedBookings = 'cached_bookings';
  static const cachedFavoriteProviders = 'cached_favorite_providers';

  static const cacheTables = [
    currentUserProfile,
    cachedWeddingPlans,
    cachedPlanMembers,
    cachedGuests,
    cachedTasks,
    cachedBudgetCategories,
    cachedCosts,
    cachedCostPayments,
    cachedPaymentSchedules,
    cachedProviderCategories,
    cachedCities,
    cachedGovernorates,
    cachedDistricts,
    cachedProviders,
    cachedProviderServices,
    cachedProviderPackages,
    cachedBookings,
    cachedFavoriteProviders,
  ];

  static const planScopedCacheTables = [
    cachedWeddingPlans,
    cachedPlanMembers,
    cachedGuests,
    cachedTasks,
    cachedBudgetCategories,
    cachedCosts,
    cachedCostPayments,
    cachedPaymentSchedules,
    cachedBookings,
  ];

  static String? tableForEntityType(String entityType) {
    return switch (entityType) {
      'user' => currentUserProfile,
      'wedding_plan' => cachedWeddingPlans,
      'plan_member' => cachedPlanMembers,
      'guest' => cachedGuests,
      'task' => cachedTasks,
      'budget_category' => cachedBudgetCategories,
      'cost' => cachedCosts,
      'cost_payment' => cachedCostPayments,
      'payment_schedule' => cachedPaymentSchedules,
      'provider_category' => cachedProviderCategories,
      'city' => cachedCities,
      'governorate' => cachedGovernorates,
      'district' => cachedDistricts,
      'provider' => cachedProviders,
      'provider_service' => cachedProviderServices,
      'provider_package' => cachedProviderPackages,
      'booking' || 'quote_request' => cachedBookings,
      'favorite_provider' => cachedFavoriteProviders,
      _ => null,
    };
  }
}
