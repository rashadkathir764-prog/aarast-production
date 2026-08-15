import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionPermission,
  ContributionSection,
  Guest,
  GuestAttendanceStatus,
  GuestGroup,
  GuestInvitationStatus,
  GuestSide,
  GuestStatus,
  Prisma,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { ListQueryDto, pageArgs } from "../platform/http/list-query.dto";
import { PhoneNormalizer } from "../shared-kernel/phone/phone-normalizer";
import {
  runRetryableTransaction,
  runSerializableTransaction,
} from "../platform/database/serializable-transaction";
import { ContributionHistoryService } from "../contribution-history/contribution-history.service";
import { buildContributionSnapshot } from "../contribution-history/contribution-snapshot.builder";
import { ContributorScopeService } from "../contribution-history/contributor-scope.service";
import { PrismaService } from "../platform/database/prisma.service";
import {
  PermissionService,
  PlanAccessContext,
} from "../sharing/permission.service";
import { BulkGuestsDto } from "./dto/bulk-guests.dto";
import { CreateGuestGroupDto } from "./dto/create-guest-group.dto";
import { CreateGuestDto } from "./dto/create-guest.dto";
import { UpdateGuestGroupDto } from "./dto/update-guest-group.dto";
import { UpdateGuestDto } from "./dto/update-guest.dto";

export interface GuestResponse {
  id: string;
  weddingPlanId: string;
  groupId: string | null;
  name: string;
  phone: string | null;
  side: GuestSide;
  status: GuestStatus;
  invitationStatus: GuestInvitationStatus;
  attendanceStatus: GuestAttendanceStatus;
  seatsCount: number;
  companionsCount: number;
  notes: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface GuestGroupResponse {
  id: string;
  weddingPlanId: string;
  name: string;
  notes: string | null;
  sortOrder: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface BulkGuestsResponse {
  created: GuestResponse[];
}

export interface GuestsSummaryResponse {
  weddingPlanId: string;
  totalGuests: number;
  confirmedGuests: number;
  confirmed: number;
  declinedGuests: number;
  declined: number;
  notAttending: number;
  pendingGuests: number;
  pending: number;
  waiting: number;
  invitedGuests: number;
  missingPhoneCount: number;
  missingNameCount: number;
  incompleteGuestsCount: number;
  groupsCount: number;
  seatsTotal: number;
  expectedSeatsCount: number;
  companionsTotal: number;
  companionsExpectedCount: number;
  bySide: Record<GuestSide, number>;
  bySideForSuper: {
    groom: number;
    bride: number;
    unknown: number;
  };
  byGroup: Record<string, number>;
  byInvitationStatus: Record<GuestInvitationStatus, number>;
  byAttendanceStatus: Record<GuestAttendanceStatus, number>;
}

@Injectable()
export class GuestsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly permissions: PermissionService,
    private readonly contributionHistory: ContributionHistoryService,
    private readonly contributorScope: ContributorScopeService,
  ) {}

