import { HttpStatus, Inject, Injectable } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { createHash } from "node:crypto";
import { AuthErrorCode, authError } from "../../identity/public/auth-error";
import {
  IDENTITY_AUTH_PORT,
  IdentityAuthPort,
  OtpDispatchContext,
} from "../../identity/public/identity-auth.port";
import { PhoneNormalizer } from "../../../shared-kernel/phone/phone-normalizer";
import { PrismaService } from "../../../platform/database/prisma.service";
import {
  USER_READ_PORT,
  type UserReadPort,
} from "../../identity/public/user-read.port";
import { RequestInviteOtpDto } from "../api/dto/request-invite-otp.dto";
import { VerifyInviteOtpDto } from "../api/dto/verify-invite-otp.dto";

@Injectable()
export class InviteAccessService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(IDENTITY_AUTH_PORT)
    private readonly auth: IdentityAuthPort,
    @Inject(USER_READ_PORT)
    private readonly users: UserReadPort,
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

    // Whether the invited phone's account still needs its setup step is
    // identity's decision; collaboration only learns the outcome.
    const account = await this.users.findInviteAccountByPhoneVariants(
      this.prisma,
      PhoneNormalizer.lookupVariants(phone),
    );
    if (invite.acceptedAt) {
      if (!account || account.appPasswordConfigured) {
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
    const accountSetupRequired = !account || account.accountSetupRequired;
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
