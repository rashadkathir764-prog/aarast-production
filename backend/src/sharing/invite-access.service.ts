import { HttpStatus, Injectable } from '@nestjs/common';
import { OtpPurpose } from '@prisma/client';
import { createHash } from 'node:crypto';
import { AuthErrorCode, authError } from '../auth/auth-error';
import { AuthService } from '../auth/auth.service';
import { OtpDispatchContext } from '../auth/otp-dispatch-quota.service';
import { PhoneNormalizer } from '../common/phone/phone-normalizer';
import { PrismaService } from '../prisma/prisma.service';
import { RequestInviteOtpDto } from './dto/request-invite-otp.dto';

@Injectable()
export class InviteAccessService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auth: AuthService,
  ) {}

  async requestOtp(
    token: string,
    dto: RequestInviteOtpDto,
    context: OtpDispatchContext,
  ) {
    const cleanToken = token.trim();
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    if (!/^[A-Za-z0-9_-]{43}$/.test(cleanToken)) {
      throw this.inviteNotFound();
    }

    const now = new Date();
    const invite = await this.prisma.planInvite.findFirst({
      where: {
        tokenHash: createHash('sha256').update(cleanToken).digest('hex'),
        normalizedPhone: phone,
        acceptedAt: null,
        declinedAt: null,
        revokedAt: null,
        expiresAt: { gt: now },
      },
      select: { id: true },
    });
    if (!invite) throw this.inviteNotFound();

    return this.auth.requestOtp(
      { phone, purpose: OtpPurpose.LOGIN },
      context,
    );
  }

  private inviteNotFound() {
    return authError(
      HttpStatus.NOT_FOUND,
      AuthErrorCode.INVITE_NOT_FOUND_FOR_PHONE,
      'No active invitation matches this phone',
    );
  }
}
