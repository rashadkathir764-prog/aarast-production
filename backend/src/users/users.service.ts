import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { NotificationPreference } from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { SafeUser, toSafeUser } from '../auth/safe-user';
import { PhoneNormalizer } from '../common/phone/phone-normalizer';
import { PrismaService } from '../prisma/prisma.service';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { UpdateSettingsDto } from './dto/update-settings.dto';

export interface NotificationPreferenceResponse {
  id: string;
  userId: string;
  pushEnabled: boolean;
  smsEnabled: boolean;
  whatsappEnabled: boolean;
  emailEnabled: boolean;
  taskRemindersEnabled: boolean;
  paymentRemindersEnabled: boolean;
  providerMessagesEnabled: boolean;
  createdAt: Date;
  updatedAt: Date;
}

/// Deliberately minimal: lookup exists only so a plan owner can confirm a
/// member before inviting. No avatar and no extra profile data — phone
/// numbers must not become a directory of user photos (culturally
/// sensitive, privacy-critical in Yemen).
export interface UserLookupResponse {
  id: string;
  name: string;
  phone: string | null;
}

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  async updateMe(
    currentUser: AuthenticatedUser,
    dto: UpdateProfileDto,
  ): Promise<SafeUser> {
    const email = this.optionalText(dto.email);

    if (email) {
      const existing = await this.prisma.user.findUnique({ where: { email } });
      if (existing && existing.id !== currentUser.id) {
        throw new ConflictException('Email is already registered');
      }
    }

    const user = await this.prisma.user.update({
      where: { id: currentUser.id },
      data: {
        ...(dto.name !== undefined
          ? { name: this.requiredText(dto.name, 'name') }
          : {}),
        ...(dto.email !== undefined ? { email } : {}),
        ...(dto.avatarUrl !== undefined
          ? { avatarUrl: this.optionalText(dto.avatarUrl) }
          : {}),
        ...(dto.locale !== undefined
          ? { locale: this.requiredText(dto.locale, 'locale') }
          : {}),
        ...(dto.appRole !== undefined ? { appRole: dto.appRole } : {}),
        ...(dto.persona !== undefined ? { persona: dto.persona } : {}),
      },
    });

    return toSafeUser(user);
  }

  async lookupByPhone(phone: string): Promise<UserLookupResponse> {
    const normalizedPhone = PhoneNormalizer.normalizeRequired(phone);
    const user = await this.prisma.user.findFirst({
      where: {
        phone: { in: PhoneNormalizer.lookupVariants(normalizedPhone) },
      },
      select: {
        id: true,
        name: true,
        phone: true,
      },
    });

    if (!user) {
      throw new NotFoundException('User not found for phone');
    }

    return user;
  }

  async getSettings(
    currentUser: AuthenticatedUser,
  ): Promise<NotificationPreferenceResponse> {
    const settings = await this.prisma.notificationPreference.upsert({
      where: { userId: currentUser.id },
      update: {},
      create: { userId: currentUser.id },
    });

    return this.toSettingsResponse(settings);
  }

  async updateSettings(
    currentUser: AuthenticatedUser,
    dto: UpdateSettingsDto,
  ): Promise<NotificationPreferenceResponse> {
    const settings = await this.prisma.notificationPreference.upsert({
      where: { userId: currentUser.id },
      create: {
        userId: currentUser.id,
        ...dto,
      },
      update: dto,
    });

    return this.toSettingsResponse(settings);
  }

  private requiredText(value: string | null | undefined, field: string): string {
    const trimmed = value?.trim() ?? '';
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

  private toSettingsResponse(
    settings: NotificationPreference,
  ): NotificationPreferenceResponse {
    return {
      id: settings.id,
      userId: settings.userId,
      pushEnabled: settings.pushEnabled,
      smsEnabled: settings.smsEnabled,
      whatsappEnabled: settings.whatsappEnabled,
      emailEnabled: settings.emailEnabled,
      taskRemindersEnabled: settings.taskRemindersEnabled,
      paymentRemindersEnabled: settings.paymentRemindersEnabled,
      providerMessagesEnabled: settings.providerMessagesEnabled,
      createdAt: settings.createdAt,
      updatedAt: settings.updatedAt,
    };
  }
}
