import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Guest, GuestSide, GuestStatus } from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { PrismaService } from '../prisma/prisma.service';
import { PermissionService } from '../sharing/permission.service';
import { CreateGuestDto } from './dto/create-guest.dto';
import { UpdateGuestDto } from './dto/update-guest.dto';

export interface GuestResponse {
  id: string;
  weddingPlanId: string;
  name: string;
  phone: string | null;
  side: GuestSide;
  status: GuestStatus;
  seatsCount: number;
  notes: string | null;
  createdAt: Date;
  updatedAt: Date;
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
  ): Promise<GuestResponse[]> {
    await this.permissions.assertPlanReadable(weddingPlanId, currentUser);

    const guests = await this.prisma.guest.findMany({
      where: { weddingPlanId },
      orderBy: [{ createdAt: 'desc' }],
    });

    return guests.map((guest) => this.toResponse(guest));
  }

  async create(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateGuestDto,
  ): Promise<GuestResponse> {
    await this.permissions.assertPlanManageable(weddingPlanId, currentUser);

    const guest = await this.prisma.guest.create({
      data: {
        weddingPlanId,
        name: this.requiredText(dto.name, 'name'),
        phone: this.optionalText(dto.phone),
        side: dto.side ?? GuestSide.OTHER,
        status: dto.status ?? GuestStatus.INVITED,
        seatsCount: dto.seatsCount ?? 1,
        notes: this.optionalText(dto.notes),
      },
    });

    return this.toResponse(guest);
  }

  async update(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateGuestDto,
  ): Promise<GuestResponse> {
    const existing = await this.findGuestOrThrow(id);
    await this.permissions.assertPlanManageable(existing.weddingPlanId, currentUser);

    const guest = await this.prisma.guest.update({
      where: { id },
      data: {
        ...(dto.name !== undefined
          ? { name: this.requiredText(dto.name, 'name') }
          : {}),
        ...(dto.phone !== undefined ? { phone: this.optionalText(dto.phone) } : {}),
        ...(dto.side !== undefined ? { side: dto.side } : {}),
        ...(dto.status !== undefined ? { status: dto.status } : {}),
        ...(dto.seatsCount !== undefined
          ? { seatsCount: this.validSeatsCount(dto.seatsCount) }
          : {}),
        ...(dto.notes !== undefined ? { notes: this.optionalText(dto.notes) } : {}),
      },
    });

    return this.toResponse(guest);
  }

  async remove(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    const existing = await this.findGuestOrThrow(id);
    await this.permissions.assertPlanManageable(existing.weddingPlanId, currentUser);
    await this.prisma.guest.delete({ where: { id } });
    return { id, deleted: true };
  }

  private async findGuestOrThrow(id: string): Promise<Guest> {
    const guest = await this.prisma.guest.findUnique({ where: { id } });
    if (!guest) {
      throw new NotFoundException('Guest not found');
    }
    return guest;
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

  private validSeatsCount(value: number): number {
    if (!Number.isInteger(value) || value < 1 || value > 20) {
      throw new BadRequestException('seatsCount must be an integer between 1 and 20');
    }
    return value;
  }

  private toResponse(guest: Guest): GuestResponse {
    return {
      id: guest.id,
      weddingPlanId: guest.weddingPlanId,
      name: guest.name,
      phone: guest.phone,
      side: guest.side,
      status: guest.status,
      seatsCount: guest.seatsCount,
      notes: guest.notes,
      createdAt: guest.createdAt,
      updatedAt: guest.updatedAt,
    };
  }
}
