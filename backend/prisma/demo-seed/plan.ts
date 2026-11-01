// Builds one demo plan: the plan itself, its money (items, agreements,
// payments, funding), tasks, guests and participants.
import {
  BudgetCategoryKind,
  ContributionAction,
  ContributionEntityType,
  ContributionPermission,
  ContributionProvenance,
  ContributionScopeStatus,
  ContributionSection,
  CostPaymentType,
  GuestAttendanceStatus,
  GuestInvitationStatus,
  GuestStatus,
  LoanRepaymentStatus,
  OnboardingPath,
  PaymentScheduleStatus,
  Prisma,
  PrismaClient,
  WeddingCostStatus,
  WeddingPlanStatus,
  WeddingTaskStatus,
} from '@prisma/client';
import { createHash } from 'node:crypto';
import {
  buildContributionSnapshot,
  canonicalJson,
  hashContributionSnapshot,
} from '../../src/modules/collaboration/public/contribution-snapshot.builder';
import { userId } from './accounts';
import { offerId, PROVIDERS, providerId } from './market-data';
import type {
  CostSpec,
  FundingSpec,
  GuestGroupSpec,
  ItemSpec,
  MemberSpec,
  PlanSpec,
  TaskSpec,
} from './plan-data';
import { inDays, normalizeCategoryName, normalizeGuestName, actorReference, demoId, today } from './support';

export const planId = (key: PlanSpec['key']): string => demoId('plan', key);

/** `DEMO_GUESTS=w38` seeds the half-answered state w38 draws (62 of 124). */
function halfAnswered(): boolean {
  return process.env.DEMO_GUESTS?.trim().toLowerCase() === 'w38';
}

type Tx = Prisma.TransactionClient;

export async function seedPlanCore(prisma: PrismaClient, spec: PlanSpec): Promise<string> {
  const id = planId(spec.key);
  const ownerId = userId(spec.owner);
  const city = 'صنعاء';
  const planData = {
    ownerUserId: ownerId,
    title: spec.title,
    city,
    location: {
      city,
      fullLabel: city,
      shortLabel: city,
      governorate: city,
      mediumLabel: city,
      displayLabel: city,
      cityOrDistrict: city,
    },
    weddingDate: spec.weddingDate,
    priorities: [],
    estimatedBudget: spec.budget,
    currency: 'YER',
    onboardingPath: OnboardingPath.USER,
    persona: spec.persona,
    onboardingCompletedAt: new Date(),
    status: WeddingPlanStatus.PLANNING,
  };

  await prisma.$transaction(
    async (tx) => {
      await tx.weddingPlan.upsert({
        where: { id },
        create: { id, ...planData },
        update: planData,
      });
      await tx.contributorHistoryScope.upsert({
        where: { weddingPlanId: id },
        create: {
          weddingPlanId: id,
          status: ContributionScopeStatus.ACTIVE,
          historyCoverageStartsAt: inDays(-90),
        },
        update: { status: ContributionScopeStatus.ACTIVE, archivedAt: null, deletedAt: null },
      });
      await tx.user.update({ where: { id: ownerId }, data: { activeWeddingPlanId: id } });
      for (const item of spec.items) await seedItem(tx, id, spec, item);
      for (const source of spec.funding) await seedFunding(tx, id, spec, source);
    },
    { timeout: 60_000 },
  );

  await prisma.$transaction(
    async (tx) => {
      for (const task of spec.tasks) await seedTask(tx, id, spec, task);
    },
    { timeout: 60_000 },
  );
  await seedGuests(prisma, id, spec);
  await seedMembers(prisma, id, spec);
  return id;
}

async function seedItem(tx: Tx, planKey: string, spec: PlanSpec, item: ItemSpec): Promise<void> {
  const kind = item.kind ?? BudgetCategoryKind.WEDDING;
  const data = {
    weddingPlanId: planKey,
    name: item.name,
    normalizedName: normalizeCategoryName(item.name),
    // C1: the mahr item is outside the budget and holds no allocation.
    allocatedAmount: kind === BudgetCategoryKind.MAHR ? null : item.allocated,
    kind,
  };
  const id = demoId('cat', `${spec.key}-${item.key}`);
  await tx.budgetCategory.upsert({ where: { id }, create: { id, ...data }, update: data });
}

