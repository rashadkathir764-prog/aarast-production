import type { PlanBookedServices } from '../modules/marketplace/public/plan-booked-services';
import type { PlanEssential } from './plan-essentials';

// The home's setup facts (prototype b01). They sit beside the summary
// contract, which is closed (R12B byte parity), and extend its response.
export interface DashboardSetupFacts {
  /**
   * C24: the venue is secured — a confirmed booking with a venue provider,
   * or (for those who see money) a cost in a venue budget category.
   */
  venueSecured: boolean;
  /**
   * D60: the plan's booked services by the one definition of «محجوز»
   * (`plan-booked-services.ts`): the home's tile and the providers board.
   */
  bookedServices: PlanBookedServices;
  /**
   * D59: of `moneySummary.paid`, what the plan owner's own money paid and
   * what the other party, the family or others paid for the owner (finance's
   * one money read); null for a reader without money rights.
   */
  paidByOwner: string | null;
  /**
   * G23: the six essentials the owner named and where each stands; null for
   * a reader who does not see the plan's items (no money rights, or a
   * contributor).
   */
  essentials: PlanEssential[] | null;
  paidByOthers: string | null;
  /**
   * The plan's wedding items (the mahr not counted), so the home asks for the
   * first one only while there is none; null for a reader who does not see
   * the plan's items.
   */
  budgetItemsCount: number | null;
}
