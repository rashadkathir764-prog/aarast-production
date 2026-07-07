import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  Guest,
  GuestAttendanceStatus,
  GuestGroup,
  GuestInvitationStatus,
  GuestSide,
  GuestStatus,
  Prisma,
} from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { ListQueryDto, pageArgs } from '../common/pagination/list-query.dto';
import { PhoneNormalizer } from '../common/phone/phone-normalizer';
import { PrismaService } from '../prisma/prisma.service';
import { PermissionService } from '../sharing/permission.service';
import { BulkGuestsDto } from './dto/bulk-guests.dto';
import { CreateGuestGroupDto } from './dto/create-guest-group.dto';
import { CreateGuestDto } from './dto/create-guest.dto';
import { UpdateGuestGroupDto } from './dto/update-guest-group.dto';
import { UpdateGuestDto } from './dto/update-guest.dto';

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
  ) {}

  async findForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    query?: ListQueryDto,
  ): Promise<GuestResponse[]> {
    await this.permissions.assertPlanReadable(weddingPlanId, currentUser);

    const guests = await this.prisma.guest.findMany({
      where: { weddingPlanId },
      orderBy: [{ createdAt: 'desc' }],
      ...pageArgs(query),
    });

    return guests.map((guest) => this.toResponse(guest));
  }

  async findOne(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<GuestResponse> {
    const guest = await this.findGuestOrThrow(id);
    await this.permissions.assertPlanReadable(guest.weddingPlanId, currentUser);
    return this.toResponse(guest);
  }

  async create(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateGuestDto,
  ): Promise<GuestResponse> {
    await this.permissions.assertGuestManageable(weddingPlanId, currentUser);
    await this.assertGroupBelongsToPlan(dto.groupId, weddingPlanId);
    const name = this.requiredText(dto.name, 'name');
    const normalizedName = this.normalizeGuestName(name);
    const phone = PhoneNormalizer.normalizeOptional(dto.phone);

    await this.assertGuestIsNotDuplicate({
      weddingPlanId,
      normalizedPhone: phone,
    });

    const guest = await this.catchDuplicateGuestConflict(
      this.prisma.guest.create({
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
          invitationStatus: dto.invitationStatus ?? GuestInvitationStatus.NOT_SENT,
          attendanceStatus:
            dto.attendanceStatus ?? this.attendanceFromStatus(dto.status),
          seatsCount: dto.seatsCount ?? 1,
          companionsCount: dto.companionsCount ?? 0,
          notes: this.optionalText(dto.notes),
        },
      }),
    );

    return this.toResponse(guest);
  }

  async bulkCreate(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: BulkGuestsDto,
  ): Promise<BulkGuestsResponse> {
    await this.permissions.assertGuestManageable(weddingPlanId, currentUser);
    if (!Array.isArray(dto.items) || dto.items.length === 0) {
      throw new BadRequestException('items must contain at least one guest');
    }
    if (dto.items.length > 200) {
      throw new BadRequestException('items must not exceed 200 guests');
    }

    const created: GuestResponse[] = [];
    for (const item of dto.items) {
      created.push(await this.create(currentUser, weddingPlanId, item));
    }

    return { created };
  }

  async update(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateGuestDto,
  ): Promise<GuestResponse> {
    const existing = await this.findGuestOrThrow(id);
    await this.permissions.assertGuestManageable(existing.weddingPlanId, currentUser);
    if (dto.groupId !== undefined) {
      await this.assertGroupBelongsToPlan(dto.groupId, existing.weddingPlanId);
    }
    const name =
      dto.name !== undefined ? this.requiredText(dto.name, 'name') : existing.name;
    const normalizedName = this.normalizeGuestName(name);
    const phone =
      dto.phone !== undefined
        ? PhoneNormalizer.normalizeOptional(dto.phone)
        : existing.normalizedPhone;
    const groupId =
      dto.groupId !== undefined ? this.optionalId(dto.groupId) : undefined;
    const mappedStatus =
      dto.attendanceStatus !== undefined
        ? this.statusFromAttendance(dto.attendanceStatus)
        : null;

    await this.assertGuestIsNotDuplicate({
      weddingPlanId: existing.weddingPlanId,
      normalizedPhone: phone,
      excludeGuestId: existing.id,
    });

    const guest = await this.catchDuplicateGuestConflict(
      this.prisma.guest.update({
        where: { id },
        data: {
          normalizedName,
          ...(dto.name !== undefined ? { name } : {}),
          ...(dto.phone !== undefined ? { phone, normalizedPhone: phone } : {}),
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
            ? { companionsCount: this.validCompanionsCount(dto.companionsCount) }
            : {}),
          ...(dto.notes !== undefined ? { notes: this.optionalText(dto.notes) } : {}),
        },
      }),
    );

    return this.toResponse(guest);
  }

  async remove(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    const existing = await this.findGuestOrThrow(id);
    await this.permissions.assertGuestManageable(existing.weddingPlanId, currentUser);
    await this.prisma.guest.delete({ where: { id } });
    return { id, deleted: true };
  }

  async findGroups(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<GuestGroupResponse[]> {
    await this.permissions.assertPlanReadable(weddingPlanId, currentUser);
    const groups = await this.prisma.guestGroup.findMany({
      where: { weddingPlanId },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
    });
    return groups.map((group) => this.toGroupResponse(group));
  }

  async createGroup(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateGuestGroupDto,
  ): Promise<GuestGroupResponse> {
    await this.permissions.assertGuestManageable(weddingPlanId, currentUser);
    const group = await this.catchDuplicateGroupConflict(
      this.prisma.guestGroup.create({
        data: {
          weddingPlanId,
          name: this.requiredText(dto.name, 'name'),
          notes: this.optionalText(dto.notes),
          sortOrder: dto.sortOrder ?? 0,
        },
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
    await this.permissions.assertGuestManageable(existing.weddingPlanId, currentUser);
    const group = await this.catchDuplicateGroupConflict(
      this.prisma.guestGroup.update({
        where: { id },
        data: {
          ...(dto.name !== undefined
            ? { name: this.requiredText(dto.name, 'name') }
            : {}),
          ...(dto.notes !== undefined ? { notes: this.optionalText(dto.notes) } : {}),
          ...(dto.sortOrder !== undefined ? { sortOrder: dto.sortOrder } : {}),
        },
      }),
    );
    return this.toGroupResponse(group);
  }

  async removeGroup(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    const existing = await this.findGroupOrThrow(id);
    await this.permissions.assertGuestManageable(existing.weddingPlanId, currentUser);
    await this.prisma.guestGroup.delete({ where: { id } });
    return { id, deleted: true };
  }

  async summary(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<GuestsSummaryResponse> {
    await this.permissions.assertPlanReadable(weddingPlanId, currentUser);
    const [guests, groupsCount] = await Promise.all([
      this.prisma.guest.findMany({
        where: { weddingPlanId },
        include: { group: { select: { name: true } } },
      }),
      this.prisma.guestGroup.count({ where: { weddingPlanId } }),
    ]);
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
      const groupKey = guest.group?.name ?? 'ungrouped';
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
      invitedGuests: guests.filter((guest) => guest.status === GuestStatus.INVITED)
        .length,
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
  }

  private isIncompleteGuest(guest: { name: string; phone: string | null }): boolean {
    return !guest.name.trim() || !guest.phone;
  }

  private async findGuestOrThrow(id: string): Promise<Guest> {
    const guest = await this.prisma.guest.findUnique({ where: { id } });
    if (!guest) {
      throw new NotFoundException('Guest not found');
    }
    return guest;
  }

  private async findGroupOrThrow(id: string): Promise<GuestGroup> {
    const group = await this.prisma.guestGroup.findUnique({ where: { id } });
    if (!group) {
      throw new NotFoundException('Guest group not found');
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
    return value.trim().replace(/\s+/g, ' ');
  }

  private async assertGuestIsNotDuplicate({
    weddingPlanId,
    normalizedPhone,
    excludeGuestId,
  }: {
    weddingPlanId: string;
    normalizedPhone: string | null;
    excludeGuestId?: string;
  }): Promise<void> {
    if (!normalizedPhone) return;

    const duplicate = await this.prisma.guest.findFirst({
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
    groupId: string | null | undefined,
    weddingPlanId: string,
  ): Promise<void> {
    const normalizedId = this.optionalId(groupId);
    if (!normalizedId) return;

    const group = await this.prisma.guestGroup.findFirst({
      where: { id: normalizedId, weddingPlanId },
      select: { id: true },
    });
    if (!group) {
      throw new BadRequestException('groupId must belong to the wedding plan');
    }
  }

  private async catchDuplicateGuestConflict<T>(promise: Promise<T>): Promise<T> {
    try {
      return await promise;
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw this.duplicateGuestConflict();
      }
      throw error;
    }
  }

  private duplicateGuestConflict(): ConflictException {
    return new ConflictException('هذا الضيف مضاف مسبقًا');
  }

  private async catchDuplicateGroupConflict<T>(promise: Promise<T>): Promise<T> {
    try {
      return await promise;
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        throw new ConflictException('Guest group already exists');
      }
      throw error;
    }
  }

  private validSeatsCount(value: number): number {
    if (!Number.isInteger(value) || value < 1 || value > 20) {
      throw new BadRequestException('seatsCount must be an integer between 1 and 20');
    }
    return value;
  }

  private validCompanionsCount(value: number): number {
    if (!Number.isInteger(value) || value < 0 || value > 20) {
      throw new BadRequestException(
        'companionsCount must be an integer between 0 and 20',
      );
    }
    return value;
  }

  private attendanceFromStatus(status: GuestStatus | undefined): GuestAttendanceStatus {
    if (status === GuestStatus.CONFIRMED) return GuestAttendanceStatus.CONFIRMED;
    if (status === GuestStatus.DECLINED) return GuestAttendanceStatus.DECLINED;
    return GuestAttendanceStatus.PENDING;
  }

  private statusFromAttendance(
    status: GuestAttendanceStatus | undefined,
  ): GuestStatus | null {
    if (status === GuestAttendanceStatus.CONFIRMED) return GuestStatus.CONFIRMED;
    if (status === GuestAttendanceStatus.DECLINED) return GuestStatus.DECLINED;
    if (status === GuestAttendanceStatus.PENDING) return GuestStatus.PENDING;
    return null;
  }

  private toResponse(guest: Guest): GuestResponse {
    return {
      id: guest.id,
      weddingPlanId: guest.weddingPlanId,
      groupId: guest.groupId,
      name: guest.name,
      phone: guest.phone,
      side: guest.side,
      status: guest.status,
      invitationStatus: guest.invitationStatus,
      attendanceStatus: guest.attendanceStatus,
      seatsCount: guest.seatsCount,
      companionsCount: guest.companionsCount,
      notes: guest.notes,
      createdAt: guest.createdAt,
      updatedAt: guest.updatedAt,
    };
  }

  private toGroupResponse(group: GuestGroup): GuestGroupResponse {
    return {
      id: group.id,
      weddingPlanId: group.weddingPlanId,
      name: group.name,
      notes: group.notes,
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
