import {
  BadRequestException,
  ConflictException,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { OtpCode, OtpPurpose, Prisma, User, UserRole } from "@prisma/client";
import * as bcryptjs from "bcryptjs";
import { randomBytes } from "crypto";
import {
  otpRequestsTotal,
  otpVerificationsTotal,
} from "../common/observability/metrics";
import { PhoneNormalizer } from "../common/phone/phone-normalizer";
import { PrismaService } from "../prisma/prisma.service";
import { RegisterDto } from "./dto/register.dto";
import { CompleteRegistrationDto } from "./dto/complete-registration.dto";
import { LoginDto } from "./dto/login.dto";
import { RequestOtpDto } from "./dto/request-otp.dto";
import { VerifyOtpDto } from "./dto/verify-otp.dto";
import { LogoutDto } from "./dto/logout.dto";
import { RefreshDto } from "./dto/refresh.dto";
import { PasswordResetRequestDto } from "./dto/password-reset-request.dto";
import { PasswordResetConfirmDto } from "./dto/password-reset-confirm.dto";
import { JwtPayload } from "./jwt-payload.interface";
import {
  DevEchoOtpChannel,
  OpenWaOtpChannel,
  OtpChannel,
  WhatsAppOtpChannel,
} from "./otp-channel";
import {
  createRefreshTokenValue,
  hashRefreshToken,
  refreshTokenExpiry,
} from "./refresh-token-policy";
import { SafeUser, toSafeUser } from "./safe-user";
import { LoginThrottleService } from "./login-throttle.service";
import {
  OtpDispatchContext,
  OtpDispatchQuotaService,
} from "./otp-dispatch-quota.service";

export interface AuthResponse {
  user: SafeUser;
  accessToken: string;
  refreshToken: string;
  refreshTokenExpiresAt: Date;
}

export interface OtpRequestResponse {
  phone: string;
  purpose: OtpPurpose;
  expiresAt: Date;
  delivery: "LOCAL_DEV" | "WHATSAPP";
  code?: string;
  message?: string;
}

export interface RegistrationPendingResponse extends OtpRequestResponse {
  registrationPending: true;
}

export interface OtpVerifyResponse {
  verified: true;
  phone: string;
  purpose: OtpPurpose;
  user?: SafeUser;
  accessToken?: string;
  refreshToken?: string;
  refreshTokenExpiresAt?: Date;
}

export interface AdminLoginPendingResponse {
  mfaRequired: true;
  challengeToken: string;
  expiresAt: Date;
  delivery: "LOCAL_DEV" | "WHATSAPP";
  code?: string;
}

@Injectable()
export class AuthService {
  private static readonly otpUnavailableMessage =
    "خدمة التحقق غير مفعلة حاليًا. حاول لاحقًا.";
  private static readonly dummyPasswordHash =
    "$2b$10$jnsLrksGKUtGyEjkRk/CeO5zUi9WwfPpG6.bREun6R8yXlN85DEq6";

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly loginThrottle: LoginThrottleService,
    private readonly otpDispatchQuota: OtpDispatchQuotaService =
      new OtpDispatchQuotaService(prisma),
  ) {}

  async startRegistration(
    dto: RegisterDto,
    context: OtpDispatchContext = {},
  ): Promise<RegistrationPendingResponse> {
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    const otp = await this.requestOtp({
      phone,
      purpose: OtpPurpose.REGISTER,
    }, context);
    return { registrationPending: true, ...otp };
  }

  async completeRegistration(
    dto: CompleteRegistrationDto,
  ): Promise<AuthResponse> {
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    const phoneVariants = PhoneNormalizer.lookupVariants(phone);
    const now = new Date();
    const otp = await this.assertOtpCodeMatches(
      phone,
      OtpPurpose.REGISTER,
      dto.otpCode,
      now,
    );
    const passwordHash = await bcryptjs.hash(dto.password, 10);

    let user: User;
    try {
      user = await this.prisma.$transaction(
        async (tx) => {
          const conflict = await tx.user.findFirst({
            where: {
              OR: [
                { phone: { in: phoneVariants } },
                ...(dto.email ? [{ email: dto.email }] : []),
              ],
            },
          });
          if (conflict) {
            throw new ConflictException("Phone or email already registered");
          }

          await this.consumeOtpRecord(tx, otp, now);
          return tx.user.create({
            data: {
              name: dto.name,
              phone,
              email: dto.email ?? null,
              passwordHash,
              phoneVerifiedAt: now,
              lastLoginAt: now,
            },
          });
        },
        { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
      );
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2034"
      ) {
        otpVerificationsTotal.inc({ outcome: "failure" });
        throw new BadRequestException("OTP code is invalid or expired");
      }
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2002"
      ) {
        throw new ConflictException("Phone or email already registered");
      }
      throw error;
    }

    otpVerificationsTotal.inc({ outcome: "success" });

    return this.createAuthResponse(user);
  }

  async login(dto: LoginDto): Promise<AuthResponse> {
    const user = await this.validatePasswordCredentials(dto);
    if (user.role === UserRole.ADMIN) {
      throw new UnauthorizedException(
        "Admin accounts must use password and OTP login",
      );
    }
    const updatedUser = await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    return this.createAuthResponse(updatedUser);
  }

  async startAdminLogin(
    dto: LoginDto,
    context: OtpDispatchContext = {},
  ): Promise<AdminLoginPendingResponse> {
    const user = await this.validatePasswordCredentials(dto, UserRole.ADMIN);
    const otp = await this.requestOtp({
      phone: user.phone!,
      purpose: OtpPurpose.LOGIN,
    }, context);
    const challengeToken = createRefreshTokenValue();
    const now = new Date();
    const expiresAt = new Date(
      Math.min(otp.expiresAt.getTime(), now.getTime() + 10 * 60_000),
    );

    await this.prisma.$transaction([
      this.prisma.adminLoginChallenge.deleteMany({
        where: {
          OR: [
            { expiresAt: { lt: now } },
            { userId: user.id, consumedAt: null },
          ],
        },
      }),
      this.prisma.adminLoginChallenge.create({
        data: {
          userId: user.id,
          tokenHash: hashRefreshToken(challengeToken),
          expiresAt,
        },
      }),
    ]);

    return {
      mfaRequired: true,
      challengeToken,
      expiresAt,
      delivery: otp.delivery,
      ...(otp.code ? { code: otp.code } : {}),
    };
  }

  async completeAdminLogin(
    challengeToken: string,
    code: string,
  ): Promise<AuthResponse> {
    const now = new Date();
    const challenge = await this.prisma.adminLoginChallenge.findUnique({
      where: { tokenHash: hashRefreshToken(challengeToken) },
      include: { user: true },
    });
    if (
      !challenge ||
      challenge.consumedAt ||
      challenge.expiresAt <= now ||
      challenge.user.role !== UserRole.ADMIN ||
      challenge.user.status === "DISABLED" ||
      !challenge.user.phone ||
      !challenge.user.phoneVerifiedAt
    ) {
      throw new UnauthorizedException(
        "Admin login challenge is invalid or expired",
      );
    }

    const otp = await this.assertOtpCodeMatches(
      challenge.user.phone,
      OtpPurpose.LOGIN,
      code,
      now,
    );

    let updatedUser: User;
    try {
      updatedUser = await this.prisma.$transaction(
        async (tx) => {
          const consumedChallenge = await tx.adminLoginChallenge.updateMany({
            where: {
              id: challenge.id,
              consumedAt: null,
              expiresAt: { gt: now },
            },
            data: { consumedAt: now },
          });
          if (consumedChallenge.count !== 1) {
            throw new UnauthorizedException(
              "Admin login challenge is invalid or expired",
            );
          }

          await this.consumeOtpRecord(tx, otp, now);
          const eligible = await tx.user.updateMany({
            where: {
              id: challenge.userId,
              role: UserRole.ADMIN,
              status: "ACTIVE",
              phoneVerifiedAt: { not: null },
            },
            data: { lastLoginAt: now },
          });
          if (eligible.count !== 1) {
            throw new UnauthorizedException("Admin access is required");
          }
          return tx.user.findUniqueOrThrow({ where: { id: challenge.userId } });
        },
        { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
      );
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2034"
      ) {
        throw new UnauthorizedException(
          "Admin login challenge is invalid or expired",
        );
      }
      throw error;
    }

    otpVerificationsTotal.inc({ outcome: "success" });
    return this.createAuthResponse(updatedUser, true);
  }

  private async validatePasswordCredentials(
    dto: LoginDto,
    requiredRole?: UserRole,
  ): Promise<User> {
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    await this.loginThrottle.assertAllowed(phone);

    const user = await this.prisma.user.findFirst({
      where: { phone: { in: PhoneNormalizer.lookupVariants(phone) } },
    });

    const passwordMatch = await bcryptjs.compare(
      dto.password,
      user?.passwordHash ?? AuthService.dummyPasswordHash,
    );
    if (
      !user ||
      !passwordMatch ||
      user.status === "DISABLED" ||
      (requiredRole !== undefined && user.role !== requiredRole)
    ) {
      await this.loginThrottle.recordFailure(phone);
      throw new UnauthorizedException("Invalid credentials");
    }

    if (!user.phoneVerifiedAt) {
      throw new UnauthorizedException("Phone verification is required");
    }

    await this.loginThrottle.clear(phone);
    return user;
  }

  async refresh(
    dto: RefreshDto,
    requiredRole?: UserRole,
  ): Promise<AuthResponse> {
    const tokenHash = hashRefreshToken(dto.refreshToken);
    const now = new Date();

    const result = await this.prisma.$transaction(async (tx) => {
      const existing = await tx.refreshToken.findUnique({
        where: { tokenHash },
        include: { user: true },
      });
      if (existing?.revokedAt || existing?.replacedById) {
        await tx.refreshToken.updateMany({
          where: { userId: existing.userId, revokedAt: null },
          data: { revokedAt: now },
        });
        return { compromisedRefreshToken: true as const };
      }
      if (
        !existing ||
        existing.expiresAt <= now ||
        existing.user.status === "DISABLED" ||
        !existing.user.phoneVerifiedAt ||
        (requiredRole !== undefined && existing.user.role !== requiredRole)
      ) {
        throw new UnauthorizedException("Session is invalid or expired");
      }

      const nextToken = createRefreshTokenValue();
      const nextExpiresAt = refreshTokenExpiry(now);
      const replacement = await tx.refreshToken.create({
        data: {
          userId: existing.userId,
          tokenHash: hashRefreshToken(nextToken),
          expiresAt: nextExpiresAt,
        },
      });
      const revoked = await tx.refreshToken.updateMany({
        where: { id: existing.id, revokedAt: null, expiresAt: { gt: now } },
        data: { revokedAt: now },
      });
      if (revoked.count !== 1) {
        throw new UnauthorizedException("Session is invalid or expired");
      }
      await tx.refreshToken.update({
        where: { id: existing.id },
        data: { replacedById: replacement.id },
      });

      const adminSessionId =
        requiredRole === UserRole.ADMIN ? replacement.id : undefined;

      return {
        user: toSafeUser(existing.user),
        accessToken: this.signToken(
          existing.user.id,
          existing.user.phone,
          requiredRole === UserRole.ADMIN,
          adminSessionId,
        ),
        refreshToken: nextToken,
        refreshTokenExpiresAt: nextExpiresAt,
      };
    });

    if ("compromisedRefreshToken" in result) {
      throw new UnauthorizedException("Session is invalid or expired");
    }
    return result;
  }

  refreshAdmin(refreshToken: string): Promise<AuthResponse> {
    return this.refresh({ refreshToken }, UserRole.ADMIN);
  }

  async logoutRefreshToken(refreshToken: string): Promise<{ revoked: number }> {
    const result = await this.prisma.refreshToken.updateMany({
      where: {
        tokenHash: hashRefreshToken(refreshToken),
        revokedAt: null,
      },
      data: { revokedAt: new Date() },
    });
    return { revoked: result.count };
  }

  async logout(userId: string, dto: LogoutDto) {
    if (!dto.refreshToken) return this.logoutAll(userId);
    const result = await this.prisma.refreshToken.updateMany({
      where: {
        userId,
        tokenHash: hashRefreshToken(dto.refreshToken),
        revokedAt: null,
      },
      data: { revokedAt: new Date() },
    });
    return { revoked: result.count };
  }

  async logoutAll(userId: string) {
    const result = await this.prisma.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return { revoked: result.count };
  }

  async requestOtp(
    dto: RequestOtpDto,
    context: OtpDispatchContext = {},
  ): Promise<OtpRequestResponse> {
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    const purpose = dto.purpose;
    const mode = this.getOtpMode();
    const channel = this.resolveOtpChannel(mode);

    if (!channel) {
      throw new BadRequestException(AuthService.otpUnavailableMessage);
    }
    if (mode !== "dev") {
      await this.otpDispatchQuota.consume(phone, context);
    }

    const code = channel.generateCode();
    const codeHash = await bcryptjs.hash(code, 10);
    const now = new Date();
    const expiresAt = new Date(
      now.getTime() + this.getOtpExpiryMinutes() * 60 * 1000,
    );

    const otp = await this.replaceActiveOtp({
      phone,
      purpose,
      codeHash,
      expiresAt,
      maxAttempts: this.getOtpMaxAttempts(),
    });

    let delivered;
    try {
      delivered = await channel.deliver(phone, code, purpose);
    } catch {
      await this.prisma.otpCode.updateMany({
        where: { id: otp.id, consumedAt: null },
        data: { consumedAt: new Date() },
      });
      throw new ServiceUnavailableException(AuthService.otpUnavailableMessage);
    }
    otpRequestsTotal.inc({ delivery: delivered.delivery });

    return {
      phone,
      purpose,
      expiresAt,
      delivery: delivered.delivery,
      ...(delivered.echoCode ? { code: delivered.echoCode } : {}),
      ...(delivered.message ? { message: delivered.message } : {}),
    };
  }

  /**
   * dev -> local echo channel; whatsapp -> Meta Cloud API;
   * openwa -> temporary hardened OpenWA transport;
   * disabled -> null (feature off).
   */
  private resolveOtpChannel(mode: string): OtpChannel | null {
    if (mode === "dev") {
      return new DevEchoOtpChannel(this.getDevOtpCode());
    }
    if (mode === "whatsapp") {
      return new WhatsAppOtpChannel();
    }
    if (mode === "openwa") {
      return new OpenWaOtpChannel();
    }
    return null;
  }

  async verifyOtp(dto: VerifyOtpDto): Promise<OtpVerifyResponse> {
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    const code = this.requiredText(dto.code, "code");
    const purpose = dto.purpose;
    const now = new Date();

    if (purpose === OtpPurpose.REGISTER) {
      throw new BadRequestException(
        "Complete registration through POST /auth/register/complete",
      );
    }

    const otp = await this.assertOtpCodeMatches(phone, purpose, code, now);
    await this.consumeOtpRecord(this.prisma, otp, now);
    otpVerificationsTotal.inc({ outcome: "success" });

    const user = await this.handleVerifiedOtp(phone, purpose, now);
    if (purpose === OtpPurpose.LOGIN && !user) {
      throw new BadRequestException("OTP code is invalid or expired");
    }
    if (purpose === OtpPurpose.LOGIN && user?.role === UserRole.ADMIN) {
      throw new UnauthorizedException(
        "Admin accounts must use password and OTP login",
      );
    }
    const auth =
      purpose === OtpPurpose.LOGIN && user
        ? await this.createAuthResponse(user)
        : undefined;

    return {
      verified: true,
      phone,
      purpose,
      ...(user ? { user: toSafeUser(user) } : {}),
      ...(auth
        ? {
            accessToken: auth.accessToken,
            refreshToken: auth.refreshToken,
            refreshTokenExpiresAt: auth.refreshTokenExpiresAt,
          }
        : {}),
    };
  }

  /**
   * Issues a RESET_PASSWORD OTP. Never reveals whether the phone belongs to
   * an account: the OTP is created for any well-formed phone, and only the
   * device holding that phone can complete the reset.
   */
  async requestPasswordReset(
    dto: PasswordResetRequestDto,
    context: OtpDispatchContext = {},
  ): Promise<OtpRequestResponse> {
    return this.requestOtp({
      phone: dto.phone,
      purpose: OtpPurpose.RESET_PASSWORD,
    }, context);
  }

  /**
   * Consumes a RESET_PASSWORD OTP, sets the new password, and revokes every
   * refresh token so stolen sessions die with the old password.
   */
  async confirmPasswordReset(
    dto: PasswordResetConfirmDto,
  ): Promise<{ reset: true; phone: string }> {
    const verification = await this.verifyOtp({
      phone: dto.phone,
      code: dto.code,
      purpose: OtpPurpose.RESET_PASSWORD,
    });

    const user = await this.prisma.user.findFirst({
      where: {
        phone: { in: PhoneNormalizer.lookupVariants(verification.phone) },
      },
    });

    // Same generic error as a wrong code — a consumed OTP on an unknown
    // phone must not disclose account existence.
    if (!user || user.status === "DISABLED") {
      throw new BadRequestException("OTP code is invalid or expired");
    }

    const passwordHash = await bcryptjs.hash(dto.newPassword, 10);
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: user.id },
        data: {
          passwordHash,
          phoneVerifiedAt: user.phoneVerifiedAt ?? new Date(),
        },
      }),
      this.prisma.refreshToken.updateMany({
        where: { userId: user.id, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    ]);

    await this.loginThrottle.clear(verification.phone);

    return { reset: true, phone: verification.phone };
  }

  private async createAuthResponse(
    user: User,
    adminMfa = false,
  ): Promise<AuthResponse> {
    if (user.status === "DISABLED" || !user.phoneVerifiedAt) {
      throw new UnauthorizedException("Phone verification is required");
    }
    const refreshToken = createRefreshTokenValue();
    const refreshTokenExpiresAt = refreshTokenExpiry();
    const refreshSession = await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: hashRefreshToken(refreshToken),
        expiresAt: refreshTokenExpiresAt,
      },
    });
    return {
      user: toSafeUser(user),
      accessToken: this.signToken(
        user.id,
        user.phone,
        adminMfa,
        adminMfa ? refreshSession.id : undefined,
      ),
      refreshToken,
      refreshTokenExpiresAt,
    };
  }

  private signToken(
    userId: string,
    phone: string | null,
    adminMfa = false,
    adminSessionId?: string,
  ): string {
    const payload: JwtPayload = {
      sub: userId,
      phone,
      ...(adminMfa && adminSessionId
        ? { amr: "admin_mfa" as const, sid: adminSessionId }
        : {}),
    };
    return this.jwtService.sign(payload);
  }

  private async handleVerifiedOtp(
    phone: string,
    purpose: OtpPurpose,
    now: Date,
  ): Promise<User | null> {
    const user = await this.prisma.user.findFirst({
      where: { phone: { in: PhoneNormalizer.lookupVariants(phone) } },
    });

    if (purpose === OtpPurpose.LOGIN) {
      if (user?.status === "DISABLED") {
        throw new BadRequestException("OTP code is invalid or expired");
      }

      if (!user) {
        const invite = await this.prisma.planInvite.findFirst({
          where: { normalizedPhone: phone },
        });
        if (!invite) {
          return null;
        }

        const passwordHash = await bcryptjs.hash(
          randomBytes(24).toString("hex"),
          10,
        );
        return this.prisma.user.create({
          data: {
            name: "مشارك أعرست",
            phone,
            passwordHash,
            phoneVerifiedAt: now,
            lastLoginAt: now,
          },
        });
      }

      return this.prisma.user.update({
        where: { id: user.id },
        data: {
          phoneVerifiedAt: user.phoneVerifiedAt ?? now,
          lastLoginAt: now,
        },
      });
    }

    if (
      user &&
      (purpose === OtpPurpose.REGISTER || purpose === OtpPurpose.VERIFY_PHONE)
    ) {
      return this.prisma.user.update({
        where: { id: user.id },
        data: { phoneVerifiedAt: user.phoneVerifiedAt ?? now },
      });
    }

    return user;
  }

  private async recordFailedOtpAttempt(otp: OtpCode, now: Date): Promise<void> {
    const attempts = otp.attempts + 1;
    await this.prisma.otpCode.updateMany({
      where: { id: otp.id, consumedAt: null, expiresAt: { gt: now } },
      data: {
        attempts: { increment: 1 },
        ...(attempts >= otp.maxAttempts ? { consumedAt: now } : {}),
      },
    });
  }

  private async replaceActiveOtp(
    data: Pick<
      Prisma.OtpCodeUncheckedCreateInput,
      "phone" | "purpose" | "codeHash" | "expiresAt" | "maxAttempts"
    >,
  ): Promise<OtpCode> {
    for (let attempt = 0; attempt < 3; attempt++) {
      const now = new Date();
      try {
        return await this.prisma.$transaction(
          async (tx) => {
            await tx.otpCode.updateMany({
              where: {
                phone: data.phone,
                purpose: data.purpose,
                consumedAt: null,
              },
              data: { consumedAt: now },
            });
            return tx.otpCode.create({ data });
          },
          { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
        );
      } catch (error) {
        const retryable =
          error instanceof Prisma.PrismaClientKnownRequestError &&
          (error.code === "P2002" || error.code === "P2034");
        if (!retryable || attempt === 2) {
          throw error;
        }
      }
    }

    throw new ServiceUnavailableException(AuthService.otpUnavailableMessage);
  }

  private async assertOtpCodeMatches(
    phone: string,
    purpose: OtpPurpose,
    code: string,
    now: Date,
  ): Promise<OtpCode> {
    if (this.getOtpMode() !== "dev" && code === this.getDevOtpCode()) {
      otpVerificationsTotal.inc({ outcome: "failure" });
      throw new BadRequestException("OTP code is invalid or expired");
    }

    const otp = await this.prisma.otpCode.findFirst({
      where: { phone, purpose, consumedAt: null },
      orderBy: { createdAt: "desc" },
    });

    if (!otp || otp.expiresAt <= now || otp.attempts >= otp.maxAttempts) {
      if (otp && !otp.consumedAt) {
        await this.prisma.otpCode.updateMany({
          where: { id: otp.id, consumedAt: null },
          data: { consumedAt: now },
        });
      }
      otpVerificationsTotal.inc({ outcome: "failure" });
      throw new BadRequestException("OTP code is invalid or expired");
    }

    const matches = await bcryptjs.compare(code, otp.codeHash);
    if (!matches) {
      await this.recordFailedOtpAttempt(otp, now);
      otpVerificationsTotal.inc({ outcome: "failure" });
      throw new BadRequestException("OTP code is invalid or expired");
    }

    return otp;
  }

  private async consumeOtpRecord(
    client: Pick<Prisma.TransactionClient, "otpCode">,
    otp: OtpCode,
    now: Date,
  ): Promise<void> {
    const consumed = await client.otpCode.updateMany({
      where: {
        id: otp.id,
        consumedAt: null,
        expiresAt: { gt: now },
        attempts: { lt: otp.maxAttempts },
      },
      data: { consumedAt: now },
    });
    if (consumed.count !== 1) {
      otpVerificationsTotal.inc({ outcome: "failure" });
      throw new BadRequestException("OTP code is invalid or expired");
    }
  }

  private getOtpMode(): "dev" | "whatsapp" | "openwa" | "disabled" {
    const configured = (process.env.AUTH_OTP_MODE ?? "").trim().toLowerCase();
    if (configured === "dev") {
      return process.env.NODE_ENV === "production" ? "disabled" : "dev";
    }
    if (
      configured === "whatsapp" ||
      configured === "openwa" ||
      configured === "disabled"
    ) {
      return configured;
    }
    return process.env.NODE_ENV === "production" ? "disabled" : "dev";
  }

  private getDevOtpCode(): string {
    const configured = (process.env.AUTH_DEV_OTP_CODE ?? "").trim();
    if (/^\d{6}$/.test(configured)) return configured;
    return "123456";
  }

  private getOtpExpiryMinutes(): number {
    const configured = Number(process.env.OTP_EXPIRES_MINUTES ?? 5);
    if (!Number.isFinite(configured) || configured < 1) return 5;
    return Math.min(Math.floor(configured), 60);
  }

  private getOtpMaxAttempts(): number {
    const configured = Number(process.env.OTP_MAX_ATTEMPTS ?? 5);
    if (!Number.isFinite(configured) || configured < 1) return 5;
    return Math.min(Math.floor(configured), 10);
  }

  private requiredText(value: string, field: string): string {
    const trimmed = value.trim();
    if (!trimmed) {
      throw new BadRequestException(`${field} must not be empty`);
    }
    return trimmed;
  }
}