  async findForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    query?: ListQueryDto,
  ): Promise<GuestResponse[]> {
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const context = await this.permissions.assertPlanReadableInTransaction(
          tx,
          weddingPlanId,
          currentUser,
        );
        const includePrivateDetails = this.permissions.canManageGuests(context);
        const [contributorScope, groupScope] = await Promise.all([
          this.liveGuestScope(tx, context, currentUser.id),
          this.liveGroupScope(tx, context, currentUser.id),
        ]);
        if (contributorScope !== null && !includePrivateDetails) return [];

        const guests = await tx.guest.findMany({
          where: {
            weddingPlanId,
            ...(contributorScope ? { id: { in: [...contributorScope] } } : {}),
          },
          orderBy: [{ createdAt: "desc" }],
          ...pageArgs(query),
        });

        return guests
          .filter(
            (guest) =>
              contributorScope === null || contributorScope.has(guest.id),
          )
          .map((guest) =>
            this.toResponse(guest, includePrivateDetails, groupScope),
          );
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  async findOne(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<GuestResponse> {
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const guest = await tx.guest.findUnique({ where: { id } });
        if (!guest) throw new NotFoundException("Guest not found");
        const context = await this.permissions.assertPlanReadableInTransaction(
          tx,
          guest.weddingPlanId,
          currentUser,
        );
        await this.assertLiveGuestReadable(
          tx,
          context,
          currentUser.id,
          guest,
        );
        const groupScope = await this.liveGroupScope(
          tx,
          context,
          currentUser.id,
        );
        return this.toResponse(
          guest,
          this.permissions.canManageGuests(context),
          groupScope,
        );
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  async create(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateGuestDto,
  ): Promise<GuestResponse> {
    const guest = await this.catchDuplicateGuestConflict(
      runSerializableTransaction(this.prisma, async (tx) => {
        const context = await this.permissions.assertGuestManageableInTransaction(
          tx,
          weddingPlanId,
          currentUser,
        );
        const created = await this.createGuestInTransaction(
          tx,
          weddingPlanId,
          dto,
          context,
          currentUser.id,
        );
        await this.recordGuestContribution(
          tx,
          context,
          created,
          ContributionAction.CREATED,
        );
        return created;
      }),
    );

    return this.toResponse(guest);
  }

  async bulkCreate(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: BulkGuestsDto,
  ): Promise<BulkGuestsResponse> {
    if (!Array.isArray(dto.items) || dto.items.length === 0) {
      throw new BadRequestException("items must contain at least one guest");
    }
    if (dto.items.length > 200) {
      throw new BadRequestException("items must not exceed 200 guests");
    }

    const created = await this.catchDuplicateGuestConflict(
      runSerializableTransaction(this.prisma, async (tx) => {
        const context = await this.permissions.assertGuestManageableInTransaction(
          tx,
          weddingPlanId,
          currentUser,
        );
        const guests: Guest[] = [];
        for (const item of dto.items) {
          const guest = await this.createGuestInTransaction(
            tx,
            weddingPlanId,
            item,
            context,
            currentUser.id,
          );
          await this.recordGuestContribution(
            tx,
            context,
            guest,
            ContributionAction.CREATED,
          );
          guests.push(guest);
        }
        return guests;
      }),
    );

    return { created: created.map((guest) => this.toResponse(guest)) };
  }

  async update(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateGuestDto,
  ): Promise<GuestResponse> {
    const existing = await this.findGuestOrThrow(id);
    const groupId =
      dto.groupId !== undefined ? this.optionalId(dto.groupId) : undefined;
    const mappedStatus =
      dto.attendanceStatus !== undefined
        ? this.statusFromAttendance(dto.attendanceStatus)
        : null;

    const guest = await this.catchDuplicateGuestConflict(
      runSerializableTransaction(this.prisma, async (tx) => {
        const context = await this.permissions.assertGuestManageableInTransaction(
          tx,
          existing.weddingPlanId,
          currentUser,
        );
        if (dto.groupId !== undefined) {
          await this.assertGroupLinkableInTransaction(
            tx,
            dto.groupId,
            existing.weddingPlanId,
            context,
            currentUser.id,
          );
        }
        const current = await this.findGuestInTransactionOrThrow(
          tx,
          id,
          existing.weddingPlanId,
        );
        await this.assertGuestInMutationScope(
          tx,
          context,
          currentUser.id,
          current,
        );
        const name =
          dto.name !== undefined
            ? this.requiredText(dto.name, "name")
            : current.name;
        const phone =
          dto.phone !== undefined
            ? PhoneNormalizer.normalizeOptional(dto.phone)
            : current.normalizedPhone;

        await this.assertGuestIsNotDuplicate(tx, {
          weddingPlanId: current.weddingPlanId,
          normalizedPhone: phone,
          excludeGuestId: current.id,
        });

        const updated = await tx.guest.update({
          where: { id },
          data: {
            ...(dto.name !== undefined
              ? {
                  name,
                  normalizedName: this.normalizeGuestName(name),
                }
              : {}),
            ...(dto.phone !== undefined
              ? { phone, normalizedPhone: phone }
              : {}),
            ...(dto.groupId !== undefined
              ? {
                  group: groupId
                    ? { connect: { id: groupId } }
                    : { disconnect: true },
                }
              : {}),
            ...(dto.side !== undefined ? { side: dto.side } : {}),
            ...(dto.status !== undefined ? { status: dto.status } : {}),
            ...(dto.invitationStatus !== undefined
              ? { invitationStatus: dto.invitationStatus }
              : {}),
            ...(dto.attendanceStatus !== undefined
              ? {
                  attendanceStatus: dto.attendanceStatus,
                  ...(dto.status === undefined && mappedStatus
                    ? { status: mappedStatus }
                    : {}),
                }
              : {}),
            ...(dto.seatsCount !== undefined
              ? { seatsCount: this.validSeatsCount(dto.seatsCount) }
              : {}),
            ...(dto.companionsCount !== undefined
              ? {
                  companionsCount: this.validCompanionsCount(
                    dto.companionsCount,
                  ),
                }
              : {}),
            ...(dto.notes !== undefined
              ? { notes: this.optionalText(dto.notes) }
              : {}),
          },
        });
        const action = this.guestUpdateAction(current, updated);
        await this.recordGuestContribution(tx, context, updated, action);
        return updated;
      }),
    );

    return this.toResponse(guest);
  }

  async remove(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    const existing = await this.findGuestOrThrow(id);
    await runSerializableTransaction(this.prisma, async (tx) => {
      const context = await this.permissions.assertGuestManageableInTransaction(
        tx,
        existing.weddingPlanId,
        currentUser,
      );
      const current = await this.findGuestInTransactionOrThrow(
        tx,
        id,
        existing.weddingPlanId,
      );
      await this.assertGuestInMutationScope(
        tx,
        context,
        currentUser.id,
        current,
      );
      await this.recordGuestContribution(
        tx,
        context,
        current,
        ContributionAction.DELETED,
      );
      await tx.guest.delete({ where: { id } });
    });
    return { id, deleted: true };
  }

  async findGroups(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<GuestGroupResponse[]> {
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const context = await this.permissions.assertPlanReadableInTransaction(
          tx,
          weddingPlanId,
          currentUser,
        );
        const includePrivateDetails = this.permissions.canManageGuests(context);
        const contributorScope = await this.liveGroupScope(
          tx,
          context,
          currentUser.id,
        );
        if (contributorScope !== null && !includePrivateDetails) return [];
        const groups = await tx.guestGroup.findMany({
          where: {
            weddingPlanId,
            ...(contributorScope ? { id: { in: [...contributorScope] } } : {}),
          },
          orderBy: [{ sortOrder: "asc" }, { createdAt: "asc" }],
        });
        return groups
          .filter(
            (group) =>
              contributorScope === null || contributorScope.has(group.id),
          )
          .map((group) => this.toGroupResponse(group, includePrivateDetails));
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  async createGroup(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateGuestGroupDto,
  ): Promise<GuestGroupResponse> {
    const group = await this.catchDuplicateGroupConflict(
      runSerializableTransaction(this.prisma, async (tx) => {
        const context = await this.permissions.assertGuestManageableInTransaction(
          tx,
          weddingPlanId,
          currentUser,
        );
        const created = await tx.guestGroup.create({
          data: {
            weddingPlanId,
            name: this.requiredText(dto.name, "name"),
            notes: this.optionalText(dto.notes),
            sortOrder: dto.sortOrder ?? 0,
          },
        });
        await this.recordGuestGroupContribution(
          tx,
          context,
          created,
          ContributionAction.CREATED,
        );
        return created;
      }),
    );
    return this.toGroupResponse(group);
  }

  async updateGroup(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateGuestGroupDto,
  ): Promise<GuestGroupResponse> {
    const existing = await this.findGroupOrThrow(id);
    const group = await this.catchDuplicateGroupConflict(
      runSerializableTransaction(this.prisma, async (tx) => {
        const context = await this.permissions.assertGuestManageableInTransaction(
          tx,
          existing.weddingPlanId,
          currentUser,
        );
        const current = await this.findGroupInTransactionOrThrow(
          tx,
          id,
          existing.weddingPlanId,
        );
        await this.assertGroupInMutationScope(
          tx,
          context,
          currentUser.id,
          current,
        );
        const updated = await tx.guestGroup.update({
          where: { id },
          data: {
            ...(dto.name !== undefined
              ? { name: this.requiredText(dto.name, "name") }
              : {}),
            ...(dto.notes !== undefined
              ? { notes: this.optionalText(dto.notes) }
              : {}),
            ...(dto.sortOrder !== undefined
              ? { sortOrder: dto.sortOrder }
              : {}),
          },
        });
        await this.recordGuestGroupContribution(
          tx,
          context,
          updated,
          ContributionAction.UPDATED,
        );
        return updated;
      }),
    );
    return this.toGroupResponse(group);
  }

  async removeGroup(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    const existing = await this.findGroupOrThrow(id);
    await runSerializableTransaction(this.prisma, async (tx) => {
      const context = await this.permissions.assertGuestManageableInTransaction(
        tx,
        existing.weddingPlanId,
        currentUser,
      );
      const current = await this.findGroupInTransactionOrThrow(
        tx,
        id,
        existing.weddingPlanId,
      );
      await this.assertGroupInMutationScope(
        tx,
        context,
        currentUser.id,
        current,
      );
      await this.recordGuestGroupContribution(
        tx,
        context,
        current,
        ContributionAction.DELETED,
      );
      await tx.guestGroup.delete({ where: { id } });
    });
    return { id, deleted: true };
  }

  async summary(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<GuestsSummaryResponse> {
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const context = await this.permissions.assertPlanReadableInTransaction(
          tx,
          weddingPlanId,
          currentUser,
        );
        const canManageGuests = this.permissions.canManageGuests(context);
        const [guestScope, groupScope] = await Promise.all([
          this.liveGuestScope(tx, context, currentUser.id),
          this.liveGroupScope(tx, context, currentUser.id),
        ]);
        const [guestRows, groupsCount] =
          guestScope !== null && !canManageGuests
            ? [[], 0]
            : await Promise.all([
                tx.guest.findMany({
                  where: {
                    weddingPlanId,
                    ...(guestScope ? { id: { in: [...guestScope] } } : {}),
                  },
                  include: { group: { select: { name: true } } },
                }),
                tx.guestGroup.count({
                  where: {
                    weddingPlanId,
                    ...(groupScope ? { id: { in: [...groupScope] } } : {}),
                  },
                }),
              ]);
        const guests = guestRows.filter(
          (guest) => guestScope === null || guestScope.has(guest.id),
        );
        const bySide = this.emptySideCounts();
        const byInvitationStatus = this.emptyInvitationStatusCounts();
        const byAttendanceStatus = this.emptyAttendanceStatusCounts();
        const byGroup: Record<string, number> = {};
        let seatsTotal = 0;
        let companionsTotal = 0;
        let missingPhoneCount = 0;
        let missingNameCount = 0;
        let incompleteGuestsCount = 0;

        for (const guest of guests) {
          bySide[guest.side]++;
          byInvitationStatus[guest.invitationStatus]++;
          byAttendanceStatus[guest.attendanceStatus]++;
          seatsTotal += guest.seatsCount;
          companionsTotal += guest.companionsCount;
          const canReadGroup =
            groupScope === null ||
            (guest.groupId !== null && groupScope.has(guest.groupId));
          const groupKey = canReadGroup
            ? (guest.group?.name ?? "ungrouped")
            : "ungrouped";
          byGroup[groupKey] = (byGroup[groupKey] ?? 0) + 1;
          if (!guest.phone) missingPhoneCount++;
          if (!guest.name.trim()) missingNameCount++;
          if (this.isIncompleteGuest(guest)) incompleteGuestsCount++;
        }
        const confirmed = byAttendanceStatus[GuestAttendanceStatus.CONFIRMED];
        const declined = byAttendanceStatus[GuestAttendanceStatus.DECLINED];
        const pending = byAttendanceStatus[GuestAttendanceStatus.PENDING];

        return {
      weddingPlanId,
      totalGuests: guests.length,
      confirmedGuests: confirmed,
      confirmed,
      declinedGuests: declined,
      declined,
      notAttending: declined,
      pendingGuests: pending,
      pending,
      waiting: pending,
      invitedGuests: guests.filter(
        (guest) => guest.status === GuestStatus.INVITED,
      ).length,
      missingPhoneCount,
      missingNameCount,
      incompleteGuestsCount,
      groupsCount,
      seatsTotal,
      expectedSeatsCount: seatsTotal,
      companionsTotal,
      companionsExpectedCount: companionsTotal,
      bySide,
      bySideForSuper: {
        groom: bySide[GuestSide.GROOM],
        bride: bySide[GuestSide.BRIDE],
        unknown:
          bySide[GuestSide.FAMILY] +
          bySide[GuestSide.FRIEND] +
          bySide[GuestSide.OTHER],
      },
      byGroup,
      byInvitationStatus,
      byAttendanceStatus,
        };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  private isContributor(context: PlanAccessContext): boolean {
    return !context.isOwner && Boolean(context.sharedMember);
  }

  private async liveGuestScope(
    tx: Prisma.TransactionClient,
    context: PlanAccessContext,
    actorUserId: string,
  ): Promise<Set<string> | null> {
    if (!this.isContributor(context)) return null;
    if (!this.permissions.canManageGuests(context)) return new Set<string>();
    return new Set(
      await this.contributorScope.qualifyingEntityIdsInTransaction(
        tx,
        context.plan.id,
        actorUserId,
        [ContributionEntityType.GUEST],
        [ContributionAction.CREATED],
      ),
    );
  }

  private async liveGroupScope(
    tx: Prisma.TransactionClient,
    context: PlanAccessContext,
    actorUserId: string,
  ): Promise<Set<string> | null> {
    if (!this.isContributor(context)) return null;
    if (!this.permissions.canManageGuests(context)) return new Set<string>();
    return new Set(
      await this.contributorScope.qualifyingEntityIdsInTransaction(
        tx,
        context.plan.id,
        actorUserId,
        [ContributionEntityType.GUEST_GROUP],
        [ContributionAction.CREATED],
      ),
    );
  }

  private async assertLiveGuestReadable(
    tx: Prisma.TransactionClient,
    context: PlanAccessContext,
    actorUserId: string,
    guest: Guest,
  ): Promise<void> {
    if (!this.isContributor(context)) return;
    if (!this.permissions.canManageGuests(context)) {
      throw new NotFoundException("Guest not found");
    }
    const ids = await this.contributorScope.qualifyingEntityIdsInTransaction(
      tx,
      guest.weddingPlanId,
      actorUserId,
      [ContributionEntityType.GUEST],
      [ContributionAction.CREATED],
    );
    if (!ids.includes(guest.id)) throw new NotFoundException("Guest not found");
  }

  private async assertGuestInMutationScope(
    tx: Prisma.TransactionClient,
    context: PlanAccessContext,
    actorUserId: string,
    guest: Guest,
  ): Promise<void> {
    if (!this.isContributor(context)) return;
    const ids = await this.contributorScope.qualifyingEntityIdsInTransaction(
      tx,
      guest.weddingPlanId,
      actorUserId,
      [ContributionEntityType.GUEST],
      [ContributionAction.CREATED],
    );
    if (!ids.includes(guest.id)) throw new NotFoundException("Guest not found");
  }

  private async assertGroupInMutationScope(
    tx: Prisma.TransactionClient,
    context: PlanAccessContext,
    actorUserId: string,
    group: GuestGroup,
  ): Promise<void> {
    if (!this.isContributor(context)) return;
    const ids = await this.contributorScope.qualifyingEntityIdsInTransaction(
      tx,
      group.weddingPlanId,
      actorUserId,
      [ContributionEntityType.GUEST_GROUP],
      [ContributionAction.CREATED],
    );
    if (!ids.includes(group.id)) {
      throw new NotFoundException("Guest group not found");
    }
  }

  private guestUpdateAction(
    previous: Guest,
    next: Guest,
  ): ContributionAction {
    if (
      previous.status !== next.status ||
      previous.invitationStatus !== next.invitationStatus ||
      previous.attendanceStatus !== next.attendanceStatus
    ) {
      return ContributionAction.STATUS_CHANGED;
    }
    return ContributionAction.UPDATED;
  }

  private async recordGuestContribution(
    tx: Prisma.TransactionClient,
    context: PlanAccessContext,
    guest: Guest,
    action: ContributionAction,
  ): Promise<void> {
    await this.contributionHistory.recordForContextInTransaction(tx, context, {
      section: ContributionSection.GUESTS,
      entityType: ContributionEntityType.GUEST,
      entityId: guest.id,
      action,
      snapshot: buildContributionSnapshot(ContributionEntityType.GUEST, {
        displayName: guest.name,
        side: guest.side,
        invitationStatus: guest.invitationStatus,
        attendanceStatus: guest.attendanceStatus,
      }),
      dedupeKey: `guest:${guest.id}:${action.toLowerCase()}:${guest.updatedAt.toISOString()}`,
      requiredPermission: ContributionPermission.MANAGE_GUESTS,
      occurredAt:
        action === ContributionAction.CREATED
          ? guest.createdAt
          : guest.updatedAt,
    });
  }

  private async recordGuestGroupContribution(
    tx: Prisma.TransactionClient,
    context: PlanAccessContext,
    group: GuestGroup,
    action: ContributionAction,
  ): Promise<void> {
    await this.contributionHistory.recordForContextInTransaction(tx, context, {
      section: ContributionSection.GUESTS,
      entityType: ContributionEntityType.GUEST_GROUP,
      entityId: group.id,
      action,
      snapshot: buildContributionSnapshot(
        ContributionEntityType.GUEST_GROUP,
        { displayName: group.name },
      ),
      dedupeKey: `guest-group:${group.id}:${action.toLowerCase()}:${group.updatedAt.toISOString()}`,
      requiredPermission: ContributionPermission.MANAGE_GUESTS,
      occurredAt:
        action === ContributionAction.CREATED
          ? group.createdAt
          : group.updatedAt,
    });
  }

  private isIncompleteGuest(guest: {
    name: string;
    phone: string | null;
  }): boolean {
    return !guest.name.trim() || !guest.phone;
  }

  private async createGuestInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    dto: CreateGuestDto,
    context: PlanAccessContext,
    actorUserId: string,
  ): Promise<Guest> {
    await this.assertGroupLinkableInTransaction(
      tx,
      dto.groupId,
      weddingPlanId,
      context,
      actorUserId,
    );
    const name = this.requiredText(dto.name, "name");
    const normalizedName = this.normalizeGuestName(name);
    const phone = PhoneNormalizer.normalizeOptional(dto.phone);

    await this.assertGuestIsNotDuplicate(tx, {
      weddingPlanId,
      normalizedPhone: phone,
    });

    return tx.guest.create({
      data: {
        weddingPlanId,
        groupId: this.optionalId(dto.groupId),
        name,
        normalizedName,
        phone,
        normalizedPhone: phone,
        side: dto.side ?? GuestSide.OTHER,
        status:
          dto.status ??
          this.statusFromAttendance(dto.attendanceStatus) ??
          GuestStatus.INVITED,
        invitationStatus:
          dto.invitationStatus ?? GuestInvitationStatus.NOT_SENT,
        attendanceStatus:
          dto.attendanceStatus ?? this.attendanceFromStatus(dto.status),
        seatsCount: dto.seatsCount ?? 1,
        companionsCount: dto.companionsCount ?? 0,
        notes: this.optionalText(dto.notes),
      },
    });
  }

  private async findGuestOrThrow(id: string): Promise<Guest> {
    const guest = await this.prisma.guest.findUnique({ where: { id } });
    if (!guest) {
      throw new NotFoundException("Guest not found");
    }
    return guest;
  }

  private async findGroupOrThrow(id: string): Promise<GuestGroup> {
    const group = await this.prisma.guestGroup.findUnique({ where: { id } });
    if (!group) {
      throw new NotFoundException("Guest group not found");
    }
    return group;
  }

  private async findGuestInTransactionOrThrow(
    tx: Prisma.TransactionClient,
    id: string,
    weddingPlanId: string,
  ): Promise<Guest> {
    const locked = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "Guest"
        WHERE "id" = ${id}
          AND "weddingPlanId" = ${weddingPlanId}
        FOR UPDATE
      `,
    );
    if (locked.length !== 1) {
      throw new NotFoundException("Guest not found");
    }
    const guest = await tx.guest.findUnique({ where: { id } });
    if (!guest) {
      throw new NotFoundException("Guest not found");
    }
    return guest;
  }

  private async findGroupInTransactionOrThrow(
    tx: Prisma.TransactionClient,
    id: string,
    weddingPlanId: string,
  ): Promise<GuestGroup> {
    const locked = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "GuestGroup"
        WHERE "id" = ${id}
          AND "weddingPlanId" = ${weddingPlanId}
        FOR UPDATE
      `,
    );
    if (locked.length !== 1) {
      throw new NotFoundException("Guest group not found");
    }
    const group = await tx.guestGroup.findUnique({ where: { id } });
    if (!group) {
      throw new NotFoundException("Guest group not found");
    }
    return group;
  }

  private requiredText(value: string, field: string): string {
    const trimmed = value.trim();
    if (!trimmed) {
      throw new BadRequestException(`${field} must not be empty`);
    }
    return trimmed;
  }

  private optionalText(value: string | null | undefined): string | null {
    if (value === undefined || value === null) return null;
    const trimmed = value.trim();
    return trimmed || null;
  }

  private optionalId(value: string | null | undefined): string | null {
    return this.optionalText(value);
  }

  private normalizeGuestName(value: string): string {
    return value.trim().replace(/\s+/g, " ");
  }

  private async assertGuestIsNotDuplicate(
    tx: Prisma.TransactionClient,
    {
      weddingPlanId,
      normalizedPhone,
      excludeGuestId,
    }: {
      weddingPlanId: string;
      normalizedPhone: string | null;
      excludeGuestId?: string;
    },
  ): Promise<void> {
    if (!normalizedPhone) return;

    const duplicate = await tx.guest.findFirst({
      where: {
        weddingPlanId,
        normalizedPhone,
        ...(excludeGuestId ? { NOT: { id: excludeGuestId } } : {}),
      },
      select: { id: true },
    });

    if (duplicate) throw this.duplicateGuestConflict();
  }

  private async assertGroupBelongsToPlan(
    tx: Prisma.TransactionClient,
    groupId: string | null | undefined,
    weddingPlanId: string,
  ): Promise<void> {
    const normalizedId = this.optionalId(groupId);
    if (!normalizedId) return;

    const locked = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "GuestGroup"
        WHERE "id" = ${normalizedId}
          AND "weddingPlanId" = ${weddingPlanId}
        FOR SHARE
      `,
    );
    if (locked.length !== 1) {
      throw new BadRequestException("groupId must belong to the wedding plan");
    }
  }

  private async assertGroupLinkableInTransaction(
    tx: Prisma.TransactionClient,
    groupId: string | null | undefined,
    weddingPlanId: string,
    context: PlanAccessContext,
    actorUserId: string,
  ): Promise<void> {
    const normalizedId = this.optionalId(groupId);
    if (!normalizedId) return;
    await this.assertGroupBelongsToPlan(tx, normalizedId, weddingPlanId);
    if (!this.isContributor(context)) return;

    const groupIds =
      await this.contributorScope.qualifyingEntityIdsInTransaction(
        tx,
        weddingPlanId,
        actorUserId,
        [ContributionEntityType.GUEST_GROUP],
        [ContributionAction.CREATED],
      );
    if (!groupIds.includes(normalizedId)) {
      throw new NotFoundException("Guest group not found");
    }
  }

  private async catchDuplicateGuestConflict<T>(
    promise: Promise<T>,
  ): Promise<T> {
    try {
      return await promise;
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2002"
      ) {
        throw this.duplicateGuestConflict();
      }
      throw error;
    }
  }

  private duplicateGuestConflict(): ConflictException {
    return new ConflictException("هذا الضيف مضاف مسبقًا");
  }

  private async catchDuplicateGroupConflict<T>(
    promise: Promise<T>,
  ): Promise<T> {
    try {
      return await promise;
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2002"
      ) {
        throw new ConflictException("Guest group already exists");
      }
      throw error;
    }
  }

  private validSeatsCount(value: number): number {
    if (!Number.isInteger(value) || value < 1 || value > 20) {
      throw new BadRequestException(
        "seatsCount must be an integer between 1 and 20",
      );
    }
    return value;
  }

  private validCompanionsCount(value: number): number {
    if (!Number.isInteger(value) || value < 0 || value > 20) {
      throw new BadRequestException(
        "companionsCount must be an integer between 0 and 20",
      );
    }
    return value;
  }

  private attendanceFromStatus(
    status: GuestStatus | undefined,
  ): GuestAttendanceStatus {
    if (status === GuestStatus.CONFIRMED)
      return GuestAttendanceStatus.CONFIRMED;
    if (status === GuestStatus.DECLINED) return GuestAttendanceStatus.DECLINED;
    return GuestAttendanceStatus.PENDING;
  }

  private statusFromAttendance(
    status: GuestAttendanceStatus | undefined,
  ): GuestStatus | null {
    if (status === GuestAttendanceStatus.CONFIRMED)
      return GuestStatus.CONFIRMED;
    if (status === GuestAttendanceStatus.DECLINED) return GuestStatus.DECLINED;
    if (status === GuestAttendanceStatus.PENDING) return GuestStatus.PENDING;
    return null;
  }

  private toResponse(
    guest: Guest,
    includePrivateDetails = true,
    readableGroupIds: Set<string> | null = null,
  ): GuestResponse {
    const canReadGroup =
      readableGroupIds === null ||
      (guest.groupId !== null && readableGroupIds.has(guest.groupId));
    return {
      id: guest.id,
      weddingPlanId: guest.weddingPlanId,
      groupId: canReadGroup ? guest.groupId : null,
      name: guest.name,
      // Phone is PII: only members who can manage guests may read it. Pure
      // read-only members (e.g. VIEWER) see the guest without the number.
      phone: includePrivateDetails ? guest.phone : null,
      side: guest.side,
      status: guest.status,
      invitationStatus: guest.invitationStatus,
      attendanceStatus: guest.attendanceStatus,
      seatsCount: guest.seatsCount,
      companionsCount: guest.companionsCount,
      notes: includePrivateDetails ? guest.notes : null,
      createdAt: guest.createdAt,
      updatedAt: guest.updatedAt,
    };
  }

  private toGroupResponse(
    group: GuestGroup,
    includePrivateDetails = true,
  ): GuestGroupResponse {
    return {
      id: group.id,
      weddingPlanId: group.weddingPlanId,
      name: group.name,
      notes: includePrivateDetails ? group.notes : null,
      sortOrder: group.sortOrder,
      createdAt: group.createdAt,
      updatedAt: group.updatedAt,
    };
  }

  private emptySideCounts(): Record<GuestSide, number> {
    return {
      [GuestSide.GROOM]: 0,
      [GuestSide.BRIDE]: 0,
      [GuestSide.FAMILY]: 0,
      [GuestSide.FRIEND]: 0,
      [GuestSide.OTHER]: 0,
    };
  }

  private emptyInvitationStatusCounts(): Record<GuestInvitationStatus, number> {
    return {
      [GuestInvitationStatus.NOT_SENT]: 0,
      [GuestInvitationStatus.SENT]: 0,
      [GuestInvitationStatus.DELIVERED]: 0,
    };
  }

  private emptyAttendanceStatusCounts(): Record<GuestAttendanceStatus, number> {
    return {
      [GuestAttendanceStatus.PENDING]: 0,
      [GuestAttendanceStatus.CONFIRMED]: 0,
      [GuestAttendanceStatus.DECLINED]: 0,
    };
  }
}
