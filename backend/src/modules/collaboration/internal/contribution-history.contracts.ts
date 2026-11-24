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
  /**
   * RA-BE-176 (D124): for a guest, a member or an invitation, its name read
   * now from it, or «محذوف» once it is gone (null when it has none); null
   * for every other entity. The snapshot keeps no person's name.
   */
  subjectName: string | null;
  provenance: ContributionProvenance;
  occurredAt: string | null;
  capturedAt: string;
}

export interface ContributionHistoryPageResponse {
  historyCoverageStartsAt: string;
  events: ContributionHistoryItemResponse[];
  total: number;
}
