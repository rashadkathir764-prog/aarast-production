import { createHash } from "node:crypto";
import { BadRequestException } from "@nestjs/common";
import { ContributionEntityType, Prisma } from "@prisma/client";

type SnapshotSource = Record<string, unknown>;

const forbiddenKey =
  /(phone|email|token|secret|message|note|attachment|method|address|contact|payload|header|query|body)/i;
const allowedSnapshotKeys = new Set([
  "title",
  "status",
  "priority",
  "dueDate",
  "category",
  "displayName",
  "groupDisplayName",
  "side",
  "invitationStatus",
  "attendanceStatus",
  "categoryLabel",
  "currency",
  "totalAmount",
  "paidAmount",
  "amount",
  "relevantDate",
  "providerDisplayLabel",
  "requestStatus",
  "role",
  "permissionLabels",
  "inviteState",
  "planTitle",
  "weddingDate",
]);
const userTextSnapshotKeys = new Set([
  "title",
  "category",
  "displayName",
  "groupDisplayName",
  "categoryLabel",
  "providerDisplayLabel",
  "planTitle",
]);
const MAX_SNAPSHOT_BYTES = 16 * 1024;
const MAX_STRING_BYTES = 2 * 1024;
const MAX_ARRAY_ITEMS = 100;
const MAX_OBJECT_KEYS = 50;
const MAX_DEPTH = 6;
const forbiddenValuePatterns = [
  /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i,
  /\bBearer\s+[A-Za-z0-9._~-]+/i,
  /[?&](?:token|key|secret|signature)=/i,
  /(?:^|\s)\+\d(?:[\s()-]*\d){7,14}(?:$|\s)/,
  /(?:^|[^\d])(?:967[\s().-]*)?7(?:[\s().-]*\d){8}(?!\d)/,
  /^\s*(?:\d[\s()-]*){8,15}\s*$/,
];

export function buildContributionSnapshot(
  entityType: ContributionEntityType,
  source: SnapshotSource,
): Prisma.JsonObject {
  const snapshot = switchSnapshot(entityType, source);
  validateContributionSnapshot(snapshot);
  return snapshot;
}

export function validateContributionSnapshot(
  snapshot: unknown,
): asserts snapshot is Prisma.JsonObject {
  if (!isPlainObject(snapshot)) {
    throw new BadRequestException("Contribution snapshot must be an object");
  }
  for (const key of Object.keys(snapshot)) {
    if (!allowedSnapshotKeys.has(key)) {
      throw new BadRequestException("Unknown contribution snapshot key");
    }
  }
  inspectSnapshot(snapshot);
  if (Buffer.byteLength(canonicalJson(snapshot), "utf8") > MAX_SNAPSHOT_BYTES) {
    throw new BadRequestException("Contribution snapshot exceeds size limit");
  }
}

export function canonicalJson(value: unknown): string {
  return JSON.stringify(canonicalValue(value));
}

export function hashContributionSnapshot(snapshot: unknown): string {
  validateContributionSnapshot(snapshot);
  return createHash("sha256").update(canonicalJson(snapshot)).digest("hex");
}

function switchSnapshot(
  entityType: ContributionEntityType,
  source: SnapshotSource,
): Prisma.JsonObject {
  switch (entityType) {
    case ContributionEntityType.TASK:
    case ContributionEntityType.TASK_CHECKLIST_ITEM:
      return pick(source, {
        title: "title",
        status: "status",
        priority: "priority",
        dueDate: "dueDate",
        category: "taskCategory",
      });
    case ContributionEntityType.GUEST:
    case ContributionEntityType.GUEST_GROUP:
      return pick(source, {
        displayName: "displayName",
        groupDisplayName: "groupDisplayName",
        side: "side",
        invitationStatus: "invitationStatus",
        attendanceStatus: "attendanceStatus",
      });
    case ContributionEntityType.MONEY_ITEM:
    case ContributionEntityType.BUDGET_CATEGORY:
    case ContributionEntityType.WEDDING_COST:
    case ContributionEntityType.COST_PAYMENT:
    case ContributionEntityType.PAYMENT_SCHEDULE:
      return pick(source, {
        title: "title",
        categoryLabel: "categoryLabel",
        currency: "currency",
        totalAmount: "totalAmount",
        paidAmount: "paidAmount",
        amount: "amount",
        status: "status",
        relevantDate: "relevantDate",
      });
    case ContributionEntityType.PROVIDER_ITEM:
    case ContributionEntityType.QUOTE_REQUEST:
    case ContributionEntityType.PLAN_PROVIDER_LINK:
      return pick(source, {
        providerDisplayLabel: "providerDisplayLabel",
        categoryLabel: "categoryLabel",
        requestStatus: "requestStatus",
        status: "status",
      });
    case ContributionEntityType.MEMBER_ITEM:
    case ContributionEntityType.PLAN_INVITE:
      return pick(source, {
        displayName: "displayName",
        role: "role",
        permissionLabels: "permissionLabels",
        inviteState: "inviteState",
      });
    case ContributionEntityType.PLAN:
      return pick(source, {
        planTitle: "planTitle",
        weddingDate: "weddingDate",
        status: "status",
      });
    case ContributionEntityType.SECTION:
      return pick(source, { status: "status" });
  }
}

