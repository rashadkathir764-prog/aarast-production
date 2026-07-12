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
  static const cachedBudgetItems = 'cached_budget_items';
  static const cachedFinancialCommitments = 'cached_financial_commitments';
  static const cachedFinancialPaymentRecords =
      'cached_financial_payment_records';
  static const cachedFinancialInstallments = 'cached_financial_installments';
  static const cachedProviderCategories = 'cached_provider_categories';
  static const cachedCities = 'cached_cities';
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
    cachedBudgetItems,
    cachedFinancialCommitments,
    cachedFinancialPaymentRecords,
    cachedFinancialInstallments,
    cachedProviderCategories,
    cachedCities,
    cachedProviders,
    cachedProviderServices,
    cachedProviderPackages,
    cachedBookings,
    cachedFavoriteProviders,
  ];

  static String? tableForEntityType(String entityType) {
    return switch (entityType) {
      'user' => currentUserProfile,
      'wedding_plan' => cachedWeddingPlans,
      'plan_member' => cachedPlanMembers,
      'guest' => cachedGuests,
      'task' => cachedTasks,
      'budget_category' => cachedBudgetCategories,
      'expense' => cachedBudgetItems,
      'financial_commitment' => cachedFinancialCommitments,
      'financial_payment_record' => cachedFinancialPaymentRecords,
      'financial_installment' => cachedFinancialInstallments,
      'provider_category' => cachedProviderCategories,
      'city' => cachedCities,
      'provider' => cachedProviders,
      'provider_service' => cachedProviderServices,
      'provider_package' => cachedProviderPackages,
      'booking' || 'quote_request' => cachedBookings,
      'favorite_provider' => cachedFavoriteProviders,
      _ => null,
    };
  }
}
