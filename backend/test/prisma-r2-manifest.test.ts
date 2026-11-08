import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { readLivePrismaModelOrder, readLivePrismaSchema } from './support/live-prisma-schema';

type ManifestOwner = {
  owner: string;
  file: string;
  models: string[];
  enums: string[];
};

type Manifest = {
  schemaVersion: number;
  splitBaseRevision: string;
  baseFile: string;
  owners: ManifestOwner[];
  modelOrder: string[];
};

const R2_BASE = '8ba0db78ac669bd6d17de878b77a4d1e6c5e542d';
const backendRoot = path.resolve(__dirname, '..');
const manifestPath = path.join(backendRoot, 'architecture', 'prisma-schema-layout.json');
const registryPath = path.join(backendRoot, 'architecture', 'ownership-registry.json');

const expectedOwners: ManifestOwner[] = [
  { owner: 'backoffice', file: 'backoffice.prisma', models: ['AdminAuditLog'], enums: ['AdminRole', 'AdminAuditPhase'] },
  { owner: 'catalog', file: 'catalog.prisma', models: ['City', 'Governorate', 'District', 'AdministrativeLocality', 'ReferenceCatalog', 'ReferenceCatalogItem', 'ReferenceCatalogItemRevision', 'ProviderCategory'], enums: ['AdministrativeLocalityType'] },
  { owner: 'collaboration', file: 'collaboration.prisma', models: ['SharedMember', 'ContributorHistoryScope', 'ContributorTenure', 'ContributionEvent', 'PlanInvite'], enums: ['SharedMemberRole', 'ContributionScopeStatus', 'ContributorTenureEndReason', 'ContributionSection', 'ContributionEntityType', 'ContributionAction', 'ContributionProvenance', 'ContributionPermission', 'PlanInviteDeliveryStatus'] },
  { owner: 'finance', file: 'finance.prisma', models: ['BudgetCategory', 'WeddingCost', 'CostPayment', 'CostReceipt', 'PaymentSchedule', 'FundingSource', 'LoanRepayment'], enums: ['WeddingCostStatus', 'CostPaymentType', 'PaymentScheduleStatus', 'FundingSourceKind', 'FundingSourceStatus', 'LoanRepaymentStatus', 'CostPayer', 'BudgetCategoryKind', 'BudgetItemSuggestion', 'CostEntryKind', 'EstimateCover'] },
  { owner: 'guests', file: 'guests.prisma', models: ['Guest', 'GuestGroup', 'GuestInvitationCard', 'GuestEventInvite'], enums: ['GuestSide', 'GuestStatus', 'GuestInvitationStatus', 'GuestAttendanceStatus'] },
  { owner: 'identity', file: 'identity.prisma', models: ['AccountDeletionReceipt', 'User', 'DataExport', 'AdminLoginChallenge', 'AdminPasswordResetChallenge', 'RefreshToken', 'LoginThrottle', 'OtpDispatchQuota', 'AssistantUsageDay', 'AssistantAnswerReport', 'OtpCode'], enums: ['UserRole', 'AppRole', 'UserStatus', 'OtpPurpose', 'AuthSessionScope'] },
  { owner: 'marketplace', file: 'marketplace.prisma', models: ['Provider', 'ProviderService', 'ProviderServiceImage', 'ProviderPackage', 'FavoriteProvider', 'ProviderReview', 'QuoteRequest', 'QuoteOffer', 'PlanProviderLink', 'Booking', 'BookingChange', 'ProviderBlockedDate', 'ProviderProfileViewDay', 'ProviderReviewEvent', 'ProviderReviewNote', 'ProviderClaimRequest', 'QuoteOfferVersion', 'ProviderFeaturedPeriod', 'PortfolioItem', 'ReviewReport'], enums: ['ProviderStatus', 'ReviewStatus', 'QuoteRequestStatus', 'QuoteOfferStatus', 'PlanProviderLinkStatus', 'BookingStatus', 'BookingParty', 'ProviderReviewEventKind', 'ProviderReviewField', 'ProviderClaimStatus', 'BookingChangeStatus', 'PortfolioItemStatus'] },
  { owner: 'media', file: 'media.prisma', models: ['MediaUploadTicket'], enums: ['MediaUploadStatus'] },
  { owner: 'messaging', file: 'messaging.prisma', models: ['Conversation', 'ConversationParticipant', 'ConversationEvent', 'ChatMessage', 'ChatAttachment', 'ConversationReport'], enums: ['ConversationScope', 'ConversationEventType', 'ConversationReportStatus'] },
  { owner: 'notifications', file: 'notifications.prisma', models: ['NotificationPreference', 'PushInstallation', 'Notification'], enums: ['NotificationType', 'NotificationPriority', 'PushPlatform'] },
  { owner: 'planning', file: 'planning.prisma', models: ['WeddingPlan', 'PlanEvent'], enums: ['OnboardingPath', 'WeddingPersona', 'WeddingPlanStatus', 'PlanEventType', 'PlanEventTimeSlot'] },
  { owner: 'platform', file: 'platform.prisma', models: ['IdempotencyKey', 'OutboxEvent'], enums: [] },
  { owner: 'tasks', file: 'tasks.prisma', models: ['WeddingTask', 'WeddingTaskChecklistItem'], enums: ['WeddingTaskStatus', 'WeddingTaskPriority'] },
];

function orderedDeclarations(keyword: 'model' | 'enum') {
  const schema = readLivePrismaSchema();
  return [...schema.matchAll(new RegExp(`^${keyword}\\s+([A-Za-z][A-Za-z0-9_]*)\\s*\\{`, 'gm'))]
    .map((match) => match[1]);
}

