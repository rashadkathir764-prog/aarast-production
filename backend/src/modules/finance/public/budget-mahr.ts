/**
 * D114: whether the groom's mahr counts inside his budget, as the other
 * contexts (planning's plan writes and read model, the dashboards) apply it.
 * The rule is finance's (`mahr-policy`); this is its public face.
 */
export type { FinanceViolation } from '../domain/finance-violation';
export {
  budgetIncludesMahrViolation,
  mahrCountsInBudget,
} from '../domain/mahr-policy';
