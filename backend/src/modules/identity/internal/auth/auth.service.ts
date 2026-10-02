import {
  BadRequestException,
  HttpStatus,
  Inject,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import {
  MESSAGING_REALTIME_PORT,
  MessagingRealtimePort,
} from "../../../messaging/public/messaging-realtime.port";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort,
} from "../../../collaboration/public/collaboration-permission.port";
import {
  IdentityAuthPort,
  InviteOtpVerifyInput,
  OtpDispatchContext,
} from "../../public/identity-auth.port";
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
} from "../../../../platform/observability/metrics";
import { PhoneNormalizer } from "../../../../shared-kernel/phone/phone-normalizer";
import { runSerializableTransaction } from "../../../../platform/database/serializable-transaction";
import { PrismaService } from "../../../../platform/database/prisma.service";
import { RegisterDto } from "../../api/auth-dto/register.dto";
import { CompleteRegistrationDto } from "../../api/auth-dto/complete-registration.dto";
import { LoginDto } from "../../api/auth-dto/login.dto";
import { RequestOtpDto } from "../../api/auth-dto/request-otp.dto";
import { VerifyOtpDto } from "../../api/auth-dto/verify-otp.dto";
import { LogoutDto } from "../../api/auth-dto/logout.dto";
import { RefreshDto } from "../../api/auth-dto/refresh.dto";
import { PasswordResetRequestDto } from "../../api/auth-dto/password-reset-request.dto";
import { PasswordResetConfirmDto } from "../../api/auth-dto/password-reset-confirm.dto";
import { AdminPasswordResetRequestDto } from "../../api/auth-dto/admin-password-reset-request.dto";
import { AdminPasswordResetConfirmDto } from "../../api/auth-dto/admin-password-reset-confirm.dto";
import { JwtPayload } from "../../public/jwt-payload.interface";
import {
  DevEchoOtpChannel,
  generateProductionOtpCode,
  OtpChannel,
} from "./otp-channel";
import {
  OtpDeliveryUncertainError,
} from "../../../../platform/otp-transport/otp-delivery";
import { OpenWaOtpChannel } from "../../../../platform/otp-transport/openwa-otp.channel";
import { WhatsAppOtpChannel } from "../../../../platform/otp-transport/whatsapp-otp.channel";
import {
  createOpaqueTokenValue,
  createRefreshTokenValue,
  hashRefreshToken,
  isRefreshTokenForScope,
  refreshTokenExpiry,
  RefreshTokenScope,
} from "./refresh-token-policy";
import { SafeUser } from "../../public/safe-user";
import { toSafeUser } from "../safe-user.presenter";
import {
  LoginThrottleRealm,
  LoginThrottleService,
} from "./login-throttle.service";
import {
  OtpDispatchQuotaService,
} from "./otp-dispatch-quota.service";
import {
  authError,
  AuthErrorCode,
  otpDeliveryUnavailableError,
} from "../../public/auth-error";
import {
  lockUserLifecycleRowsForUpdateInTransaction,
} from "../../public/user-lifecycle-lock";
import {
  enqueueUserSessionsRevoked,
} from "../../../../platform/outbox/realtime-revocation";
import { AuthUserRepository } from "../../infrastructure/auth-user.repository";
import { AuthOtpRepository, type OtpClaimResult } from "../../infrastructure/auth-otp.repository";
import { AuthChallengeRepository } from "../../infrastructure/auth-challenge.repository";
import { AuthSessionRepository, type LockedRefreshTokenRow, type LockedRefreshTokenFamily } from "../../infrastructure/auth-session.repository";

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

interface OtpChannelSelection {
  channel: OtpChannel;
  generateCode: () => string;
}