function exactStringList(value: unknown) {
  assert.ok(Array.isArray(value));
  const entries = value as unknown[];
  assert.equal(Object.getPrototypeOf(entries), Array.prototype);
  assert.equal(Object.getOwnPropertySymbols(entries).length, 0);
  for (const item of entries) assert.equal(typeof item, 'string');
  assert.equal(new Set(entries).size, entries.length);
}

function projectOwnerMap(owners: ManifestOwner[]) {
  return owners
    .map((entry) => ({ owner: entry.owner, file: entry.file, models: [...entry.models].sort(), enums: [...entry.enums].sort() }))
    .sort((left, right) => left.file < right.file ? -1 : left.file > right.file ? 1 : 0);
}

function registryOwnerModels(owners: ManifestOwner[], registry: { owners: Record<string, string[]> }) {
  return Object.fromEntries(
    owners.map(({ owner, models }) => [owner, [...models].sort()]),
  ) as Record<string, string[]>;
}

test('R2 Prisma manifest is exact plain data with immutable provenance and deterministic layout', () => {
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8')) as Manifest;
  assert.equal(Object.getPrototypeOf(manifest), Object.prototype);
  assert.deepEqual(Object.keys(manifest).sort(), ['baseFile', 'modelOrder', 'owners', 'schemaVersion', 'splitBaseRevision']);
  assert.equal(manifest.schemaVersion, 1);
  assert.equal(manifest.splitBaseRevision, R2_BASE);
  assert.match(manifest.splitBaseRevision, /^[0-9a-f]{40}$/);
  assert.equal(manifest.baseFile, '_base.prisma');
  assert.deepEqual(manifest.owners, expectedOwners);
  assert.deepEqual(projectOwnerMap(manifest.owners), projectOwnerMap([...manifest.owners].reverse()));
  assert.equal(manifest.owners.some((entry) => entry.owner === 'insights'), false);
  assert.deepEqual(manifest.owners.map((entry) => entry.file), expectedOwners.map((entry) => entry.file));
  assert.deepEqual(manifest.owners.map((entry) => entry.owner), expectedOwners.map((entry) => entry.owner));

  for (const entry of manifest.owners) {
    assert.equal(Object.getPrototypeOf(entry), Object.prototype);
    assert.deepEqual(Object.keys(entry).sort(), ['enums', 'file', 'models', 'owner']);
    assert.match(entry.owner, /^[a-z]+$/);
    assert.match(entry.file, /^[a-z]+\.prisma$/);
    exactStringList(entry.models);
    exactStringList(entry.enums);
  }

  exactStringList(manifest.modelOrder);
  // B-16: + PortfolioItem and PortfolioItemStatus (D62).
  // D63: + DataExport. D65: + PlanEvent and its two enums.
  // D83: + GuestInvitationCard and GuestEventInvite (the guests' card and
  // their events beyond the wedding).
  // RA-ST-05: + ReviewReport. RA-ST-04: + AssistantAnswerReport.
  assert.equal(manifest.modelOrder.length, 72);
  assert.equal(manifest.owners.flatMap((entry) => entry.models).length, 72);
  // B5: + BudgetCategoryKind (the groom's mahr item, C1).
  // Home guidance: + BudgetItemSuggestion («ما أحتاجها» / «بعدين»).
  // D105: + EstimateCover. D107: + CostEntryKind.
  assert.equal(manifest.owners.flatMap((entry) => entry.enums).length, 58);
  assert.equal(new Set(manifest.owners.flatMap((entry) => entry.models)).size, 72);
  assert.equal(new Set(manifest.owners.flatMap((entry) => entry.enums)).size, 58);
});

test('R2 Prisma manifest equals the current registry and ordered live single-schema declarations', () => {
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8')) as Manifest;
  const registry = JSON.parse(readFileSync(registryPath, 'utf8')) as { owners: Record<string, string[]> };
  const manifestModels = manifest.owners.flatMap((entry) => entry.models).sort();
  const registryModels = Object.entries(registry.owners)
    .filter(([, models]) => models.length > 0)
    .flatMap(([, models]) => models)
    .sort();

  assert.deepEqual(manifestModels, registryModels);
  const expectedRegistryOwners = Object.fromEntries(
    Object.entries(registry.owners)
      .filter(([, models]) => models.length > 0)
      .map(([owner, models]) => [owner, [...models].sort()]),
  ) as Record<string, string[]>;
  assert.deepEqual(registryOwnerModels(manifest.owners, registry), expectedRegistryOwners);
  assert.deepEqual(manifest.modelOrder, readLivePrismaModelOrder());
  assert.deepEqual(manifest.owners.flatMap((entry) => entry.enums).sort(), orderedDeclarations('enum').sort());
  assert.equal(manifest.modelOrder.length, 72);
  assert.equal(orderedDeclarations('enum').length, 58);
});

test('manifest registry comparison rejects a User and IdempotencyKey owner swap', () => {
  const registry = JSON.parse(readFileSync(registryPath, 'utf8')) as { owners: Record<string, string[]> };
  const swapped = structuredClone(expectedOwners);
  const identity = swapped.find((entry) => entry.owner === 'identity')!;
  const platform = swapped.find((entry) => entry.owner === 'platform')!;
  identity.models[identity.models.indexOf('User')] = 'IdempotencyKey';
  platform.models[platform.models.indexOf('IdempotencyKey')] = 'User';
  const expectedRegistryOwners = Object.fromEntries(
    Object.entries(registry.owners)
      .filter(([, models]) => models.length > 0)
      .map(([owner, models]) => [owner, [...models].sort()]),
  ) as Record<string, string[]>;
  assert.throws(() => assert.deepEqual(registryOwnerModels(swapped, registry), expectedRegistryOwners));
});
