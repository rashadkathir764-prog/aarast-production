import { HttpStatus, Injectable } from "@nestjs/common";
import { Prisma, UserRole } from "@prisma/client";
import { createHash } from "node:crypto";
import { AuthErrorCode, authError } from "../auth/auth-error";
import { AuthService } from "../auth/auth.service";
import { OtpDispatchContext } from "../auth/otp-dispatch-quota.service";
import { PhoneNormalizer } from "../shared-kernel/phone/phone-normalizer";
import { PrismaService } from "../platform/database/prisma.service";
import { RequestInviteOtpDto } from "./dto/request-invite-otp.dto";
import { VerifyInviteOtpDto } from "./dto/verify-invite-otp.dto";

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

    const expectedTokenHash = createHash("sha256")
      .update(cleanToken)
      .digest("hex");
    const now = new Date();
    const invite = await this.prisma.planInvite.findFirst({
      where: {
        tokenHash: expectedTokenHash,
        normalizedPhone: phone,
        declinedAt: null,
        revokedAt: null,
        expiresAt: { gt: now },
      },
      select: { id: true, acceptedAt: true, weddingPlanId: true },
    });
    if (!invite) throw this.inviteNotFound();

    const account = await this.prisma.user.findFirst({
      where: { phone: { in: PhoneNormalizer.lookupVariants(phone) } },
      select: {
        id: true,
        role: true,
        phoneVerifiedAt: true,
        appPasswordHash: true,
        appPasswordConfiguredAt: true,
      },
    });
    if (invite.acceptedAt) {
      if (!account || account.appPasswordConfiguredAt) {
        throw this.inviteNotFound();
      }
      const existingMembership = await this.prisma.sharedMember.findUnique({
        where: {
          weddingPlanId_userId: {
            weddingPlanId: invite.weddingPlanId,
            userId: account.id,
          },
        },
        select: { id: true },
      });
      if (!existingMembership) throw this.inviteNotFound();
    }
    const accountSetupRequired =
      !account ||
      !account.appPasswordConfiguredAt ||
      (!account.phoneVerifiedAt && account.role !== UserRole.ADMIN) ||
      (account.role === UserRole.ADMIN && !account.appPasswordHash);
    let otp;
    try {
      otp = await this.auth.requestInviteOtp(
        phone,
        invite.id,
        expectedTokenHash,
        context,
        invite.acceptedAt !== null,
      );
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2003"
      ) {
        throw this.inviteNotFound();
      }
      throw error;
    }
    return { ...otp, accountSetupRequired };
  }

  verifyOtp(token: string, dto: VerifyInviteOtpDto) {
    return this.auth.verifyInviteOtp({
      token,
      phone: dto.phone,
      code: dto.code,
      name: dto.name,
      password: dto.password,
    });
  }

  private inviteNotFound() {
    return authError(
      HttpStatus.NOT_FOUND,
      AuthErrorCode.INVITE_NOT_FOUND_FOR_PHONE,
      "No active invitation matches this phone",
    );
  }
}