async function seedFunding(tx: Tx, planKey: string, spec: PlanSpec, source: FundingSpec): Promise<void> {
  const id = demoId('fund', `${spec.key}-${source.key}`);
  const data = {
    weddingPlanId: planKey,
    kind: source.kind,
    sourceName: source.sourceName,
    amount: source.amount,
    status: source.status,
    receivedAt: source.receivedAt ?? null,
    expectedAt: source.expectedAt ?? null,
    note: source.note,
  };
  await tx.fundingSource.upsert({ where: { id }, create: { id, ...data }, update: data });
  for (const repayment of source.repayments ?? []) {
    const repaymentId = demoId('repay', `${spec.key}-${source.key}-${repayment.key}`);
    const repaymentData = {
      fundingSourceId: id,
      amount: repayment.amount,
      dueDate: repayment.dueDate,
      note: repayment.note,
      status: LoanRepaymentStatus.PLANNED,
      paidAt: null,
    };
    await tx.loanRepayment.upsert({
      where: { id: repaymentId },
      create: { id: repaymentId, ...repaymentData },
      update: repaymentData,
    });
  }
}

export const taskId = (planKey: PlanSpec['key'], key: string): string => demoId('task', `${planKey}-${key}`);

async function seedTask(tx: Tx, planKey: string, spec: PlanSpec, task: TaskSpec): Promise<void> {
  const id = taskId(spec.key, task.key);
  const data = {
    weddingPlanId: planKey,
    title: task.title,
    description: task.description ?? null,
    dueDate: task.dueDate,
    status: task.done ? WeddingTaskStatus.DONE : WeddingTaskStatus.TODO,
    priority: task.priority ?? 'MEDIUM',
    assigneeUserId: task.assignee ? userId(task.assignee) : null,
    responsibleName: task.responsibleName ?? null,
    privateToUserId: null,
    linkedBudgetCategoryId: task.linkedItem ? demoId('cat', `${spec.key}-${task.linkedItem}`) : null,
    linkedCostId: task.linkedPayment ? demoId('cost', `${spec.key}-${task.linkedPayment.cost}`) : null,
    linkedScheduleId: task.linkedPayment ? demoId('sched', `${spec.key}-${task.linkedPayment.schedule}`) : null,
    autoClosedAt: null,
  } as const;
  await tx.weddingTask.upsert({ where: { id }, create: { id, ...data }, update: data });
  for (const [index, item] of (task.checklist ?? []).entries()) {
    const itemId = demoId('check', `${spec.key}-${task.key}-${index}`);
    const itemData = { taskId: id, title: item.title, isDone: item.done, sortOrder: index + 1 };
    await tx.weddingTaskChecklistItem.upsert({
      where: { id: itemId },
      create: { id: itemId, ...itemData },
      update: itemData,
    });
  }
}

interface GuestRow {
  id: string;
  groupKey: string;
  name: string;
  side: GuestGroupSpec['side'];
  attendance: GuestAttendanceStatus;
  companions: number;
}

/** 124 guests with the designs' families, counts and answers. */
function buildGuestRows(spec: PlanSpec): GuestRow[] {
  const rows: GuestRow[] = [];
  for (const group of spec.guestGroups) {
    const used = new Set<string>();
    const names: Array<{ name: string; companions: number; attendance?: GuestAttendanceStatus }> = [];
    for (const featured of group.featured ?? []) {
      used.add(featured.name);
      names.push({
        name: featured.name,
        companions: featured.companions ?? 0,
        attendance: featured.attendance ? GuestAttendanceStatus[featured.attendance] : undefined,
      });
    }
    let cursor = 0;
    const first = group.firstNames;
    const combinations = first.length * group.surnames.length;
    while (names.length < group.total) {
      if (cursor > 5000) throw new Error(`Cannot build ${group.total} unique guests for ${group.name}`);
      const pass = Math.floor(cursor / combinations);
      const index = cursor % combinations;
      const given = first[index % first.length];
      const surname = group.surnames[Math.floor(index / first.length)];
      // After every first name met every surname, the father's name is added.
      const father = first[(index + pass * 3 + 1) % first.length];
      const name = pass === 0 ? `${given} ${surname}` : `${given} ${father} ${surname}`;
      cursor += 1;
      if (used.has(name)) continue;
      used.add(name);
      names.push({ name, companions: 0 });
    }
    // Quotas per group: confirmed first, then pending, the rest declined.
    let confirmedLeft = group.confirmed;
    let pendingLeft = group.pending;
    const resolved = names.map((entry) => {
      if (entry.attendance === GuestAttendanceStatus.CONFIRMED) confirmedLeft -= 1;
      if (entry.attendance === GuestAttendanceStatus.PENDING) pendingLeft -= 1;
      return entry;
    });
    for (const entry of resolved) {
      if (entry.attendance) continue;
      if (confirmedLeft > 0) {
        entry.attendance = GuestAttendanceStatus.CONFIRMED;
        confirmedLeft -= 1;
      } else if (pendingLeft > 0) {
        entry.attendance = GuestAttendanceStatus.PENDING;
        pendingLeft -= 1;
      } else {
        entry.attendance = GuestAttendanceStatus.DECLINED;
      }
    }
    for (const [index, entry] of resolved.entries()) {
      rows.push({
        id: demoId('guest', `${spec.key}-${group.key}-${index + 1}`),
        groupKey: group.key,
        name: entry.name,
        side: group.side,
        attendance: entry.attendance ?? GuestAttendanceStatus.PENDING,
        companions: entry.companions,
      });
    }
  }
  if (halfAnswered()) {
    // w38: half have answered; nobody declined.
    rows.forEach((row, index) => {
      row.attendance = index < 62 ? GuestAttendanceStatus.CONFIRMED : GuestAttendanceStatus.PENDING;
    });
  }
  return rows;
}