function pick(
  source: SnapshotSource,
  fields: Readonly<Record<string, string>>,
): Prisma.JsonObject {
  const result: Prisma.JsonObject = {};
  for (const [target, sourceKey] of Object.entries(fields)) {
    const normalized = toJsonValue(source[sourceKey]);
    if (normalized === undefined) continue;
    // User-authored labels remain available in the live domain row. If a
    // label resembles contact or credential data, omit only that field from
    // the immutable history snapshot instead of rejecting the domain write.
    if (
      userTextSnapshotKeys.has(target) &&
      typeof normalized === "string" &&
      isUnsafeUserText(normalized)
    ) {
      continue;
    }
    result[target] = normalized;
  }
  return result;
}

function isUnsafeUserText(value: string): boolean {
  if (Buffer.byteLength(value, "utf8") > MAX_STRING_BYTES) return true;
  const normalized = normalizeUnicodeDigits(value);
  return forbiddenValuePatterns.some((pattern) => pattern.test(normalized));
}

function toJsonValue(value: unknown): Prisma.JsonValue | undefined {
  if (value === undefined || value === null) return undefined;
  if (value instanceof Date) return value.toISOString();
  if (typeof value === "string" || typeof value === "boolean") return value;
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (Array.isArray(value)) {
    return value
      .map(toJsonValue)
      .filter((item): item is Prisma.JsonValue => item !== undefined);
  }
  if (typeof value === "object" && "toString" in value) {
    return String(value);
  }
  return undefined;
}

function inspectSnapshot(value: unknown, key = "snapshot", depth = 0): void {
  if (depth > MAX_DEPTH) {
    throw new BadRequestException("Contribution snapshot exceeds depth limit");
  }
  if (forbiddenKey.test(key)) {
    throw new BadRequestException("Sensitive contribution snapshot key");
  }
  if (typeof value === "string") {
    if (Buffer.byteLength(value, "utf8") > MAX_STRING_BYTES) {
      throw new BadRequestException(
        "Contribution snapshot string exceeds size limit",
      );
    }
    const normalized = normalizeUnicodeDigits(value);
    if (forbiddenValuePatterns.some((pattern) => pattern.test(normalized))) {
      throw new BadRequestException("Sensitive contribution snapshot value");
    }
    return;
  }
  if (Array.isArray(value)) {
    if (value.length > MAX_ARRAY_ITEMS) {
      throw new BadRequestException(
        "Contribution snapshot array exceeds item limit",
      );
    }
    value.forEach((item) => inspectSnapshot(item, key, depth + 1));
    return;
  }
  if (isPlainObject(value)) {
    if (Object.keys(value).length > MAX_OBJECT_KEYS) {
      throw new BadRequestException(
        "Contribution snapshot object exceeds key limit",
      );
    }
    for (const [nestedKey, nestedValue] of Object.entries(value)) {
      inspectSnapshot(nestedValue, nestedKey, depth + 1);
    }
  }
}

function normalizeUnicodeDigits(value: string): string {
  return value.replace(/[٠-٩۰-۹]/g, (digit) => {
    const code = digit.charCodeAt(0);
    const numeric = code >= 0x06f0 ? code - 0x06f0 : code - 0x0660;
    return String(numeric);
  });
}

function canonicalValue(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonicalValue);
  if (!isPlainObject(value)) return value;
  return Object.fromEntries(
    Object.keys(value)
      .sort()
      .map((key) => [key, canonicalValue(value[key])]),
  );
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
