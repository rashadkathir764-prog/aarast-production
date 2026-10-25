// The home's setup facts (prototype b01). They sit beside the summary
// contract, which is closed (R12B byte parity), and extend its response.
export interface DashboardSetupFacts {
  /**
   * C24: the venue is secured — a confirmed booking with a venue provider,
   * or (for those who see money) a cost in a venue budget category.
   */
  venueSecured: boolean;
  /**
   * D59: of `moneySummary.paid`, what the plan owner's own money paid and
   * what the other party, the family or others paid for the owner (finance's
   * one money read); null for a reader without money rights.
   */
  paidByOwner: string | null;
  paidByOthers: string | null;
}