const statusFromAttendance = (attendance: GuestAttendanceStatus): GuestStatus =>
  attendance === GuestAttendanceStatus.CONFIRMED
    ? GuestStatus.CONFIRMED
    : attendance === GuestAttendanceStatus.DECLINED
      ? GuestStatus.DECLINED
      : GuestStatus.PENDING;

export function guestRowsFor(spec: PlanSpec): GuestRow[] {
  return buildGuestRows(spec);
}

async function seedGuests(prisma: PrismaClient, planKey: string, spec: PlanSpec): Promise<void> {
  await prisma.$transaction(
    async (tx) => {
      for (const [index, group] of spec.guestGroups.entries()) {
        const id = demoId('gg', `${spec.key}-${group.key}`);
        const data = { weddingPlanId: planKey, name: group.name, sortOrder: index + 1 };
        await tx.guestGroup.upsert({ where: { id }, create: { id, ...data }, update: data });
      }
      const rows = buildGuestRows(spec);
      let phoneCounter = spec.key === 'groom' ? 10_000 : 20_000;
      for (const [position, row] of rows.entries()) {
        // Two thirds of the guests carry a number; they are all fake (+96777701xxxx).
        const phone = position % 3 === 2 ? null : `+96777701${String(phoneCounter + position).slice(-4)}`;
        const data = {
          weddingPlanId: planKey,
          groupId: demoId('gg', `${spec.key}-${row.groupKey}`),
          name: row.name,
          normalizedName: normalizeGuestName(row.name),
          phone,
          normalizedPhone: phone,
          side: row.side,
          status: statusFromAttendance(row.attendance),
          invitationStatus: GuestInvitationStatus.SENT,
          attendanceStatus: row.attendance,
          seatsCount: 1,
          companionsCount: row.companions,
        };
        await tx.guest.upsert({ where: { id: row.id }, create: { id: row.id, ...data }, update: data });
      }
    },
    { timeout: 120_000 },
  );
}

async function seedMembers(prisma: PrismaClient, planKey: string, spec: PlanSpec): Promise<void> {
  const scope = await prisma.contributorHistoryScope.findUniqueOrThrow({
    where: { weddingPlanId: planKey },
  });
  for (const member of spec.members) {
    const memberUserId = userId(member.account);
    const id = demoId('member', `${spec.key}-${member.account}`);
    const flags = permissionFlags(member);
    const sharedMember = await prisma.sharedMember.upsert({
      where: { id },
      create: { id, weddingPlanId: planKey, userId: memberUserId, role: member.role, ...flags },
      update: { role: member.role, ...flags },
    });
    // A participant opens straight into the plan that was shared with them.
    if (member.account !== 'groom' && member.account !== 'bride') {
      await prisma.user.update({ where: { id: memberUserId }, data: { activeWeddingPlanId: planKey } });
    }
    const reference = actorReference(memberUserId);
    const tenure =
      (await prisma.contributorTenure.findFirst({
        where: { historyScopeId: scope.id, actorReference: reference, endedAt: null },
      })) ??
      (await prisma.contributorTenure.create({
        data: {
          historyScopeId: scope.id,
          actorUserId: memberUserId,
          actorReference: reference,
          sharedMemberId: sharedMember.id,
          joinedAt: sharedMember.createdAt,
          trackingStartedAt: inDays(-60),
          roleAtTrackingStart: member.role,
        },
      }));
    await seedContributions(prisma, spec, member, tenure.id, tenure.actorReference, scope.id, sharedMember.authorityVersion);
  }
}

