import {
  BadRequestException,
  HttpStatus,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { ConversationRealtimePublisher } from "../conversations/conversation-realtime.publisher";
import {
  AuthSessionScope,
  OtpCode,
  OtpPurpose,
  Prisma,
  User,
  UserRole,
} from "@prisma/client";
import * as bcryptjs from "bcryptjs";
import { createHash, randomBytes } from "crypto";
import {
  otpDeliveryOutcomesTotal,
  otpRequestsTotal,
  otpVerificationsTotal,
} from "../platform/observability/metrics";
import { PhoneNormalizer } from "../common/phone/phone-normalizer";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import { PrismaService } from "../platform/database/prisma.service";
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
import {
  authError,
  AuthErrorCode,
  otpDeliveryUnavailableError,
} from "./auth-error";
import {
  lockUserLifecycleRowsForUpdateInTransaction,
} from "../users/user-lifecycle-lock";
import {
  enqueueSessionRevoked,
  enqueueUserSessionsRevoked,
} from "../outbox/realtime-revocation";

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
  deliveryStatus: "LOCAL_DEV" | "DELIVERED" | "PENDING" | "UNCERTAIN";
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

export interface InviteOtpVerifyInput {
  token: string;
  phone: string;
  code: string;
  name?: string;
  password?: string;
}

export interface AdminLoginPendingResponse {
  mfaRequired: true;
  challengeToken: string;
  expiresAt: Date;
  delivery: "LOCAL_DEV" | "WHATSAPP";
  deliveryStatus: "LOCAL_DEV" | "DELIVERED" | "PENDING" | "UNCERTAIN";
  code?: string;
}

export interface AdminPasswordResetPendingResponse {
  accepted: true;
  challengeToken: string;
  expiresAt: Date;
  retryAfterSeconds: number;
  deliveryStatus: "LOCAL_DEV" | "DELIVERED" | "PENDING" | "UNCERTAIN";
}

type RegistrationResult =
  | { auth: AuthResponse }
  | { error: ReturnType<typeof authError> }
  | { otpInvalid: true };

type PasswordResetResult =
  | { reset: true; userId: string }
  | { error: ReturnType<typeof authError> }
  | { otpInvalid: true };

type InviteOtpVerificationResult =
  | { auth: AuthResponse }
  | { error: ReturnType<typeof authError> }
  | { otpInvalid: true };

type OtpClaimResult =
  | { outcome: "verified"; otp: OtpCode }
  | { outcome: "invalid" };

interface LockedRefreshTokenRow {
  id: string;
  userId: string;
  scope: AuthSessionScope;
  expiresAt: Date;
  revokedAt: Date | null;
  replacedById: string | null;
}

interface LockedRefreshTokenFamily {
  rows: LockedRefreshTokenRow[];
  complete: boolean;
}

interface LockedRefreshTokenTraversalRow extends LockedRefreshTokenRow {
  depth: number;
}

@Injectable()
export class AuthService {
  private static readonly maxRefreshFamilyDepth = 4_096;
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
    private readonly otpDispatchQuota: OtpDispatchQuotaService,
    private readonly realtime: ConversationRealtimePublisher,
  ) {}

  async startRegistration(
    dto: RegisterDto,
    context: OtpDispatchContext = {},
  ): Promise<RegistrationPendingResponse> {
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    const otp = await this.requestOtp(
      {
        phone,
        purpose: OtpPurpose.REGISTER,
      },
      context,
    );
    return { registrationPending: true, ...otp };
  }

  async completeRegistration(
    dto: CompleteRegistrationDto,
  ): Promise<AuthResponse> {
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    const phoneVariants = PhoneNormalizer.lookupVariants(phone);
    const now = new Date();
    const passwordHash = await bcryptjs.hash(dto.password, 10);

    let result: RegistrationResult;
    try {
      result = await runSerializableTransaction(
        this.prisma,
        async (tx) => {
          const otpClaim = await this.claimOtpCodeInTransaction(tx, {
            phone,
            purpose: OtpPurpose.REGISTER,
            code: dto.otpCode,
            now,
          });
          if (otpClaim.outcome === "invalid") {
            return { otpInvalid: true as const };
          }
          let existing = await this.findUserByCanonicalPhone(
            tx,
            phone,
            phoneVariants,
          );
          if (existing) {
            await lockUserLifecycleRowsForUpdateInTransaction(tx, [
              existing.id,
            ]);
            existing = await tx.user.findUnique({
              where: { id: existing.id },
            });
          }

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
                appPasswordConfiguredAt: now,
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
                appPasswordConfiguredAt: now,
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
              appPasswordConfiguredAt: now,
              phoneVerifiedAt: now,
              lastLoginAt: now,
            },
          });
          return { auth: await this.createAuthResponse(user, false, tx) };
        },
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

    if ("otpInvalid" in result) {
      otpVerificationsTotal.inc({ outcome: "failure" });
      throw this.otpInvalid();
    }
    if ("error" in result) {
      // The code was proven and consumed, but the account outcome was
      // rejected (already exists / disabled / no app account). This is a
      // distinct signal from a genuine end-to-end success.
      otpVerificationsTotal.inc({ outcome: "verified_then_rejected" });
      throw result.error;
    }
    otpVerificationsTotal.inc({ outcome: "success" });
    return result.auth;
  }

  async login(dto: LoginDto): Promise<AuthResponse> {
    const user = await this.validatePasswordCredentials(dto);
    return runSerializableTransaction(this.prisma, async (tx) => {
      const credentialIdentity =
        user.role === UserRole.ADMIN
          ? { appPasswordHash: user.appPasswordHash! }
          : { passwordHash: user.passwordHash! };
      const loginAt = new Date();
      const eligible = await tx.user.updateMany({
        where: {
          id: user.id,
          phone: user.phone,
          role: user.role,
          status: "ACTIVE",
          phoneVerifiedAt: { not: null },
          appPasswordConfiguredAt: { not: null },
          ...credentialIdentity,
        },
        data: { lastLoginAt: loginAt },
      });
      if (eligible.count !== 1) {
        throw authError(
          HttpStatus.UNAUTHORIZED,
          AuthErrorCode.INVALID_CREDENTIALS,
          "Invalid credentials",
        );
      }
      const updatedUser = await tx.user.findUniqueOrThrow({
        where: { id: user.id },
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
      const lifecycleUsers =
        await lockUserLifecycleRowsForUpdateInTransaction(tx, [user.id]);
      await this.lockAdminLoginChallengesInTransaction(tx, user.id);
      const currentUser = await tx.user.findUnique({
        where: { id: user.id },
      });
      if (
        lifecycleUsers[0]?.status !== "ACTIVE" ||
        !currentUser ||
        currentUser.role !== UserRole.ADMIN ||
        currentUser.phone !== user.phone ||
        currentUser.passwordHash !== user.passwordHash
      ) {
        throw authError(
          HttpStatus.UNAUTHORIZED,
          AuthErrorCode.INVALID_CREDENTIALS,
          "Invalid credentials",
        );
      }
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
      deliveryStatus: otp.deliveryStatus,
      ...(otp.code ? { code: otp.code } : {}),
    };
  }

  async completeAdminLogin(
    challengeToken: string,
    code: string,
  ): Promise<AuthResponse> {
    const now = new Date();
    const challengeSeed = await this.prisma.adminLoginChallenge.findUnique({
      where: { tokenHash: hashRefreshToken(challengeToken) },
      select: { id: true, userId: true },
    });
    if (!challengeSeed) {
      throw new UnauthorizedException(
        "Admin login challenge is invalid or expired",
      );
    }

    try {
      const result = await runSerializableTransaction(
        this.prisma,
        async (tx) => {
          await lockUserLifecycleRowsForUpdateInTransaction(tx, [
            challengeSeed.userId,
          ]);
          await this.lockAdminLoginChallengesInTransaction(
            tx,
            challengeSeed.userId,
          );
          const challenge = await tx.adminLoginChallenge.findUnique({
            where: { id: challengeSeed.id },
            include: { user: true, otp: true },
          });
          if (
            !challenge ||
            challenge.userId !== challengeSeed.userId ||
            challenge.consumedAt ||
            challenge.expiresAt <= now ||
            challenge.user.role !== UserRole.ADMIN ||
            challenge.user.status === "DISABLED" ||
            !challenge.user.phone
          ) {
            return { challengeInvalid: true as const };
          }

          const otpClaim = await this.claimOtpCodeInTransaction(tx, {
            otpId: challenge.otpId,
            phone: challenge.user.phone,
            purpose: OtpPurpose.ADMIN_LOGIN,
            code,
            now,
          });
          if (otpClaim.outcome === "invalid") {
            return { otpInvalid: true as const };
          }

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
          return {
            auth: await this.createAuthResponse(updatedUser, true, tx),
          };
        },
      );
      if ("challengeInvalid" in result) {
        throw new UnauthorizedException(
          "Admin login challenge is invalid or expired",
        );
      }
      if ("otpInvalid" in result) {
        otpVerificationsTotal.inc({ outcome: "failure" });
        throw this.otpInvalid();
      }
      otpVerificationsTotal.inc({ outcome: "success" });
      return result.auth;
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
  }

  private async validatePasswordCredentials(
    dto: LoginDto,
    requiredRole?: UserRole,
    options: { allowUnverifiedPhone?: boolean } = {},
  ): Promise<User> {
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    const realm: LoginThrottleRealm =
      requiredRole === UserRole.ADMIN ? "admin" : "application";
    await this.loginThrottle.reserveAttempt(phone, realm);

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
      (realm === "application" && !user.appPasswordConfiguredAt) ||
      (requiredRole !== undefined && user.role !== requiredRole)
    ) {
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

    let validatedUser = user;
    if (
      realm === "admin" &&
      credentialHash &&
      bcryptjs.getRounds(credentialHash) < 12
    ) {
      const upgradedPasswordHash = await bcryptjs.hash(dto.password, 12);
      const upgraded = await this.prisma.user.updateMany({
        where: {
          id: user.id,
          passwordHash: credentialHash,
          role: UserRole.ADMIN,
          status: "ACTIVE",
        },
        data: { passwordHash: upgradedPasswordHash },
      });
      if (upgraded.count !== 1) {
        throw authError(
          HttpStatus.UNAUTHORIZED,
          AuthErrorCode.INVALID_CREDENTIALS,
          "Invalid credentials",
        );
      }
      const current = await this.prisma.user.findUnique({
        where: { id: user.id },
      });
      if (
        !current ||
        current.passwordHash !== upgradedPasswordHash ||
        current.role !== UserRole.ADMIN ||
        current.status !== "ACTIVE"
      ) {
        throw authError(
          HttpStatus.UNAUTHORIZED,
          AuthErrorCode.INVALID_CREDENTIALS,
          "Invalid credentials",
        );
      }
      validatedUser = current;
    }

    await this.loginThrottle.clear(phone, realm);
    return validatedUser;
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

    const result = await runSerializableTransaction(this.prisma, async (tx) => {
      const seed = await tx.refreshToken.findUnique({
        where: { tokenHash },
        select: { id: true, userId: true, scope: true },
      });
      if (!seed || seed.scope !== sessionScope) {
        throw new UnauthorizedException("Session is invalid or expired");
      }

      await lockUserLifecycleRowsForUpdateInTransaction(tx, [seed.userId]);
      const lockedFamily = await this.lockRefreshTokenFamilyInTransaction(
        tx,
        seed.id,
        seed.userId,
        sessionScope,
      );
      if (!lockedFamily.complete) {
        await this.revokeRefreshScopeInTransaction(
          tx,
          seed.userId,
          sessionScope,
          now,
        );
        return {
          rejectedRefreshToken: true as const,
          scope: sessionScope,
          revokedSessionIds: [] as string[],
          revokedUserId:
            sessionScope === AuthSessionScope.APPLICATION ? seed.userId : null,
        };
      }
      const family = lockedFamily.rows;
      const existingRow = family[0];
      const existing = existingRow
        ? await tx.refreshToken.findUnique({
            where: { id: existingRow.id },
            include: { user: true },
          })
        : null;
      if (
        !existing ||
        existing.userId !== seed.userId ||
        existing.scope !== sessionScope
      ) {
        throw new UnauthorizedException("Session is invalid or expired");
      }

      if (existing.revokedAt || existing.replacedById) {
        const revokedSessionIds = existing.replacedById
          ? await this.revokeRefreshSessionsInTransaction(
              tx,
              family.slice(1),
              now,
              existing.scope === AuthSessionScope.APPLICATION,
            )
          : [];
        return {
          rejectedRefreshToken: true as const,
          scope: existing.scope,
          revokedSessionIds,
          revokedUserId: null,
        };
      }
      if (
        existing.expiresAt <= now ||
        existing.user.status === "DISABLED" ||
        !existing.user.phoneVerifiedAt ||
        (sessionScope === AuthSessionScope.APPLICATION &&
          !existing.user.appPasswordConfiguredAt) ||
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
      if (sessionScope === AuthSessionScope.APPLICATION) {
        await enqueueSessionRevoked(tx, existing.id);
      }

      return {
        user: toSafeUser(existing.user, requiredRole === UserRole.ADMIN),
        accessToken: this.signToken(
          existing.user.id,
          existing.user.phone,
          requiredRole === UserRole.ADMIN ? "admin" : "application",
          replacement.id,
        ),
        refreshToken: nextToken,
        refreshTokenExpiresAt: nextExpiresAt,
        revokedSessionId: existing.id,
      };
    });

    if ("rejectedRefreshToken" in result) {
      if (result.scope === AuthSessionScope.APPLICATION) {
        if (result.revokedUserId) {
          this.realtime.disconnectUser(result.revokedUserId);
        } else {
          for (const sessionId of result.revokedSessionIds) {
            this.realtime.disconnectSession(sessionId);
          }
        }
      }
      throw new UnauthorizedException("Session is invalid or expired");
    }
    if (sessionScope === AuthSessionScope.APPLICATION) {
      this.realtime.disconnectSession(result.revokedSessionId);
    }
    const { revokedSessionId: _revokedSessionId, ...auth } = result;
    return auth;
  }

  refreshAdmin(refreshToken: string): Promise<AuthResponse> {
    return this.refresh({ refreshToken }, UserRole.ADMIN);
  }

  async logoutAdminRefreshToken(
    refreshToken: string,
  ): Promise<{ revoked: number }> {
    if (!isRefreshTokenForScope(refreshToken, "admin")) {
      return { revoked: 0 };
    }
    const tokenHash = hashRefreshToken(refreshToken);
    const revokedCount = await runSerializableTransaction(
      this.prisma,
      async (tx) => {
        const seed = await tx.refreshToken.findUnique({
          where: { tokenHash },
          select: { id: true, userId: true, scope: true },
        });
        if (!seed || seed.scope !== AuthSessionScope.ADMIN) return 0;

        await lockUserLifecycleRowsForUpdateInTransaction(tx, [seed.userId]);
        const lockedFamily = await this.lockRefreshTokenFamilyInTransaction(
          tx,
          seed.id,
          seed.userId,
          AuthSessionScope.ADMIN,
        );
        const now = new Date();
        if (!lockedFamily.complete) {
          return this.revokeRefreshScopeInTransaction(
            tx,
            seed.userId,
            AuthSessionScope.ADMIN,
            now,
          );
        }
        const revokedSessionIds =
          await this.revokeRefreshSessionsInTransaction(
            tx,
            lockedFamily.rows,
            now,
          );
        return revokedSessionIds.length;
      },
    );
    return { revoked: revokedCount };
  }

  async logout(userId: string, dto: LogoutDto) {
    if (!dto.refreshToken) return this.logoutAll(userId);
    if (!isRefreshTokenForScope(dto.refreshToken, "application")) {
      return { revoked: 0 };
    }
    const tokenHash = hashRefreshToken(dto.refreshToken);
    const revocation = await runSerializableTransaction(
      this.prisma,
      async (tx) => {
        const seed = await tx.refreshToken.findUnique({
          where: { tokenHash },
          select: { id: true, userId: true, scope: true },
        });
        if (
          !seed ||
          seed.userId !== userId ||
          seed.scope !== AuthSessionScope.APPLICATION
        ) {
          return {
            revokedSessionIds: [] as string[],
            revokedCount: 0,
            revokedUser: false,
          };
        }

        await lockUserLifecycleRowsForUpdateInTransaction(tx, [userId]);
        const lockedFamily = await this.lockRefreshTokenFamilyInTransaction(
          tx,
          seed.id,
          userId,
          AuthSessionScope.APPLICATION,
        );
        const now = new Date();
        if (!lockedFamily.complete) {
          const revokedCount = await this.revokeRefreshScopeInTransaction(
            tx,
            userId,
            AuthSessionScope.APPLICATION,
            now,
          );
          return {
            revokedSessionIds: [] as string[],
            revokedCount,
            revokedUser: true,
          };
        }
        const revokedSessionIds =
          await this.revokeRefreshSessionsInTransaction(
            tx,
            lockedFamily.rows,
            now,
            true,
          );
        return {
          revokedSessionIds,
          revokedCount: revokedSessionIds.length,
          revokedUser: false,
        };
      },
    );
    if (revocation.revokedUser) {
      this.realtime.disconnectUser(userId);
    } else {
      for (const sessionId of revocation.revokedSessionIds) {
        this.realtime.disconnectSession(sessionId);
      }
    }
    return { revoked: revocation.revokedCount };
  }

  private async lockRefreshTokenFamilyInTransaction(
    tx: Prisma.TransactionClient,
    startId: string,
    expectedUserId: string,
    expectedScope: AuthSessionScope,
  ): Promise<LockedRefreshTokenFamily> {
    const traversed = await tx.$queryRaw<LockedRefreshTokenTraversalRow[]>(
      Prisma.sql`
        WITH RECURSIVE "RefreshFamily" AS (
          SELECT
            token."id",
            token."userId",
            token."scope",
            token."expiresAt",
            token."revokedAt",
            token."replacedById",
            1 AS "depth"
          FROM "RefreshToken" AS token
          WHERE token."id" = ${startId}

          UNION ALL

          SELECT
            replacement."id",
            replacement."userId",
            replacement."scope",
            replacement."expiresAt",
            replacement."revokedAt",
            replacement."replacedById",
            family."depth" + 1
          FROM "RefreshFamily" AS family
          JOIN "RefreshToken" AS replacement
            ON replacement."id" = family."replacedById"
          WHERE family."depth" <= ${AuthService.maxRefreshFamilyDepth}
        )
        SELECT
          family."id",
          family."userId",
          family."scope",
          family."expiresAt",
          family."revokedAt",
          family."replacedById",
          family."depth"
        FROM "RefreshFamily" AS family
        JOIN "RefreshToken" AS locked_token
          ON locked_token."id" = family."id"
        ORDER BY family."depth" ASC
        FOR UPDATE OF locked_token
      `,
    );

    const family: LockedRefreshTokenRow[] = [];
    const visited = new Set<string>();
    let expectedId: string | null = startId;
    for (const current of traversed) {
      if (
        current.depth !== family.length + 1 ||
        current.id !== expectedId ||
        current.userId !== expectedUserId ||
        current.scope !== expectedScope ||
        visited.has(current.id) ||
        family.length >= AuthService.maxRefreshFamilyDepth
      ) {
        return { rows: family, complete: false };
      }
      visited.add(current.id);
      family.push(current);
      expectedId = current.replacedById;
    }
    return {
      rows: family,
      complete:
        family.length > 0 &&
        expectedId === null &&
        family.length <= AuthService.maxRefreshFamilyDepth,
    };
  }

  private async revokeRefreshScopeInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
    scope: AuthSessionScope,
    now: Date,
  ): Promise<number> {
    await this.lockRefreshSessionsInTransaction(tx, userId, scope);
    const revoked = await tx.refreshToken.updateMany({
      where: { userId, scope, revokedAt: null },
      data: { revokedAt: now },
    });
    if (revoked.count > 0 && scope === AuthSessionScope.APPLICATION) {
      await enqueueUserSessionsRevoked(tx, userId);
    }
    return revoked.count;
  }

  private async revokeRefreshSessionsInTransaction(
    tx: Prisma.TransactionClient,
    sessions: readonly LockedRefreshTokenRow[],
    now: Date,
    publishApplicationRevocations = false,
  ): Promise<string[]> {
    const revokedSessionIds: string[] = [];
    for (const session of sessions) {
      if (session.revokedAt) continue;
      const revoked = await tx.refreshToken.updateMany({
        where: {
          id: session.id,
          userId: session.userId,
          scope: session.scope,
          revokedAt: null,
        },
        data: { revokedAt: now },
      });
      if (revoked.count !== 1) continue;
      revokedSessionIds.push(session.id);
      if (publishApplicationRevocations) {
        await enqueueSessionRevoked(tx, session.id);
      }
    }
    return revokedSessionIds;
  }

  private async lockAdminLoginChallengesInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void> {
    await tx.$queryRaw(
      Prisma.sql`
        SELECT "id"
        FROM "AdminLoginChallenge"
        WHERE "userId" = ${userId}
          AND "consumedAt" IS NULL
        ORDER BY "id" ASC
        FOR UPDATE
      `,
    );
  }

  private async lockAdminPasswordResetChallengesInTransaction(
    tx: Prisma.TransactionClient,
    input:
      | { userId: string }
      | { challengeId: string }
      | { subjectHash: string },
  ): Promise<void> {
    if ("userId" in input) {
      await tx.$queryRaw(
        Prisma.sql`
          SELECT "id"
          FROM "AdminPasswordResetChallenge"
          WHERE "userId" = ${input.userId}
            AND "consumedAt" IS NULL
          ORDER BY "id" ASC
          FOR UPDATE
        `,
      );
      return;
    }
    if ("subjectHash" in input) {
      await tx.$queryRaw(
        Prisma.sql`
          SELECT "id"
          FROM "AdminPasswordResetChallenge"
          WHERE "subjectHash" = ${input.subjectHash}
            AND "consumedAt" IS NULL
          ORDER BY "id" ASC
          FOR UPDATE
        `,
      );
      return;
    }
    await tx.$queryRaw(
      Prisma.sql`
        SELECT "id"
        FROM "AdminPasswordResetChallenge"
        WHERE "id" = ${input.challengeId}
        FOR UPDATE
      `,
    );
  }

  private async lockRefreshSessionsInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
    scope: AuthSessionScope,
  ): Promise<void> {
    await tx.$queryRaw(
      Prisma.sql`
        SELECT "id"
        FROM "RefreshToken"
        WHERE "userId" = ${userId}
          AND "scope" = ${scope}::"AuthSessionScope"
          AND "revokedAt" IS NULL
        ORDER BY "id" ASC
        FOR UPDATE
      `,
    );
  }

  async logoutAll(
    userId: string,
    scope: AuthSessionScope = AuthSessionScope.APPLICATION,
  ) {
    const result = await runSerializableTransaction(this.prisma, async (tx) => {
      await lockUserLifecycleRowsForUpdateInTransaction(tx, [userId]);
      await this.lockRefreshSessionsInTransaction(tx, userId, scope);
      const revoked = await tx.refreshToken.updateMany({
        where: { userId, scope, revokedAt: null },
        data: { revokedAt: new Date() },
      });
      if (scope === AuthSessionScope.APPLICATION) {
        await enqueueUserSessionsRevoked(tx, userId);
      }
      return revoked;
    });
    // Chat sockets belong to the application session; only revoking that scope
    // should tear them down (an admin-scope logout must not kill app chat).
    if (scope === AuthSessionScope.APPLICATION) {
      this.realtime.disconnectUser(userId);
    }
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
      purpose === OtpPurpose.ADMIN_RESET_PASSWORD ||
      purpose === OtpPurpose.INVITE_ACCESS
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

  async requestInviteOtp(
    phoneInput: string,
    planInviteIdInput: string,
    expectedTokenHashInput: string,
    context: OtpDispatchContext = {},
    allowAcceptedCredentialRecovery = false,
  ): Promise<OtpRequestResponse> {
    const phone = PhoneNormalizer.normalizeRequired(phoneInput);
    const planInviteId = planInviteIdInput.trim();
    const expectedTokenHash = expectedTokenHashInput.trim();
    if (!planInviteId || !/^[a-f0-9]{64}$/.test(expectedTokenHash)) {
      throw this.inviteNotFoundForPhone();
    }
    const { otpId: _otpId, ...response } = await this.issueOtp(
      phone,
      OtpPurpose.INVITE_ACCESS,
      context,
      false,
      planInviteId,
      expectedTokenHash,
      allowAcceptedCredentialRecovery,
    );
    return response;
  }

  private async issueOtp(
    phone: string,
    purpose: OtpPurpose,
    context: OtpDispatchContext = {},
    quotaAlreadyConsumed = false,
    planInviteId: string | null = null,
    expectedInviteTokenHash: string | null = null,
    allowAcceptedCredentialRecovery = false,
  ): Promise<IssuedOtpResponse> {
    const mode = this.getOtpMode();
    let channel: OtpChannel;
    try {
      channel = this.requireOtpChannel(mode);
    } catch (error) {
      otpDeliveryOutcomesTotal.inc({ purpose, outcome: "unavailable" });
      throw error;
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

    const otp = await this.replaceActiveOtp(
      {
        phone,
        purpose,
        codeHash,
        expiresAt,
        maxAttempts: this.getOtpMaxAttempts(),
        planInviteId,
      },
      expectedInviteTokenHash,
      allowAcceptedCredentialRecovery,
    );

    let delivered;
    try {
      delivered = await channel.deliver(phone, code, purpose);
    } catch (error) {
      if (error instanceof OtpDeliveryUncertainError) {
        otpDeliveryOutcomesTotal.inc({ purpose, outcome: "uncertain" });
        delivered = {
          delivery: "WHATSAPP" as const,
          deliveryStatus: "UNCERTAIN" as const,
          message: AuthService.otpDeliveryUncertainMessage,
        };
      } else {
        await this.prisma.otpCode.updateMany({
          where: { id: otp.id, consumedAt: null },
          data: { consumedAt: new Date() },
        });
        otpDeliveryOutcomesTotal.inc({ purpose, outcome: "rejected" });
        throw otpDeliveryUnavailableError();
      }
    }
    if (delivered.deliveryStatus !== "UNCERTAIN") {
      otpDeliveryOutcomesTotal.inc({
        purpose,
        outcome: delivered.deliveryStatus.toLowerCase(),
      });
    }
    otpRequestsTotal.inc({ delivery: delivered.delivery });

    return {
      otpId: otp.id,
      phone,
      purpose,
      expiresAt,
      delivery: delivered.delivery,
      deliveryStatus: delivered.deliveryStatus,
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

  private requireOtpChannel(mode: string): OtpChannel {
    try {
      const channel = this.resolveOtpChannel(mode);
      if (channel) return channel;
    } catch {
      // Channel configuration details are operational secrets and must never
      // escape through a public authentication response.
    }
    throw otpDeliveryUnavailableError();
  }

  async verifyOtp(dto: VerifyOtpDto): Promise<OtpVerifyResponse> {
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    const code = this.requiredText(dto.code, "code");
    const purpose = dto.purpose;
    const now = new Date();

    if (purpose === OtpPurpose.INVITE_ACCESS) {
      throw new BadRequestException("Unsupported OTP purpose");
    }
    if (
      purpose === OtpPurpose.REGISTER ||
      purpose === OtpPurpose.RESET_PASSWORD ||
      purpose === OtpPurpose.ADMIN_RESET_PASSWORD
    ) {
      throw new BadRequestException(
        "Complete registration through POST /auth/register/complete",
      );
    }

    const result = await runSerializableTransaction(
      this.prisma,
      async (tx) => {
        let user = await this.findUserByCanonicalPhone(tx, phone);
        if (user) {
          await lockUserLifecycleRowsForUpdateInTransaction(tx, [user.id]);
          user = await tx.user.findUnique({ where: { id: user.id } });
        }
        const otpClaim = await this.claimOtpCodeInTransaction(tx, {
          phone,
          purpose,
          code,
          now,
        });
        if (otpClaim.outcome === "invalid") {
          return { otpInvalid: true as const };
        }

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

        if (user) {
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
    ).catch((error: unknown) => {
        if (
          error instanceof Prisma.PrismaClientKnownRequestError &&
          error.code === "P2034"
        ) {
          otpVerificationsTotal.inc({ outcome: "failure" });
          throw this.otpInvalid();
        }
        throw error;
      });
    if ("otpInvalid" in result) {
      otpVerificationsTotal.inc({ outcome: "failure" });
      throw this.otpInvalid();
    }
    if ("error" in result) {
      // The code was proven and consumed, but the account outcome was
      // rejected (already exists / disabled / no app account). This is a
      // distinct signal from a genuine end-to-end success.
      otpVerificationsTotal.inc({ outcome: "verified_then_rejected" });
      throw result.error;
    }
    otpVerificationsTotal.inc({ outcome: "success" });
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

  async verifyInviteOtp(
    input: InviteOtpVerifyInput,
  ): Promise<OtpVerifyResponse> {
    const cleanToken = input.token.trim();
    if (!/^[A-Za-z0-9_-]{43}$/.test(cleanToken)) {
      throw this.inviteNotFoundForPhone();
    }

    const phone = PhoneNormalizer.normalizeRequired(input.phone);
    const code = this.requiredText(input.code, "code");
    const name = input.name?.trim() ?? "";
    const password = input.password ?? "";
    const hasAccountSetup = name.length > 0 && password.length > 0;
    const now = new Date();
    const tokenHash = createHash("sha256").update(cleanToken).digest("hex");
    const inviteSeed = await this.prisma.planInvite.findFirst({
      where: {
        tokenHash,
        normalizedPhone: phone,
        declinedAt: null,
        revokedAt: null,
        expiresAt: { gt: now },
      },
      select: { id: true, acceptedAt: true, weddingPlanId: true },
    });
    if (!inviteSeed) {
      throw this.inviteNotFoundForPhone();
    }

    const existingUser = await this.findUserByCanonicalPhone(
      this.prisma,
      phone,
    );
    if (inviteSeed.acceptedAt) {
      if (!existingUser || existingUser.appPasswordConfiguredAt) {
        throw this.inviteNotFoundForPhone();
      }
      const existingMembership = await this.prisma.sharedMember.findUnique({
        where: {
          weddingPlanId_userId: {
            weddingPlanId: inviteSeed.weddingPlanId,
            userId: existingUser.id,
          },
        },
        select: { id: true },
      });
      if (!existingMembership) throw this.inviteNotFoundForPhone();
    }
    const accountSetupRequired =
      !existingUser ||
      !existingUser.appPasswordConfiguredAt ||
      (!existingUser.phoneVerifiedAt &&
        existingUser.role !== UserRole.ADMIN) ||
      (existingUser.role === UserRole.ADMIN && !existingUser.appPasswordHash);
    if (accountSetupRequired && !hasAccountSetup) {
      throw authError(
        HttpStatus.CONFLICT,
        AuthErrorCode.INVITE_ACCOUNT_SETUP_REQUIRED,
        "Create an application password to continue this invitation",
      );
    }

    const passwordHash = hasAccountSetup
      ? await bcryptjs.hash(password, 10)
      : null;

    let result: InviteOtpVerificationResult;
    try {
      result = await runSerializableTransaction(
        this.prisma,
        async (tx) => {
          let user = await this.findUserByCanonicalPhone(tx, phone);
          if (user) {
            await lockUserLifecycleRowsForUpdateInTransaction(tx, [user.id]);
            user = await tx.user.findUnique({ where: { id: user.id } });
          }
          const inviteLocked =
            await this.lockPlanInviteForUpdateInTransaction(
              tx,
              inviteSeed.id,
            );
          if (!inviteLocked) {
            return { error: this.inviteNotFoundForPhone() };
          }
          const invite = await tx.planInvite.findFirst({
            where: {
              id: inviteSeed.id,
              tokenHash,
              normalizedPhone: phone,
              declinedAt: null,
              revokedAt: null,
              expiresAt: { gt: now },
            },
            select: { id: true, acceptedAt: true, weddingPlanId: true },
          });
          if (!invite) {
            return { error: this.inviteNotFoundForPhone() };
          }
          if (invite.acceptedAt) {
            if (!user || user.appPasswordConfiguredAt) {
              return { error: this.inviteNotFoundForPhone() };
            }
            const existingMembership = await tx.sharedMember.findUnique({
              where: {
                weddingPlanId_userId: {
                  weddingPlanId: invite.weddingPlanId,
                  userId: user.id,
                },
              },
              select: { id: true },
            });
            if (!existingMembership) {
              return { error: this.inviteNotFoundForPhone() };
            }
          }

          const otpClaim = await this.claimOtpCodeInTransaction(tx, {
            phone,
            purpose: OtpPurpose.INVITE_ACCESS,
            planInviteId: invite.id,
            code,
            now,
          });
          if (otpClaim.outcome === "invalid") {
            return { otpInvalid: true as const };
          }

          const accountSetupRequired =
            !user ||
            !user.appPasswordConfiguredAt ||
            (!user.phoneVerifiedAt && user.role !== UserRole.ADMIN) ||
            (user.role === UserRole.ADMIN && !user.appPasswordHash);
          if (accountSetupRequired && (!hasAccountSetup || !passwordHash)) {
            return {
              error: authError(
                HttpStatus.CONFLICT,
                AuthErrorCode.INVITE_ACCOUNT_SETUP_REQUIRED,
                "Create an application password to continue this invitation",
              ),
            };
          }

          if (user?.status === "DISABLED") {
            return {
              error: authError(
                HttpStatus.FORBIDDEN,
                AuthErrorCode.ACCOUNT_DISABLED_AFTER_PHONE_PROOF,
                "This account is disabled",
              ),
            };
          }

          if (!user) {
            user = await tx.user.create({
              data: {
                name,
                phone,
                email: null,
                passwordHash: passwordHash!,
                appPasswordConfiguredAt: now,
                phoneVerifiedAt: now,
                lastLoginAt: now,
              },
            });
          } else if (
            user.role === UserRole.ADMIN &&
            !user.appPasswordConfiguredAt
          ) {
            const claimed = await tx.user.updateMany({
              where: {
                id: user.id,
                role: UserRole.ADMIN,
                status: "ACTIVE",
                appPasswordConfiguredAt: null,
              },
              data: {
                appPasswordHash: passwordHash!,
                appPasswordConfiguredAt: now,
                appName: name,
                appEmail: null,
                appAvatarUrl: null,
                phone,
                phoneVerifiedAt: user.phoneVerifiedAt ?? now,
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
            user = await tx.user.findUniqueOrThrow({
              where: { id: user.id },
            });
          } else if (
            !user.phoneVerifiedAt ||
            !user.appPasswordConfiguredAt
          ) {
            user = await tx.user.update({
              where: { id: user.id },
              data: {
                name,
                phone,
                passwordHash: passwordHash!,
                appPasswordConfiguredAt: now,
                phoneVerifiedAt: now,
                lastLoginAt: now,
              },
            });
          } else {
            user = await tx.user.update({
              where: { id: user.id },
              data: { lastLoginAt: now },
            });
          }

          return {
            auth: await this.createAuthResponse(user, false, tx),
          };
        },
      );
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2034"
      ) {
        otpVerificationsTotal.inc({ outcome: "failure" });
        throw this.otpInvalid();
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

    if ("otpInvalid" in result) {
      otpVerificationsTotal.inc({ outcome: "failure" });
      throw this.otpInvalid();
    }
    if ("error" in result) {
      otpVerificationsTotal.inc({ outcome: "verified_then_rejected" });
      throw result.error;
    }

    otpVerificationsTotal.inc({ outcome: "success" });
    return {
      verified: true,
      phone,
      purpose: OtpPurpose.INVITE_ACCESS,
      user: result.auth.user,
      accessToken: result.auth.accessToken,
      refreshToken: result.auth.refreshToken,
      refreshTokenExpiresAt: result.auth.refreshTokenExpiresAt,
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
    return this.requestOtp(
      {
        phone: dto.phone,
        purpose: OtpPurpose.RESET_PASSWORD,
      },
      context,
    );
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
    const passwordHash = await bcryptjs.hash(dto.newPassword, 10);
    let result: PasswordResetResult;
    try {
      result = await runSerializableTransaction(this.prisma, async (tx) => {
        let user = await this.findUserByCanonicalPhone(
          tx,
          phone,
          PhoneNormalizer.lookupVariants(phone),
        );
        if (user) {
          await lockUserLifecycleRowsForUpdateInTransaction(tx, [user.id]);
          user = await tx.user.findUnique({ where: { id: user.id } });
        }
        const otpClaim = await this.claimOtpCodeInTransaction(tx, {
          phone,
          purpose: OtpPurpose.RESET_PASSWORD,
          code: dto.code,
          now,
        });
        if (otpClaim.outcome === "invalid") {
          return { otpInvalid: true as const };
        }
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
              ? {
                  appPasswordHash: passwordHash,
                  appPasswordConfiguredAt: now,
                }
              : { passwordHash, appPasswordConfiguredAt: now }),
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
        await enqueueUserSessionsRevoked(tx, user.id);
        return { reset: true as const, userId: user.id };
      });
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2034"
      ) {
        otpVerificationsTotal.inc({ outcome: "failure" });
        throw this.otpInvalid();
      }
      throw error;
    }

    if ("otpInvalid" in result) {
      otpVerificationsTotal.inc({ outcome: "failure" });
      throw this.otpInvalid();
    }
    if ("error" in result) {
      // The code was proven and consumed, but the account outcome was
      // rejected (already exists / disabled / no app account). This is a
      // distinct signal from a genuine end-to-end success.
      otpVerificationsTotal.inc({ outcome: "verified_then_rejected" });
      throw result.error;
    }
    otpVerificationsTotal.inc({ outcome: "success" });
    // The old password's sessions were just revoked; sever any live realtime
    // channel a lost/stolen device might still hold open.
    this.realtime.disconnectUser(result.userId);
    await this.loginThrottle.clear(phone, "application");
    return { reset: true, phone };
  }

  async requestAdminPasswordReset(
    dto: AdminPasswordResetRequestDto,
    context: OtpDispatchContext = {},
  ): Promise<AdminPasswordResetPendingResponse> {
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    const mode = this.getOtpMode();
    this.requireOtpChannel(mode);
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
      if (admin) {
        await lockUserLifecycleRowsForUpdateInTransaction(tx, [admin.id]);
        await this.lockAdminLoginChallengesInTransaction(tx, admin.id);
        await this.lockAdminPasswordResetChallengesInTransaction(tx, {
          userId: admin.id,
        });
      } else {
        await this.lockAdminPasswordResetChallengesInTransaction(tx, {
          subjectHash,
        });
      }
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
      deliveryStatus: issued.deliveryStatus,
    };
  }

  async confirmAdminPasswordReset(
    dto: AdminPasswordResetConfirmDto,
  ): Promise<{ reset: true }> {
    const now = new Date();
    const challengeSeed =
      await this.prisma.adminPasswordResetChallenge.findUnique({
        where: { tokenHash: hashRefreshToken(dto.challengeToken) },
        select: { id: true, userId: true },
      });
    if (!challengeSeed) {
      await bcryptjs.compare(dto.code, AuthService.dummyPasswordHash);
      throw this.adminResetInvalid();
    }

    const passwordHash = await bcryptjs.hash(dto.newPassword, 12);

    try {
      const result = await runSerializableTransaction(
        this.prisma,
        async (tx) => {
          if (challengeSeed.userId) {
            await lockUserLifecycleRowsForUpdateInTransaction(tx, [
              challengeSeed.userId,
            ]);
            await this.lockAdminLoginChallengesInTransaction(
              tx,
              challengeSeed.userId,
            );
            await this.lockAdminPasswordResetChallengesInTransaction(tx, {
              userId: challengeSeed.userId,
            });
          } else {
            await this.lockAdminPasswordResetChallengesInTransaction(tx, {
              challengeId: challengeSeed.id,
            });
          }

          const challenge =
            await tx.adminPasswordResetChallenge.findUnique({
              where: { id: challengeSeed.id },
              include: { user: true, otp: true },
            });
          if (
            !challenge ||
            challenge.consumedAt ||
            challenge.expiresAt <= now ||
            challenge.attempts >= challenge.maxAttempts
          ) {
            if (challenge && !challenge.consumedAt) {
              await this.recordFailedAdminResetAttemptInTransaction(
                tx,
                challenge.id,
                challenge.maxAttempts,
                now,
              );
            }
            return {
              invalid: true as const,
              otpVerified: false as const,
              compareDummy: true as const,
            };
          }

          const otpClaim = await this.claimOtpCodeInTransaction(tx, {
            otpId: challenge.otpId,
            phone: challenge.otp.phone,
            purpose: OtpPurpose.ADMIN_RESET_PASSWORD,
            code: dto.code,
            now,
          });
          if (otpClaim.outcome === "invalid") {
            await this.recordFailedAdminResetAttemptInTransaction(
              tx,
              challenge.id,
              challenge.maxAttempts,
              now,
            );
            return {
              invalid: true as const,
              otpVerified: false as const,
              compareDummy: false as const,
            };
          }

          const eligibleAdmin =
            challenge.user?.role === UserRole.ADMIN &&
            challenge.user.status === "ACTIVE" &&
            challenge.user.phone === challenge.otp.phone;
          if (!eligibleAdmin) {
            await tx.adminPasswordResetChallenge.updateMany({
              where: { id: challenge.id, consumedAt: null },
              data: { consumedAt: now },
            });
            return { invalid: true as const, otpVerified: true as const };
          }

          const claimed = await tx.adminPasswordResetChallenge.updateMany({
            where: {
              id: challenge.id,
              consumedAt: null,
              expiresAt: { gt: now },
              attempts: { lt: challenge.maxAttempts },
            },
            data: { consumedAt: now },
          });
          if (claimed.count !== 1) {
            return { invalid: true as const, otpVerified: true as const };
          }

          await this.lockRefreshSessionsInTransaction(
            tx,
            challenge.userId!,
            AuthSessionScope.ADMIN,
          );

          const updated = await tx.user.updateMany({
            where: {
              id: challenge.userId!,
              role: UserRole.ADMIN,
              status: "ACTIVE",
            },
            data: { passwordHash },
          });
          if (updated.count !== 1) {
            return { invalid: true as const, otpVerified: true as const };
          }

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
                in: [OtpPurpose.ADMIN_LOGIN, OtpPurpose.ADMIN_RESET_PASSWORD],
              },
              consumedAt: null,
            },
            data: { consumedAt: now },
          });
          await tx.loginThrottle.deleteMany({
            where: { subjectHash: challenge.subjectHash },
          });
          return { reset: true as const };
        },
      );
      if ("invalid" in result) {
        if ("compareDummy" in result && result.compareDummy) {
          await bcryptjs.compare(dto.code, AuthService.dummyPasswordHash);
        }
        otpVerificationsTotal.inc({
          outcome: result.otpVerified ? "verified_then_rejected" : "failure",
        });
        throw this.adminResetInvalid();
      }
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
    if (
      user.status === "DISABLED" ||
      !user.phoneVerifiedAt ||
      (!adminMfa && !user.appPasswordConfiguredAt)
    ) {
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
        scope: adminMfa ? AuthSessionScope.ADMIN : AuthSessionScope.APPLICATION,
        expiresAt: refreshTokenExpiresAt,
      },
    });
    return {
      user: toSafeUser(user, adminMfa),
      accessToken: this.signToken(
        user.id,
        user.phone,
        adminMfa ? "admin" : "application",
        refreshSession.id,
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

  private inviteNotFoundForPhone() {
    return authError(
      HttpStatus.NOT_FOUND,
      AuthErrorCode.INVITE_NOT_FOUND_FOR_PHONE,
      "No active invitation matches this phone",
    );
  }

  private adminResetInvalid() {
    return authError(
      HttpStatus.BAD_REQUEST,
      AuthErrorCode.ADMIN_RESET_INVALID_OR_EXPIRED,
      "Admin password reset is invalid or expired",
    );
  }

  private async recordFailedAdminResetAttemptInTransaction(
    tx: Pick<Prisma.TransactionClient, "adminPasswordResetChallenge">,
    challengeId: string,
    maxAttempts: number,
    now: Date,
  ): Promise<void> {
    await tx.adminPasswordResetChallenge.updateMany({
      where: {
        id: challengeId,
        consumedAt: null,
        attempts: { lt: maxAttempts },
      },
      data: { attempts: { increment: 1 } },
    });
    await tx.adminPasswordResetChallenge.updateMany({
      where: {
        id: challengeId,
        consumedAt: null,
        attempts: { gte: maxAttempts },
      },
      data: { consumedAt: now },
    });
  }

  private signToken(
    userId: string,
    phone: string | null,
    scope: JwtPayload["scope"],
    sessionId: string,
  ): string {
    if (!sessionId) {
      throw new Error("Access-token scope and session are inconsistent");
    }
    const payload: JwtPayload = {
      sub: userId,
      phone,
      scope,
      sid: sessionId,
      ...(scope === "admin" ? { amr: "admin_mfa" as const } : {}),
    };
    return this.jwtService.sign(payload);
  }

  private async lockPlanInviteForUpdateInTransaction(
    tx: Pick<Prisma.TransactionClient, "$queryRaw">,
    planInviteId: string,
  ): Promise<boolean> {
    const locked = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "PlanInvite"
        WHERE "id" = ${planInviteId}
        FOR UPDATE
      `,
    );
    return locked.length === 1;
  }

  private async replaceActiveOtp(
    data: Pick<
      Prisma.OtpCodeUncheckedCreateInput,
      | "phone"
      | "purpose"
      | "codeHash"
      | "expiresAt"
      | "maxAttempts"
      | "planInviteId"
    >,
    expectedInviteTokenHash: string | null = null,
    allowAcceptedCredentialRecovery = false,
  ): Promise<OtpCode> {
    for (let attempt = 0; attempt < 3; attempt++) {
      const now = new Date();
      try {
        return await this.prisma.$transaction(
          async (tx) => {
            if (data.planInviteId) {
              if (!expectedInviteTokenHash) {
                throw this.inviteNotFoundForPhone();
              }
              const inviteLocked =
                await this.lockPlanInviteForUpdateInTransaction(
                  tx,
                  data.planInviteId,
                );
              if (!inviteLocked) {
                throw this.inviteNotFoundForPhone();
              }
              const activeInvite = await tx.planInvite.findFirst({
                where: {
                  id: data.planInviteId,
                  tokenHash: expectedInviteTokenHash,
                  normalizedPhone: data.phone,
                  acceptedAt: allowAcceptedCredentialRecovery
                    ? { not: null }
                    : null,
                  declinedAt: null,
                  revokedAt: null,
                  expiresAt: { gt: now },
                },
                select: { id: true },
              });
              if (!activeInvite) {
                throw this.inviteNotFoundForPhone();
              }
            }
            await tx.otpCode.updateMany({
              where: {
                phone: data.phone,
                purpose: data.purpose,
                planInviteId: data.planInviteId ?? null,
                consumedAt: null,
              },
              data: { consumedAt: now },
            });
            return tx.otpCode.create({
              data: {
                ...data,
                planInviteId: data.planInviteId ?? null,
              },
            });
          },
          { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
        );
      } catch (error) {
        if (
          data.planInviteId &&
          error instanceof Prisma.PrismaClientKnownRequestError &&
          error.code === "P2003"
        ) {
          throw this.inviteNotFoundForPhone();
        }
        const databaseCode =
          error instanceof Prisma.PrismaClientKnownRequestError
            ? String(
                (error.meta as Record<string, unknown> | undefined)?.code ?? "",
              )
            : "";
        const retryable =
          error instanceof Prisma.PrismaClientKnownRequestError &&
          (error.code === "P2002" ||
            error.code === "P2034" ||
            (error.code === "P2010" &&
              (databaseCode === "40001" || databaseCode === "40P01")));
        if (!retryable) {
          throw error;
        }
        if (attempt === 2) {
          throw otpDeliveryUnavailableError();
        }
      }
    }

    throw otpDeliveryUnavailableError();
  }

  private async claimOtpCodeInTransaction(
    tx: Pick<Prisma.TransactionClient, "otpCode">,
    input: {
      otpId?: string;
      phone: string;
      purpose: OtpPurpose;
      planInviteId?: string | null;
      code: string;
      now: Date;
    },
  ): Promise<OtpClaimResult> {
    const { otpId, phone, purpose, code, now } = input;
    const planInviteId = input.planInviteId ?? null;
    if (this.getOtpMode() !== "dev" && code === this.getDevOtpCode()) {
      return { outcome: "invalid" };
    }
    const otp = otpId
      ? await tx.otpCode.findUnique({ where: { id: otpId } })
      : await tx.otpCode.findFirst({
          where: { phone, purpose, planInviteId, consumedAt: null },
          orderBy: { createdAt: "desc" },
        });
    if (!otp) {
      return { outcome: "invalid" };
    }

    const locked = await tx.otpCode.updateMany({
      where: { id: otp.id },
      data: { updatedAt: now },
    });
    if (locked.count !== 1) return { outcome: "invalid" };

    const current = await tx.otpCode.findUnique({
      where: { id: otp.id },
    });
    if (
      !current ||
      current.phone !== phone ||
      current.purpose !== purpose ||
      (current.planInviteId ?? null) !== planInviteId
    ) {
      return { outcome: "invalid" };
    }
    if (
      current.consumedAt ||
      current.expiresAt <= now ||
      current.attempts >= current.maxAttempts
    ) {
      if (current && !current.consumedAt) {
        await tx.otpCode.updateMany({
          where: { id: current.id, consumedAt: null },
          data: { consumedAt: now },
        });
      }
      return { outcome: "invalid" };
    }

    const matches = await bcryptjs.compare(code, current.codeHash);
    if (!matches) {
      const nextAttempts = current.attempts + 1;
      await tx.otpCode.updateMany({
        where: {
          id: current.id,
          consumedAt: null,
          expiresAt: { gt: now },
          attempts: { lt: current.maxAttempts },
        },
        data: {
          attempts: { increment: 1 },
          ...(nextAttempts >= current.maxAttempts ? { consumedAt: now } : {}),
        },
      });
      return { outcome: "invalid" };
    }

    const consumed = await tx.otpCode.updateMany({
      where: {
        id: current.id,
        consumedAt: null,
        expiresAt: { gt: now },
        attempts: { lt: current.maxAttempts },
      },
      data: { consumedAt: now },
    });
    if (consumed.count !== 1) return { outcome: "invalid" };

    return {
      outcome: "verified",
      otp: {
        ...current,
        consumedAt: now,
        updatedAt: now,
      },
    };
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
