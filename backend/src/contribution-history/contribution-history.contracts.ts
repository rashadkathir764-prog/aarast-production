import {
  ContributionAction,
  ContributionEntityType,
  ContributionProvenance,
  ContributionSection,
} from "@prisma/client";

export interface ContributionHistoryItemResponse {
  id: string;
  contributorReference: string;
  section: ContributionSection;
  entityType: ContributionEntityType;
  action: ContributionAction;
  snapshot: Record<string, unknown>;
  provenance: ContributionProvenance;
  occurredAt: string | null;
  capturedAt: string;
}

export interface ContributionHistoryPageResponse {
  historyCoverageStartsAt: string;
  events: ContributionHistoryItemResponse[];
  total: number;
}