function permissionFlags(member: MemberSpec) {
  return {
    canViewMoney: member.canViewMoney,
    canEditPlan: member.canEditPlan,
    canManageTasks: member.canManageTasks,
    canManageGuests: member.canManageGuests,
    canManageProviders: member.canManageProviders,
    canInviteMembers: member.canInviteMembers,
    canManageMoney: member.canManageMoney,
  };
}

/** The helper's own work: the tasks they created and a few guests they added. */
async function seedContributions(
  prisma: PrismaClient,
  spec: PlanSpec,
  member: MemberSpec,
  tenureId: string,
  tenureReference: string,
  scopeId: string,
  authorityVersion: number,
): Promise<void> {
  const events: Prisma.ContributionEventCreateManyInput[] = [];
  const push = (
    section: ContributionSection,
    entityType: ContributionEntityType,
    entityId: string,
    snapshot: Prisma.JsonObject,
    permission: ContributionPermission,
    occurredAt: Date,
  ) => {
    const snapshotHash = hashContributionSnapshot(snapshot);
    const fingerprint = createHash('sha256')
      .update(
        canonicalJson({
          contributorReference: tenureReference,
          contributorTenureId: tenureId,
          section,
          entityType,
          entityId,
          action: ContributionAction.CREATED,
          snapshotHash,
          provenance: ContributionProvenance.RUNTIME,
          requiredPermission: permission,
          permissionPolicyVersion: 1,
          authorityVersion,
          occurredAt: occurredAt.toISOString(),
        }),
      )
      .digest('hex');
    events.push({
      historyScopeId: scopeId,
      contributorTenureId: tenureId,
      section,
      entityType,
      entityId,
      action: ContributionAction.CREATED,
      snapshot,
      snapshotHash,
      snapshotVersion: 1,
      dedupeKey: `demo:${entityId}:created`,
      eventFingerprint: fingerprint,
      provenance: ContributionProvenance.RUNTIME,
      requiredPermission: permission,
      permissionPolicyVersion: 1,
      authorityVersion,
      occurredAt,
    });
  };

  for (const task of spec.tasks) {
    if (task.createdByMember !== member.account) continue;
    push(
      ContributionSection.TASKS,
      ContributionEntityType.TASK,
      taskId(spec.key, task.key),
      buildContributionSnapshot(ContributionEntityType.TASK, {
        title: task.title,
        status: task.done ? 'DONE' : 'TODO',
        priority: task.priority ?? 'MEDIUM',
        dueDate: task.dueDate.toISOString(),
      }),
      ContributionPermission.MANAGE_TASKS,
      task.dueDate,
    );
  }
  if (member.canManageGuests && member.role === 'HELPER') {
    const rows = buildGuestRows(spec).filter((row) => row.groupKey === 'friends').slice(0, 4);
    for (const row of rows) {
      const group = spec.guestGroups.find((candidate) => candidate.key === row.groupKey);
      push(
        ContributionSection.GUESTS,
        ContributionEntityType.GUEST,
        row.id,
        buildContributionSnapshot(ContributionEntityType.GUEST, {
          displayName: row.name,
          groupDisplayName: group?.name,
          side: row.side,
          invitationStatus: GuestInvitationStatus.SENT,
          attendanceStatus: row.attendance,
        }),
        ContributionPermission.MANAGE_GUESTS,
        inDays(-20),
      );
    }
  }
  if (events.length > 0) {
    await prisma.contributionEvent.createMany({ data: events, skipDuplicates: true });
  }
}

/**
 * Agreements, payments and reminders. Runs after the marketplace so a cost can
 * point at the provider and the accepted offer. Payments are append-only, so a
 * payment that already exists is left alone.
 */
export async function seedPlanCosts(prisma: PrismaClient, spec: PlanSpec): Promise<void> {
  const planKey = planId(spec.key);
  for (const item of spec.items) {
    if (!item.cost) continue;
    await seedCost(prisma, planKey, spec, item, item.cost);
  }
}

