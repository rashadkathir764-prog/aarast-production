import type { PlanBookedServices } from '../modules/marketplace/public/plan-booked-services';
import type {
  DashboardImportantItemResponse,
  DashboardImportantItemType,
  WeddingPlanDashboardSummaryResponse,
} from './dashboard.contracts';
import type { PlanEssential } from './plan-essentials';

/**
 * J1-04: the home's next steps beside the closed item types (R12B byte
 * parity): the mahr («اتفقتوا على المهر؟») and the first agreement, which
 * come after the budget and before the guests.
 */
export type DashboardNextStepType =
  | DashboardImportantItemType
  | 'RECORD_MAHR'
  | 'ADD_FIRST_COST';

/** A next step on the home: the closed item, with the wider type. */
export type DashboardNextStepResponse = Omit<
  DashboardImportantItemResponse,
  'type'
> & { type: DashboardNextStepType };

/** The summary the home reads: the closed contract, its next steps widened. */
export type DashboardSummaryWithSetupResponse = Omit<
  WeddingPlanDashboardSummaryResponse,
  'importantItems' | 'nextBestActions'
> &
  DashboardSetupFacts;

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
  /** The next steps, first one first (J1-04: one ordered source). */
  importantItems: DashboardNextStepResponse[];
  nextBestActions: DashboardNextStepResponse[];
}
