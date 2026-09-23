import { Inject, Injectable } from "@nestjs/common";
import {
  CATALOG_READ_PORT,
  type CatalogReadPort,
} from "../modules/catalog/public/catalog-read.port";
import {
  FINANCE_PORT,
  type FinancePort,
} from "../modules/finance/public/finance.port";
import {
  GUESTS_PORT,
  type GuestsPort,
} from "../modules/guests/public/guests.port";
import {
  USER_READ_PORT,
  type UserReadPort,
} from "../modules/identity/public/user-read.port";
import {
  PROVIDER_READ_PORT,
  type ProviderReadPort,
} from "../modules/marketplace/public/provider-read.port";
import {
  QUOTE_READ_PORT,
  type QuoteReadPort,
} from "../modules/marketplace/public/quote-read.port";
import {
  PLAN_READ_PORT,
  type PlanReadPort,
} from "../modules/planning/public/plan-read.port";
import {
  TASKS_PORT,
  type TasksPort,
} from "../modules/tasks/public/tasks.port";

// Insights owns no tables: the dashboard and the timeline compose what the
// owners serve through their ports on the caller's client (the design's
// "read composition over ports only"). This holder keeps the owner ports
// the two read models share in one place.
@Injectable()
export class InsightsReadPorts {
  constructor(
    @Inject(PLAN_READ_PORT) readonly plans: PlanReadPort,
    @Inject(TASKS_PORT) readonly tasks: TasksPort,
    @Inject(GUESTS_PORT) readonly guests: GuestsPort,
    @Inject(FINANCE_PORT) readonly finance: FinancePort,
    @Inject(PROVIDER_READ_PORT) readonly providers: ProviderReadPort,
    @Inject(QUOTE_READ_PORT) readonly quotes: QuoteReadPort,
    @Inject(USER_READ_PORT) readonly users: UserReadPort,
    @Inject(CATALOG_READ_PORT) readonly catalog: CatalogReadPort,
  ) {}
}