@Injectable()
export class AuthService implements IdentityAuthPort {
  private readonly users = new AuthUserRepository();
  private readonly otps = new AuthOtpRepository();
  private readonly challenges = new AuthChallengeRepository();
  private readonly sessions = new AuthSessionRepository();
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
    @Inject(MESSAGING_REALTIME_PORT)
    private readonly realtime: MessagingRealtimePort,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly collaboration: CollaborationPermissionPort,
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
            existing = await this.users.findById(tx, existing.id);
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
            const claimed = await this.users.claimAdminApplicationRegistration(
              tx, existing, phone, dto.name, passwordHash, now,
            );
            if (claimed.count !== 1) {
              return {
                error: authError(
                  HttpStatus.CONFLICT,
                  AuthErrorCode.ADMIN_APP_PASSWORD_ALREADY_SET,
                  "The application password is already configured",
                ),
              };
            }
            const user = await this.users.requireById(tx, existing.id);
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
            const claimed = await this.users.claimApplicationRegistration(
              tx, existing.id, phone, dto.name, passwordHash, now,
            );
            if (claimed.count !== 1) {
              return {
                error: authError(
                  HttpStatus.CONFLICT,
                  AuthErrorCode.ACCOUNT_ALREADY_EXISTS,
                  "An account already exists for this phone",
                ),
              };
            }
            const user = await this.users.requireById(tx, existing.id);
            return { auth: await this.createAuthResponse(user, false, tx) };
          }

          const user = await this.users.createApplicationUser(
            tx, dto.name, phone, passwordHash, now,
          );
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
      const loginAt = new Date();
      const eligible = await this.users.markSuccessfulLogin(tx, user, loginAt);
      if (eligible.count !== 1) {
        throw authError(
          HttpStatus.UNAUTHORIZED,
          AuthErrorCode.INVALID_CREDENTIALS,
          "Invalid credentials",
        );
      }
      const updatedUser = await this.users.requireById(tx, user.id);
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
      const currentUser = await this.users.findById(tx, user.id);
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
      const issuedOtp = await this.otps.issuedConsumedAt(tx, otp.otpId);
      const superseded = issuedOtp.consumedAt !== null;
      await this.challenges.createAdminLogin(tx, {
        userId: user.id, otpId: otp.otpId,
        tokenHash: hashRefreshToken(challengeToken), expiresAt, superseded, now,
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
    const challengeSeed = await this.challenges.findAdminLoginSeed(
      this.prisma, hashRefreshToken(challengeToken),
    );
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
          const challenge = await this.challenges.findAdminLogin(tx, challengeSeed.id);
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

          const consumedChallenge = await this.challenges.consumeAdminLogin(
            tx, challenge.id, now,
          );
          if (consumedChallenge.count !== 1) {
            throw new UnauthorizedException(
              "Admin login challenge is invalid or expired",
            );
          }

          const eligible = await this.users.markAdminMfaLogin(tx, challenge.user, now);
          if (eligible.count !== 1) {
            throw new UnauthorizedException("Admin access is required");
          }
          const updatedUser = await this.users.requireById(tx, challenge.userId);
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
    const user = await this.users.findByCanonicalPhone(
      this.prisma, phone, PhoneNormalizer.lookupVariants(phone),
    );

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
      const upgraded = await this.users.upgradeAdminPasswordHash(
        this.prisma, user.id, credentialHash, upgradedPasswordHash,
      );
      if (upgraded.count !== 1) {
        throw authError(
          HttpStatus.UNAUTHORIZED,
          AuthErrorCode.INVALID_CREDENTIALS,
          "Invalid credentials",
        );
      }
      const current = await this.users.findById(this.prisma, user.id);
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
      const seed = await this.sessions.findSeed(tx, tokenHash);
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
        ? await this.sessions.findWithUser(tx, existingRow.id)
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
      const replacementId = await this.sessions.rotate(tx, {
        id: existing.id, userId: existing.userId,
        tokenHash: hashRefreshToken(nextToken), scope: sessionScope,
        now, expiresAt: nextExpiresAt,
      });

      return {
        user: toSafeUser(existing.user, requiredRole === UserRole.ADMIN),
        accessToken: this.signToken(
          existing.user.id,
          existing.user.phone,
          requiredRole === UserRole.ADMIN ? "admin" : "application",
          replacementId,
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
        const seed = await this.sessions.findSeed(tx, tokenHash);
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
        const seed = await this.sessions.findSeed(tx, tokenHash);
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
    return this.sessions.lockFamily(tx, startId, expectedUserId, expectedScope);
  }

  private async revokeRefreshScopeInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
    scope: AuthSessionScope,
    now: Date,
  ): Promise<number> {
    return this.sessions.revokeScope(tx, userId, scope, now);
  }

  private async revokeRefreshSessionsInTransaction(
    tx: Prisma.TransactionClient,
    sessions: readonly LockedRefreshTokenRow[],
    now: Date,
    publishApplicationRevocations = false,
  ): Promise<string[]> {
    return this.sessions.revokeFamily(tx, sessions, now, publishApplicationRevocations);
  }

  private async lockAdminLoginChallengesInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void> {
    await this.challenges.lockAdminLogins(tx, userId);
  }

  private async lockAdminPasswordResetChallengesInTransaction(
    tx: Prisma.TransactionClient,
    input:
      | { userId: string }
      | { challengeId: string }
      | { subjectHash: string },
  ): Promise<void> {
    await this.challenges.lockAdminResets(tx, input);
  }

  private async lockRefreshSessionsInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
    scope: AuthSessionScope,
  ): Promise<void> {
    await this.sessions.lockActiveScope(tx, userId, scope);
  }

  async logoutAll(
    userId: string,
    scope: AuthSessionScope = AuthSessionScope.APPLICATION,
  ) {
    const result = await runSerializableTransaction(this.prisma, async (tx) => {
      await lockUserLifecycleRowsForUpdateInTransaction(tx, [userId]);
      await this.lockRefreshSessionsInTransaction(tx, userId, scope);
      const revoked = await this.sessions.revokeActiveScope(tx, userId, scope, new Date());
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
    let selection: OtpChannelSelection;
    try {
      selection = this.requireOtpChannel(mode);
    } catch (error) {
      otpDeliveryOutcomesTotal.inc({ purpose, outcome: "unavailable" });
      throw error;
    }
    if (mode !== "dev" && !quotaAlreadyConsumed) {
      await this.otpDispatchQuota.consume(phone, context);
    }

    const code = selection.generateCode();
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
      delivered = await selection.channel.deliver(phone, code, purpose);
    } catch (error) {
      if (error instanceof OtpDeliveryUncertainError) {
        otpDeliveryOutcomesTotal.inc({ purpose, outcome: "uncertain" });
        delivered = {
          delivery: "WHATSAPP" as const,
          deliveryStatus: "UNCERTAIN" as const,
          message: AuthService.otpDeliveryUncertainMessage,
        };
      } else {
        await this.otps.consumeIfActive(this.prisma, otp.id, new Date());
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
  private resolveOtpChannel(mode: string): OtpChannelSelection | null {
    if (mode === "dev") {
      const fixedCode = this.getDevOtpCode();
      return {
        channel: new DevEchoOtpChannel(fixedCode),
        generateCode: () => fixedCode,
      };
    }
    if (mode === "whatsapp") {
      return {
        channel: new WhatsAppOtpChannel(),
        generateCode: generateProductionOtpCode,
      };
    }
    if (mode === "openwa") {
      return {
        channel: new OpenWaOtpChannel(),
        generateCode: generateProductionOtpCode,
      };
    }
    return null;
  }

  private requireOtpChannel(mode: string): OtpChannelSelection {
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
          user = await this.users.findById(tx, user.id);
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
          user = await this.users.markPhoneVerified(tx, user, purpose === OtpPurpose.LOGIN, now);
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
    const inviteSeed = await this.collaboration.findLivePlanInvite(
      this.prisma,
      { tokenHash, normalizedPhone: phone, now },
    );
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
      const existingMembership = await this.collaboration.getMembership(
        this.prisma,
        inviteSeed.weddingPlanId,
        existingUser.id,
      );
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
            user = await this.users.findById(tx, user.id);
          }
          const inviteLocked =
            await this.collaboration.lockPlanInviteForUpdateInTransaction(
              tx,
              inviteSeed.id,
            );
          if (!inviteLocked) {
            return { error: this.inviteNotFoundForPhone() };
          }
          const invite = await this.collaboration.findLivePlanInvite(tx, {
            id: inviteSeed.id,
            tokenHash,
            normalizedPhone: phone,
            now,
          });
          if (!invite) {
            return { error: this.inviteNotFoundForPhone() };
          }
          if (invite.acceptedAt) {
            if (!user || user.appPasswordConfiguredAt) {
              return { error: this.inviteNotFoundForPhone() };
            }
            const existingMembership = await this.collaboration.getMembership(
              tx,
              invite.weddingPlanId,
              user.id,
            );
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
            user = await this.users.createApplicationUser(tx, name, phone, passwordHash!, now);
          } else if (
            user.role === UserRole.ADMIN &&
            !user.appPasswordConfiguredAt
          ) {
            const claimed = await this.users.claimInviteAdminApplication(
              tx, user, name, phone, passwordHash!, now,
            );
            if (claimed.count !== 1) {
              return {
                error: authError(
                  HttpStatus.CONFLICT,
                  AuthErrorCode.ADMIN_APP_PASSWORD_ALREADY_SET,
                  "The application password is already configured",
                ),
              };
            }
            user = await this.users.requireById(tx, user.id);
          } else if (
            !user.phoneVerifiedAt ||
            !user.appPasswordConfiguredAt
          ) {
            user = await this.users.completeInviteAccountSetup(
              tx, user.id, name, phone, passwordHash!, now,
            );
          } else {
            user = await this.users.touchLastLogin(tx, user.id, now);
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
          user = await this.users.findById(tx, user.id);
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

        await this.users.resetApplicationPassword(tx, user, passwordHash, now);
        await this.sessions.revokeActiveScope(tx, user.id, AuthSessionScope.APPLICATION, now);
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
      const issuedOtp = await this.otps.issuedConsumedAt(tx, issued.otpId);
      const superseded = issuedOtp.consumedAt !== null;
      await this.challenges.createAdminReset(tx, {
        userId: admin?.id ?? null, otpId: issued.otpId,
        tokenHash: hashRefreshToken(challengeToken), subjectHash,
        expiresAt, superseded, now,
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
    const challengeSeed = await this.challenges.findAdminResetSeed(
      this.prisma, hashRefreshToken(dto.challengeToken),
    );
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

          const challenge = await this.challenges.findAdminReset(tx, challengeSeed.id);
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
            await this.challenges.consumeAdminResetIfActive(tx, challenge.id, now);
            return { invalid: true as const, otpVerified: true as const };
          }

          const claimed = await this.challenges.claimAdminReset(
            tx, challenge.id, challenge.maxAttempts, now,
          );
          if (claimed.count !== 1) {
            return { invalid: true as const, otpVerified: true as const };
          }

          await this.lockRefreshSessionsInTransaction(
            tx,
            challenge.userId!,
            AuthSessionScope.ADMIN,
          );

          const updated = await this.users.resetAdministratorPassword(
            tx, challenge.userId!, passwordHash,
          );
          if (updated.count !== 1) {
            return { invalid: true as const, otpVerified: true as const };
          }

          await this.sessions.revokeActiveScope(tx, challenge.userId!, AuthSessionScope.ADMIN, now);
          await this.challenges.consumeActiveAdminLogins(tx, challenge.userId!, now);
          await this.challenges.consumeActiveAdminResetsByUser(tx, challenge.userId!, now);
          await this.otps.consumeAdministratorCodes(tx, challenge.user!.phone!, now);
          await this.sessions.clearLoginThrottle(tx, challenge.subjectHash);
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
    client: PrismaService | Prisma.TransactionClient = this.prisma,
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
    const refreshSession = await this.sessions.create(
      client, user.id, hashRefreshToken(refreshToken),
      adminMfa ? AuthSessionScope.ADMIN : AuthSessionScope.APPLICATION,
      refreshTokenExpiresAt,
    );
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
    client: PrismaService | Prisma.TransactionClient,
    phone: string,
    variants = PhoneNormalizer.lookupVariants(phone),
  ): Promise<User | null> {
    return this.users.findByCanonicalPhone(client, phone, variants);
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
    tx: Prisma.TransactionClient,
    challengeId: string,
    maxAttempts: number,
    now: Date,
  ): Promise<void> {
    await this.challenges.recordFailedAdminResetAttempt(tx, challengeId, maxAttempts, now);
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
                await this.collaboration.lockPlanInviteForUpdateInTransaction(
                  tx,
                  data.planInviteId,
                );
              if (!inviteLocked) {
                throw this.inviteNotFoundForPhone();
              }
              const activeInvite = await this.collaboration.findLivePlanInvite(
                tx,
                {
                  id: data.planInviteId,
                  tokenHash: expectedInviteTokenHash,
                  normalizedPhone: data.phone,
                  now,
                  accepted: allowAcceptedCredentialRecovery,
                },
              );
              if (!activeInvite) {
                throw this.inviteNotFoundForPhone();
              }
            }
            return this.otps.replaceActive(tx, data, now);
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
    tx: Prisma.TransactionClient,
    input: {
      otpId?: string;
      phone: string;
      purpose: OtpPurpose;
      planInviteId?: string | null;
      code: string;
      now: Date;
    },
  ): Promise<OtpClaimResult> {
    if (this.getOtpMode() === "disabled") {
      throw otpDeliveryUnavailableError();
    }
    if (this.getOtpMode() !== "dev" && input.code === this.getDevOtpCode()) {
      return { outcome: "invalid" };
    }
    return this.otps.claim(tx, input);
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
