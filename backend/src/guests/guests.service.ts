import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Guest, GuestSide, GuestStatus, Prisma } from '@prisma/client';
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
    const name = this.requiredText(dto.name, 'name');
    const normalizedName = this.normalizeGuestName(name);
    const phone = this.optionalYemeniPhone(dto.phone);

    await this.assertGuestIsNotDuplicate({
      weddingPlanId,
      normalizedName,
      normalizedPhone: phone,
    });

    const guest = await this.catchDuplicateGuestConflict(
      this.prisma.guest.create({
        data: {
          weddingPlanId,
          name,
          normalizedName,
          phone,
          normalizedPhone: phone,
          side: dto.side ?? GuestSide.OTHER,
          status: dto.status ?? GuestStatus.INVITED,
          seatsCount: dto.seatsCount ?? 1,
          notes: this.optionalText(dto.notes),
        },
      }),
    );

    return this.toResponse(guest);
  }

  async update(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateGuestDto,
  ): Promise<GuestResponse> {
    const existing = await this.findGuestOrThrow(id);
    await this.permissions.assertPlanManageable(existing.weddingPlanId, currentUser);
    const name =
      dto.name !== undefined ? this.requiredText(dto.name, 'name') : existing.name;
    const normalizedName = this.normalizeGuestName(name);
    const phone =
      dto.phone !== undefined
        ? this.optionalYemeniPhone(dto.phone)
        : existing.normalizedPhone;

    await this.assertGuestIsNotDuplicate({
      weddingPlanId: existing.weddingPlanId,
      normalizedName,
      normalizedPhone: phone,
      excludeGuestId: existing.id,
    });

    const guest = await this.catchDuplicateGuestConflict(
      this.prisma.guest.update({
        where: { id },
        data: {
          normalizedName,
          ...(dto.name !== undefined ? { name } : {}),
          ...(dto.phone !== undefined
            ? { phone, normalizedPhone: phone }
            : {}),
          ...(dto.side !== undefined ? { side: dto.side } : {}),
          ...(dto.status !== undefined ? { status: dto.status } : {}),
          ...(dto.seatsCount !== undefined
            ? { seatsCount: this.validSeatsCount(dto.seatsCount) }
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

  private optionalYemeniPhone(value: string | null | undefined): string | null {
    const phone = this.optionalText(value);
    if (!phone) return null;
    return this.normalizeYemeniPhone(phone);
  }

  private normalizeGuestName(value: string): string {
    return value.trim().replace(/\s+/g, ' ');
  }

  private normalizeYemeniPhone(value: string): string {
    const asciiValue = this.toAsciiDigits(value).trim();
    const digits = asciiValue.replace(/[^0-9]/g, '');
    if (!digits) {
      throw new BadRequestException('phone must be a valid Yemeni phone number');
    }

    const local = this.localYemeniDigits(asciiValue, digits);
    if (local.length !== 9) {
      throw new BadRequestException('phone must be a valid Yemeni phone number');
    }

    return `+967${local}`;
  }

  private localYemeniDigits(value: string, digits: string): string {
    if (value.startsWith('+')) {
      if (!digits.startsWith('967')) {
        throw new BadRequestException('phone must be a valid Yemeni phone number');
      }
      return digits.slice(3);
    }

    if (digits.startsWith('00967')) {
      return digits.slice(5);
    }

    if (digits.startsWith('967')) {
      return digits.slice(3);
    }

    if (digits.startsWith('0')) {
      return digits.slice(1);
    }

    return digits;
  }

  private toAsciiDigits(value: string): string {
    let result = '';
    for (const char of value) {
      const codePoint = char.codePointAt(0);
      if (codePoint !== undefined && codePoint >= 0x0660 && codePoint <= 0x0669) {
        result += String.fromCharCode(0x30 + codePoint - 0x0660);
      } else if (
        codePoint !== undefined &&
        codePoint >= 0x06f0 &&
        codePoint <= 0x06f9
      ) {
        result += String.fromCharCode(0x30 + codePoint - 0x06f0);
      } else {
        result += char;
      }
    }
    return result;
  }

  private async assertGuestIsNotDuplicate({
    weddingPlanId,
    normalizedName,
    normalizedPhone,
    excludeGuestId,
  }: {
    weddingPlanId: string;
    normalizedName: string;
    normalizedPhone: string | null;
    excludeGuestId?: string;
  }): Promise<void> {
    if (!normalizedPhone) return;

    const duplicate = await this.prisma.guest.findFirst({
      where: {
        weddingPlanId,
        normalizedName,
        normalizedPhone,
        ...(excludeGuestId ? { NOT: { id: excludeGuestId } } : {}),
      },
      select: { id: true },
    });

    if (duplicate) {
      throw this.duplicateGuestConflict();
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