async function seedCost(
  prisma: PrismaClient,
  planKey: string,
  spec: PlanSpec,
  item: ItemSpec,
  cost: CostSpec,
): Promise<void> {
  const id = demoId('cost', `${spec.key}-${cost.key}`);
  const categoryId = demoId('cat', `${spec.key}-${item.key}`);
  const provider = cost.providerKey ? PROVIDERS.find((candidate) => candidate.key === cost.providerKey) : undefined;
  if (cost.providerKey && !provider) throw new Error(`Unknown provider ${cost.providerKey}`);
  const paidTotal = cost.payments.reduce((sum, payment) => sum + payment.amount, 0);
  const total = cost.total ?? item.allocated;
  const status =
    paidTotal === 0
      ? WeddingCostStatus.OPEN
      : paidTotal === total
        ? WeddingCostStatus.PAID
        : WeddingCostStatus.PARTIALLY_PAID;

  await prisma.$transaction(
    async (tx) => {
      const base = {
        weddingPlanId: planKey,
        budgetCategoryId: categoryId,
        providerId: provider ? providerId(provider) : null,
        quoteOfferId: cost.offerKey ? offerId(cost.offerKey) : null,
        title: cost.title,
        partyName: provider ? null : (cost.partyName ?? null),
        partyPhone: null,
        totalAmount: total,
        payer: cost.payer ?? null,
        payerName: cost.payerName ?? null,
        agreementDate: cost.agreementDate,
      };
      const existing = await tx.weddingCost.findUnique({ where: { id } });
      if (!existing) {
        await tx.weddingCost.create({ data: { id, ...base, paidAmount: 0, status: WeddingCostStatus.OPEN } });
      } else {
        await tx.weddingCost.update({ where: { id }, data: base });
      }

      // Schedules that were paid come first: a payment points at its schedule.
      for (const schedule of cost.schedules.filter((entry) => entry.paid)) {
        const paidAt = cost.payments.find((payment) => payment.scheduleKey === schedule.key)?.paidAt;
        if (!paidAt) throw new Error(`Paid schedule ${schedule.key} has no payment`);
        await upsertSchedule(tx, id, spec, schedule.key, {
          amount: schedule.amount,
          dueDate: schedule.dueDate,
          note: schedule.note,
          status: PaymentScheduleStatus.PAID,
          paidAt,
        });
      }
      for (const payment of cost.payments) {
        const paymentId = demoId('pay', `${spec.key}-${payment.key}`);
        const found = await tx.costPayment.findUnique({ where: { id: paymentId } });
        if (found) continue;
        await tx.costPayment.create({
          data: {
            id: paymentId,
            weddingCostId: id,
            amount: payment.amount,
            entryType: CostPaymentType.PAYMENT,
            paidAt: payment.paidAt,
            method: payment.method,
            note: payment.note ?? null,
            paymentScheduleId: payment.scheduleKey ? demoId('sched', `${spec.key}-${payment.scheduleKey}`) : null,
          },
        });
      }
      // The ledger of payments already stored decides the balance.
      const ledger = await tx.costPayment.aggregate({
        where: { weddingCostId: id },
        _sum: { amount: true },
      });
      const stored = Number(ledger._sum.amount ?? 0);
      if (stored !== paidTotal) {
        throw new Error(
          `Cost ${cost.key} already has ${stored} in its ledger but the demo expects ${paidTotal}. ` +
            'Payments cannot be changed; reset the local database to re-seed this plan.',
        );
      }
      await tx.weddingCost.update({ where: { id }, data: { paidAmount: paidTotal, status } });

      for (const schedule of cost.schedules.filter((entry) => !entry.paid)) {
        await upsertSchedule(tx, id, spec, schedule.key, {
          amount: schedule.amount,
          dueDate: schedule.dueDate,
          note: schedule.note,
          status: PaymentScheduleStatus.PENDING,
          paidAt: null,
        });
      }
    },
    { timeout: 60_000 },
  );
}

async function upsertSchedule(
  tx: Tx,
  costId: string,
  spec: PlanSpec,
  key: string,
  data: {
    amount: number;
    dueDate: Date;
    note: string;
    status: PaymentScheduleStatus;
    paidAt: Date | null;
  },
): Promise<void> {
  const id = demoId('sched', `${spec.key}-${key}`);
  await tx.paymentSchedule.upsert({
    where: { id },
    create: { id, weddingCostId: costId, ...data },
    update: data,
  });
}

/** For the printed summary and the smoke checks: the headline numbers of a plan. */
export function expectedTotals(spec: PlanSpec) {
  // The budget's items: the mahr item is outside it (C1).
  const items = spec.items.reduce(
    (sum, item) => sum + (item.kind === BudgetCategoryKind.MAHR ? 0 : item.allocated),
    0,
  );
  const paid = spec.items.reduce(
    (sum, item) => sum + (item.cost?.payments.reduce((inner, payment) => inner + payment.amount, 0) ?? 0),
    0,
  );
  const guests = spec.guestGroups.reduce((sum, group) => sum + group.total, 0);
  const confirmed = halfAnswered() ? 62 : spec.guestGroups.reduce((sum, group) => sum + group.confirmed, 0);
  return { budget: spec.budget, items, paid, guests, confirmed, tasks: spec.tasks.length, today: today() };
}
