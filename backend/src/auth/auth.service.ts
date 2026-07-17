import {
  BadRequestException,
  HttpStatus,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import {
  AuthSessionScope,
  OtpCode,
  OtpPurpose,
  Prisma,
  User,
  UserRole,
} from "@prisma/client";
import * as bcryptjs from "bcryptjs";
import { randomBytes } from "crypto";
import {
  otpRequestsTotal,
  otpVerificationsTotal,
} from "../common/observability/metrics";
import { PhoneNormalizer } from "../common/phone/phone-normalizer";
import { runSerializableTransaction } from "../common/prisma/serializable-transaction";
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
import { AdminPasswordResetRequestDto } from "./dto/admin-password-reset-request.dto";
import { AdminPasswordResetConfirmDto } from "./dto/admin-password-reset-confirm.dto";
import { JwtPayload } from "./jwt-payload.interface";
import {
  DevEchoOtpChannel,
  OpenWaOtpChannel,
  OtpChannel,
  OtpDeliveryUncertainError,
  WhatsAppOtpChannel,
} from "./otp-channel";
import {
  createOpaqueTokenValue,
  createRefreshTokenValue,
  hashRefreshToken,
  isRefreshTokenForScope,
  refreshTokenExpiry,
  RefreshTokenScope,
} from "./refresh-token-policy";
import { SafeUser, toSafeUser } from "./safe-user";
import {
  LoginThrottleRealm,
  LoginThrottleService,
} from "./login-throttle.service";
import {
  OtpDispatchContext,
  OtpDispatchQuotaService,
} from "./otp-dispatch-quota.service";
import { authError, AuthErrorCode } from "./auth-error";

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

interface IssuedOtpResponse extends OtpRequestResponse {
  otpId: string;
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

export interface AdminPasswordResetPendingResponse {
  accepted: true;
  challengeToken: string;
  expiresAt: Date;
  retryAfterSeconds: number;
}

type RegistrationResult =
  | { auth: AuthResponse }
  | { error: ReturnType<typeof authError> };

type PasswordResetResult =
  | { reset: true }
  | { error: ReturnType<typeof authError> };

@Injectable()
export class AuthService {
  private static readonly otpUnavailableMessage =
    "خدمة التحقق غير مفعلة حاليًا. حاول لاحقًا.";
  private static readonly otpDeliveryUncertainMessage =
    "قد يستغرق وصول الرمز لحظات. إذا وصلك الرمز فأدخله، وإن لم يصل فأعد الإرسال بعد انتهاء المهلة.";
  private static readonly dummyPasswordHash =
    "$2b$10$jnsLrksGKUtGyEjkRk/CeO5zUi9WwfPpG6.bREun6R8yXlN85DEq6";
  private static readonly dummyAdminPasswordHash =
    "$2b$12$PtFtxKzdM6q6s1u/HBnUmetEkF.BeoCfw0XZKNvOBGehCCiWLWw8q";

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

    let result: RegistrationResult;
    try {
      result = await this.prisma.$transaction(
        async (tx) => {
          const existing = await this.findUserByCanonicalPhone(
            tx,
            phone,
            phoneVariants,
          );
          await this.consumeOtpRecord(tx, otp, now);

          if (existing?.status === "DISABLED") {
            return {
              error: authError(
                HttpStatus.FORBIDDEN,
                AuthErrorCode.ACCOUNT_DISABLED_AFTER_PHONE_PROOF,
                "This account is disabled",
              ),
            };
          }

          if (existing?.role === UserRole.ADMIN) {
            if (existing.appPasswordHash) {
              return {
                error: authError(
                  HttpStatus.CONFLICT,
                  AuthErrorCode.ADMIN_APP_PASSWORD_ALREADY_SET,
                  "The application password is already configured",
                ),
              };
            }
            const claimed = await tx.user.updateMany({
              where: {
                id: existing.id,
                role: UserRole.ADMIN,
                status: "ACTIVE",
                appPasswordHash: null,
              },
              data: {
                appPasswordHash: passwordHash,
                appName: dto.name,
                appEmail: null,
                appAvatarUrl: null,
                phone,
                phoneVerifiedAt: existing.phoneVerifiedAt ?? now,
                lastLoginAt: now,
              },
            });
            if (claimed.count !== 1) {
              return {
                error: authError(
                  HttpStatus.CONFLICT,
                  AuthErrorCode.ADMIN_APP_PASSWORD_ALREADY_SET,
                  "The application password is already configured",
                ),
              };
            }
            const user = await tx.user.findUniqueOrThrow({
              where: { id: existing.id },
            });
            return { auth: await this.createAuthResponse(user, false, tx) };
          }

          if (existing) {
            if (existing.phoneVerifiedAt) {
              return {
                error: authError(
                  HttpStatus.CONFLICT,
                  AuthErrorCode.ACCOUNT_ALREADY_EXISTS,
                  "An account already exists for this phone",
                ),
              };
            }
            const claimed = await tx.user.updateMany({
              where: {
                id: existing.id,
                role: { in: [UserRole.USER, UserRole.PROVIDER] },
                status: "ACTIVE",
                phoneVerifiedAt: null,
              },
              data: {
                name: dto.name,
                phone,
                passwordHash,
                phoneVerifiedAt: now,
                lastLoginAt: now,
              },
            });
            if (claimed.count !== 1) {
              return {
                error: authError(
                  HttpStatus.CONFLICT,
                  AuthErrorCode.ACCOUNT_ALREADY_EXISTS,
                  "An account already exists for this phone",
                ),
              };
            }
            const user = await tx.user.findUniqueOrThrow({
              where: { id: existing.id },
            });
            return { auth: await this.createAuthResponse(user, false, tx) };
          }

          const user = await tx.user.create({
            data: {
              name: dto.name,
              phone,
              email: null,
              passwordHash,
              phoneVerifiedAt: now,
              lastLoginAt: now,
            },
          });
          return { auth: await this.createAuthResponse(user, false, tx) };
        },
        { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
      );
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2034"
      ) {
        otpVerificationsTotal.inc({ outcome: "failure" });
        throw authError(
          HttpStatus.BAD_REQUEST,
          AuthErrorCode.OTP_INVALID_OR_EXPIRED,
          "OTP code is invalid or expired",
        );
      }
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2002"
      ) {
        throw authError(
          HttpStatus.CONFLICT,
          AuthErrorCode.ACCOUNT_ALREADY_EXISTS,
          "An account already exists for this phone",
        );
      }
      throw error;
    }

    otpVerificationsTotal.inc({ outcome: "success" });
    if ("error" in result) throw result.error;
    return result.auth;
  }

  async login(dto: LoginDto): Promise<AuthResponse> {
    const user = await this.validatePasswordCredentials(dto);
    return this.prisma.$transaction(async (tx) => {
      const updatedUser = await tx.user.update({
        where: { id: user.id },
        data: { lastLoginAt: new Date() },
      });
      return this.createAuthResponse(updatedUser, false, tx);
    });
  }

  async startAdminLogin(
    dto: LoginDto,
    context: OtpDispatchContext = {},
  ): Promise<AdminLoginPendingResponse> {
    // The OTP completed below is itself proof that the administrator controls
    // the configured phone. This keeps pre-MFA/bootstrap administrators from
    // being permanently locked out while still requiring both their password
    // and the out-of-band code before a session can be issued.
    const user = await this.validatePasswordCredentials(dto, UserRole.ADMIN, {
      allowUnverifiedPhone: true,
    });
    const otp = await this.issueOtp(
      user.phone!,
      OtpPurpose.ADMIN_LOGIN,
      context,
    );
    const challengeToken = createOpaqueTokenValue();
    const now = new Date();
    const expiresAt = new Date(
      Math.min(otp.expiresAt.getTime(), now.getTime() + 10 * 60_000),
    );

    await runSerializableTransaction(this.prisma, async (tx) => {
      const issuedOtp = await tx.otpCode.findUniqueOrThrow({
        where: { id: otp.otpId },
        select: { consumedAt: true },
      });
      const superseded = issuedOtp.consumedAt !== null;
      if (!superseded) {
        await tx.adminLoginChallenge.updateMany({
          where: { userId: user.id, consumedAt: null },
          data: { consumedAt: now },
        });
      }
      await tx.adminLoginChallenge.create({
        data: {
          userId: user.id,
          otpId: otp.otpId,
          tokenHash: hashRefreshToken(challengeToken),
          expiresAt,
          ...(superseded ? { consumedAt: now } : {}),
        },
      });
    });

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
      include: { user: true, otp: true },
    });
    if (
      !challenge ||
      challenge.consumedAt ||
      challenge.expiresAt <= now ||
      challenge.user.role !== UserRole.ADMIN ||
      challenge.user.status === "DISABLED" ||
      !challenge.user.phone
    ) {
      throw new UnauthorizedException(
        "Admin login challenge is invalid or expired",
      );
    }

    const otp = await this.assertSpecificOtpCodeMatches(
      challenge.otp,
      challenge.user.phone,
      OtpPurpose.ADMIN_LOGIN,
      code,
      now,
    );

    let auth: AuthResponse;
    try {
      auth = await this.prisma.$transaction(
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
            },
            data: {
              lastLoginAt: now,
              phoneVerifiedAt: challenge.user.phoneVerifiedAt ?? now,
            },
          });
          if (eligible.count !== 1) {
            throw new UnauthorizedException("Admin access is required");
          }
          const updatedUser = await tx.user.findUniqueOrThrow({
            where: { id: challenge.userId },
          });
          return this.createAuthResponse(updatedUser, true, tx);
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
    return auth;
  }

  private async validatePasswordCredentials(
    dto: LoginDto,
    requiredRole?: UserRole,
    options: { allowUnverifiedPhone?: boolean } = {},
  ): Promise<User> {
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    const realm: LoginThrottleRealm =
      requiredRole === UserRole.ADMIN ? "admin" : "application";
    await this.loginThrottle.assertAllowed(phone, realm);

    // Prefer the canonical normalized row before consulting legacy variants.
    // A pre-normalization database may still contain both `7xxxxxxxx` and
    // `+9677xxxxxxxx`; one unordered `IN` query can otherwise authenticate
    // against an arbitrary duplicate and reject the correct password.
    const user =
      (await this.prisma.user.findFirst({ where: { phone } })) ??
      (await this.prisma.user.findFirst({
        where: { phone: { in: PhoneNormalizer.lookupVariants(phone) } },
      }));

    const credentialHash =
      requiredRole === UserRole.ADMIN
        ? user?.passwordHash
        : user?.role === UserRole.ADMIN
          ? user.appPasswordHash
          : user?.passwordHash;
    const passwordMatch = await bcryptjs.compare(
      dto.password,
      credentialHash ??
        (realm === "admin"
          ? AuthService.dummyAdminPasswordHash
          : AuthService.dummyPasswordHash),
    );
    if (
      !user ||
      !passwordMatch ||
      user.status === "DISABLED" ||
      (requiredRole !== undefined && user.role !== requiredRole)
    ) {
      await this.loginThrottle.recordFailure(phone, realm);
      throw authError(
        HttpStatus.UNAUTHORIZED,
        AuthErrorCode.INVALID_CREDENTIALS,
        "Invalid credentials",
      );
    }

    if (!user.phoneVerifiedAt && !options.allowUnverifiedPhone) {
      throw authError(
        HttpStatus.UNAUTHORIZED,
        AuthErrorCode.PHONE_VERIFICATION_REQUIRED,
        "Phone verification is required",
      );
    }

    if (
      realm === "admin" &&
      credentialHash &&
      bcryptjs.getRounds(credentialHash) < 12
    ) {
      await this.prisma.user.update({
        where: { id: user.id },
        data: { passwordHash: await bcryptjs.hash(dto.password, 12) },
      });
    }

    await this.loginThrottle.clear(phone, realm);
    return user;
  }

  async refresh(
    dto: RefreshDto,
    requiredRole?: UserRole,
  ): Promise<AuthResponse> {
    const refreshScope: RefreshTokenScope =
      requiredRole === UserRole.ADMIN ? "admin" : "application";
    const sessionScope =
      requiredRole === UserRole.ADMIN
        ? AuthSessionScope.ADMIN
        : AuthSessionScope.APPLICATION;
    if (!isRefreshTokenForScope(dto.refreshToken, refreshScope)) {
      throw new UnauthorizedException("Session is invalid or expired");
    }
    const tokenHash = hashRefreshToken(dto.refreshToken);
    const now = new Date();

    const result = await this.prisma.$transaction(async (tx) => {
      const existing = await tx.refreshToken.findUnique({
        where: { tokenHash },
        include: { user: true },
      });
      if (existing?.revokedAt || existing?.replacedById) {
        await tx.refreshToken.updateMany({
          where: {
            userId: existing.userId,
            scope: existing.scope,
            revokedAt: null,
          },
          data: { revokedAt: now },
        });
        return { compromisedRefreshToken: true as const };
      }
      if (
        !existing ||
        existing.expiresAt <= now ||
        existing.scope !== sessionScope ||
        existing.user.status === "DISABLED" ||
        !existing.user.phoneVerifiedAt ||
        (requiredRole !== undefined && existing.user.role !== requiredRole)
      ) {
        throw new UnauthorizedException("Session is invalid or expired");
      }

      const nextToken = createRefreshTokenValue(refreshScope);
      const nextExpiresAt = refreshTokenExpiry(now);
      const replacement = await tx.refreshToken.create({
        data: {
          userId: existing.userId,
          tokenHash: hashRefreshToken(nextToken),
          scope: sessionScope,
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
        user: toSafeUser(
          existing.user,
          requiredRole === UserRole.ADMIN,
        ),
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
        scope: AuthSessionScope.APPLICATION,
        tokenHash: hashRefreshToken(dto.refreshToken),
        revokedAt: null,
      },
      data: { revokedAt: new Date() },
    });
    return { revoked: result.count };
  }

  async logoutAll(
    userId: string,
    scope: AuthSessionScope = AuthSessionScope.APPLICATION,
  ) {
    const result = await this.prisma.refreshToken.updateMany({
      where: { userId, scope, revokedAt: null },
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
    if (
      purpose === OtpPurpose.ADMIN_LOGIN ||
      purpose === OtpPurpose.ADMIN_RESET_PASSWORD
    ) {
      throw new BadRequestException("Unsupported OTP purpose");
    }
    const { otpId: _otpId, ...response } = await this.issueOtp(
      phone,
      purpose,
      context,
    );
    return response;
  }

  private async issueOtp(
    phone: string,
    purpose: OtpPurpose,
    context: OtpDispatchContext = {},
    quotaAlreadyConsumed = false,
  ): Promise<IssuedOtpResponse> {
    const mode = this.getOtpMode();
    const channel = this.resolveOtpChannel(mode);

    if (!channel) {
      throw new BadRequestException(AuthService.otpUnavailableMessage);
    }
    if (mode !== "dev" && !quotaAlreadyConsumed) {
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
    } catch (error) {
      if (error instanceof OtpDeliveryUncertainError) {
        delivered = {
          delivery: "WHATSAPP" as const,
          message: AuthService.otpDeliveryUncertainMessage,
        };
      } else {
        await this.prisma.otpCode.updateMany({
          where: { id: otp.id, consumedAt: null },
          data: { consumedAt: new Date() },
        });
        throw new ServiceUnavailableException(AuthService.otpUnavailableMessage);
      }
    }
    otpRequestsTotal.inc({ delivery: delivered.delivery });

    return {
      otpId: otp.id,
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

    if (
      purpose === OtpPurpose.REGISTER ||
      purpose === OtpPurpose.RESET_PASSWORD ||
      purpose === OtpPurpose.ADMIN_RESET_PASSWORD
    ) {
      throw new BadRequestException(
        "Complete registration through POST /auth/register/complete",
      );
    }

    const otp = await this.assertOtpCodeMatches(phone, purpose, code, now);
    const result = await this.prisma
      .$transaction(
        async (tx) => {
        await this.consumeOtpRecord(tx, otp, now);
        let user = await this.findUserByCanonicalPhone(tx, phone);

        if (user?.status === "DISABLED") {
          return { error: this.otpInvalid() };
        }

        if (
          user?.role === UserRole.ADMIN &&
          purpose === OtpPurpose.LOGIN &&
          !user.appPasswordHash
        ) {
          return {
            error: authError(
              HttpStatus.NOT_FOUND,
              AuthErrorCode.ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF,
              "No application account exists for this verified phone",
            ),
          };
        }

        if (!user && purpose === OtpPurpose.LOGIN) {
          const invite = await tx.planInvite.findFirst({
            where: {
              normalizedPhone: phone,
              acceptedAt: null,
              declinedAt: null,
              revokedAt: null,
              expiresAt: { gt: now },
            },
          });
          if (!invite) {
            return {
              error: authError(
                HttpStatus.NOT_FOUND,
                AuthErrorCode.ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF,
                "No account exists for this verified phone",
              ),
            };
          }
          user = await tx.user.create({
            data: {
              name: "مشارك أعرست",
              phone,
              passwordHash: await bcryptjs.hash(
                randomBytes(24).toString("hex"),
                10,
              ),
              phoneVerifiedAt: now,
              lastLoginAt: now,
            },
          });
        } else if (user) {
          user = await tx.user.update({
            where: { id: user.id },
            data: {
              phoneVerifiedAt: user.phoneVerifiedAt ?? now,
              ...(purpose === OtpPurpose.LOGIN ? { lastLoginAt: now } : {}),
            },
          });
        }

        if (!user) {
          return {
            error: authError(
              HttpStatus.NOT_FOUND,
              AuthErrorCode.ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF,
              "No account exists for this verified phone",
            ),
          };
        }

        return {
          user,
          auth:
            purpose === OtpPurpose.LOGIN
              ? await this.createAuthResponse(user, false, tx)
              : undefined,
        };
        },
        { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
      )
      .catch((error: unknown) => {
        if (
          error instanceof Prisma.PrismaClientKnownRequestError &&
          error.code === "P2034"
        ) {
          otpVerificationsTotal.inc({ outcome: "failure" });
          throw this.otpInvalid();
        }
        throw error;
      });
    otpVerificationsTotal.inc({ outcome: "success" });
    if ("error" in result) throw result.error;
    const { user, auth } = result;

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
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    const now = new Date();
    const otp = await this.assertOtpCodeMatches(
      phone,
      OtpPurpose.RESET_PASSWORD,
      dto.code,
      now,
    );

    const passwordHash = await bcryptjs.hash(dto.newPassword, 10);
    const result: PasswordResetResult = await this.prisma.$transaction(
      async (tx) => {
        const user = await this.findUserByCanonicalPhone(
          tx,
          phone,
          PhoneNormalizer.lookupVariants(phone),
        );
        await this.consumeOtpRecord(tx, otp, now);
        if (!user) {
          return {
            error: authError(
              HttpStatus.NOT_FOUND,
              AuthErrorCode.ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF,
              "No application account exists for this verified phone",
            ),
          };
        }
        if (user.status === "DISABLED") {
          return {
            error: authError(
              HttpStatus.FORBIDDEN,
              AuthErrorCode.ACCOUNT_DISABLED_AFTER_PHONE_PROOF,
              "This account is disabled",
            ),
          };
        }
        if (user.role === UserRole.ADMIN && !user.appPasswordHash) {
          return {
            error: authError(
              HttpStatus.NOT_FOUND,
              AuthErrorCode.ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF,
              "No application account exists for this verified phone",
            ),
          };
        }

        await tx.user.update({
          where: { id: user.id },
          data: {
            ...(user.role === UserRole.ADMIN
              ? { appPasswordHash: passwordHash }
              : { passwordHash }),
            phoneVerifiedAt: user.phoneVerifiedAt ?? now,
          },
        });
        await tx.refreshToken.updateMany({
          where: {
            userId: user.id,
            scope: AuthSessionScope.APPLICATION,
            revokedAt: null,
          },
          data: { revokedAt: now },
        });
        return { reset: true as const };
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
    );

    otpVerificationsTotal.inc({ outcome: "success" });
    if ("error" in result) throw result.error;
    await this.loginThrottle.clear(phone, "application");
    return { reset: true, phone };
  }

  async requestAdminPasswordReset(
    dto: AdminPasswordResetRequestDto,
    context: OtpDispatchContext = {},
  ): Promise<AdminPasswordResetPendingResponse> {
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    const mode = this.getOtpMode();
    if (!this.resolveOtpChannel(mode)) {
      throw new BadRequestException(AuthService.otpUnavailableMessage);
    }
    if (mode !== "dev") {
      await this.otpDispatchQuota.consume(phone, context);
    }

    const challengeToken = randomBytes(32).toString("hex");
    const subjectHash = LoginThrottleService.subjectHash(phone, "admin");
    const candidate = await this.findUserByCanonicalPhone(
      this.prisma,
      phone,
      PhoneNormalizer.lookupVariants(phone),
    );
    const admin =
      candidate?.role === UserRole.ADMIN && candidate.status === "ACTIVE"
        ? candidate
        : null;

    // Send the same OTP flow for every well-formed phone. This keeps status,
    // body, bcrypt work and transport timing independent of account existence.
    const issued = await this.issueOtp(
      phone,
      OtpPurpose.ADMIN_RESET_PASSWORD,
      context,
      mode !== "dev",
    );
    const now = new Date();
    const expiresAt = new Date(
      Math.min(issued.expiresAt.getTime(), now.getTime() + 10 * 60_000),
    );

    await runSerializableTransaction(this.prisma, async (tx) => {
      const issuedOtp = await tx.otpCode.findUniqueOrThrow({
        where: { id: issued.otpId },
        select: { consumedAt: true },
      });
      const superseded = issuedOtp.consumedAt !== null;
      if (!superseded) {
        await tx.adminPasswordResetChallenge.updateMany({
          where: { subjectHash, consumedAt: null },
          data: { consumedAt: now },
        });
      }
      await tx.adminPasswordResetChallenge.create({
        data: {
          userId: admin?.id ?? null,
          otpId: issued.otpId,
          tokenHash: hashRefreshToken(challengeToken),
          subjectHash,
          expiresAt,
          ...(superseded ? { consumedAt: now } : {}),
        },
      });
    });

    return {
      accepted: true,
      challengeToken,
      expiresAt,
      retryAfterSeconds: 60,
    };
  }

  async confirmAdminPasswordReset(
    dto: AdminPasswordResetConfirmDto,
  ): Promise<{ reset: true }> {
    const now = new Date();
    const challenge =
      await this.prisma.adminPasswordResetChallenge.findUnique({
        where: { tokenHash: hashRefreshToken(dto.challengeToken) },
        include: { user: true, otp: true },
      });
    if (
      !challenge ||
      challenge.consumedAt ||
      challenge.expiresAt <= now ||
      challenge.attempts >= challenge.maxAttempts
    ) {
      await bcryptjs.compare(dto.code, AuthService.dummyPasswordHash);
      if (challenge && !challenge.consumedAt) {
        await this.recordFailedAdminResetAttempt(challenge.id, now);
      }
      throw this.adminResetInvalid();
    }

    let otp: OtpCode;
    try {
      otp = await this.assertSpecificOtpCodeMatches(
        challenge.otp,
        challenge.otp.phone,
        OtpPurpose.ADMIN_RESET_PASSWORD,
        dto.code,
        now,
      );
    } catch {
      await this.recordFailedAdminResetAttempt(challenge.id, now);
      throw this.adminResetInvalid();
    }

    const eligibleAdmin =
      challenge.user?.role === UserRole.ADMIN &&
      challenge.user.status === "ACTIVE" &&
      challenge.user.phone === challenge.otp.phone;
    if (!eligibleAdmin) {
      await this.prisma.$transaction(async (tx) => {
        await tx.adminPasswordResetChallenge.updateMany({
          where: { id: challenge.id, consumedAt: null },
          data: { consumedAt: now },
        });
        await this.consumeOtpRecord(tx, otp, now);
      });
      throw this.adminResetInvalid();
    }
    const passwordHash = await bcryptjs.hash(dto.newPassword, 12);

    try {
      await this.prisma.$transaction(
        async (tx) => {
          const claimed = await tx.adminPasswordResetChallenge.updateMany({
            where: {
              id: challenge.id,
              consumedAt: null,
              expiresAt: { gt: now },
              attempts: { lt: challenge.maxAttempts },
            },
            data: { consumedAt: now },
          });
          if (claimed.count !== 1) throw this.adminResetInvalid();
          await this.consumeOtpRecord(tx, otp, now);

          const updated = await tx.user.updateMany({
            where: {
              id: challenge.userId!,
              role: UserRole.ADMIN,
              status: "ACTIVE",
            },
            data: { passwordHash },
          });
          if (updated.count !== 1) throw this.adminResetInvalid();

          await tx.refreshToken.updateMany({
            where: {
              userId: challenge.userId!,
              scope: AuthSessionScope.ADMIN,
              revokedAt: null,
            },
            data: { revokedAt: now },
          });
          await tx.adminLoginChallenge.updateMany({
            where: { userId: challenge.userId!, consumedAt: null },
            data: { consumedAt: now },
          });
          await tx.adminPasswordResetChallenge.updateMany({
            where: { userId: challenge.userId!, consumedAt: null },
            data: { consumedAt: now },
          });
          await tx.otpCode.updateMany({
            where: {
              phone: challenge.user!.phone!,
              purpose: {
                in: [
                  OtpPurpose.ADMIN_LOGIN,
                  OtpPurpose.ADMIN_RESET_PASSWORD,
                ],
              },
              consumedAt: null,
            },
            data: { consumedAt: now },
          });
          await tx.loginThrottle.deleteMany({
            where: { subjectHash: challenge.subjectHash },
          });
        },
        { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
      );
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2034"
      ) {
        throw this.adminResetInvalid();
      }
      throw error;
    }
    otpVerificationsTotal.inc({ outcome: "success" });
    return { reset: true };
  }

  private async createAuthResponse(
    user: User,
    adminMfa = false,
    client: Pick<Prisma.TransactionClient, "refreshToken"> = this.prisma,
  ): Promise<AuthResponse> {
    if (user.status === "DISABLED" || !user.phoneVerifiedAt) {
      throw authError(
        HttpStatus.UNAUTHORIZED,
        AuthErrorCode.PHONE_VERIFICATION_REQUIRED,
        "Phone verification is required",
      );
    }
    const refreshToken = createRefreshTokenValue(
      adminMfa ? "admin" : "application",
    );
    const refreshTokenExpiresAt = refreshTokenExpiry();
    const refreshSession = await client.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: hashRefreshToken(refreshToken),
        scope: adminMfa
          ? AuthSessionScope.ADMIN
          : AuthSessionScope.APPLICATION,
        expiresAt: refreshTokenExpiresAt,
      },
    });
    return {
      user: toSafeUser(user, adminMfa),
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

  private async findUserByCanonicalPhone(
    client: Pick<Prisma.TransactionClient, "user">,
    phone: string,
    variants = PhoneNormalizer.lookupVariants(phone),
  ): Promise<User | null> {
    return (
      (await client.user.findFirst({ where: { phone } })) ??
      (await client.user.findFirst({ where: { phone: { in: variants } } }))
    );
  }

  private otpInvalid() {
    return authError(
      HttpStatus.BAD_REQUEST,
      AuthErrorCode.OTP_INVALID_OR_EXPIRED,
      "OTP code is invalid or expired",
    );
  }

  private adminResetInvalid() {
    return authError(
      HttpStatus.BAD_REQUEST,
      AuthErrorCode.ADMIN_RESET_INVALID_OR_EXPIRED,
      "Admin password reset is invalid or expired",
    );
  }

  private async recordFailedAdminResetAttempt(
    challengeId: string,
    now: Date,
  ): Promise<void> {
    await this.prisma.adminPasswordResetChallenge.updateMany({
      where: { id: challengeId, consumedAt: null, attempts: { lt: 5 } },
      data: { attempts: { increment: 1 } },
    });
    await this.prisma.adminPasswordResetChallenge.updateMany({
      where: { id: challengeId, consumedAt: null, attempts: { gte: 5 } },
      data: { consumedAt: now },
    });
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
    const otp = await this.prisma.otpCode.findFirst({
      where: { phone, purpose, consumedAt: null },
      orderBy: { createdAt: "desc" },
    });

    return this.assertSpecificOtpCodeMatches(
      otp,
      phone,
      purpose,
      code,
      now,
    );
  }

  private async assertSpecificOtpCodeMatches(
    otp: OtpCode | null | undefined,
    phone: string,
    purpose: OtpPurpose,
    code: string,
    now: Date,
  ): Promise<OtpCode> {
    if (this.getOtpMode() !== "dev" && code === this.getDevOtpCode()) {
      otpVerificationsTotal.inc({ outcome: "failure" });
      throw this.otpInvalid();
    }
    if (
      !otp ||
      otp.phone !== phone ||
      otp.purpose !== purpose ||
      otp.consumedAt ||
      otp.expiresAt <= now ||
      otp.attempts >= otp.maxAttempts
    ) {
      if (otp && !otp.consumedAt) {
        await this.prisma.otpCode.updateMany({
          where: { id: otp.id, consumedAt: null },
          data: { consumedAt: now },
        });
      }
      otpVerificationsTotal.inc({ outcome: "failure" });
      throw this.otpInvalid();
    }

    const matches = await bcryptjs.compare(code, otp.codeHash);
    if (!matches) {
      await this.recordFailedOtpAttempt(otp, now);
      otpVerificationsTotal.inc({ outcome: "failure" });
      throw this.otpInvalid();
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
      throw this.otpInvalid();
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
