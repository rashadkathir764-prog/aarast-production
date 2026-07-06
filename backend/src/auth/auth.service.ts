import {
  BadRequestException,
  ConflictException,
  HttpException,
  HttpStatus,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { OtpCode, OtpPurpose, User } from '@prisma/client';
import * as bcryptjs from 'bcryptjs';
import { randomBytes } from 'crypto';
import { PhoneNormalizer } from '../common/phone/phone-normalizer';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RequestOtpDto } from './dto/request-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { LogoutDto } from './dto/logout.dto';
import { RefreshDto } from './dto/refresh.dto';
import { JwtPayload } from './jwt-payload.interface';
import { DevEchoOtpChannel, OtpChannel } from './otp-channel';
import {
  createRefreshTokenValue,
  hashRefreshToken,
  refreshTokenExpiry,
} from './refresh-token-policy';
import { SafeUser, toSafeUser } from './safe-user';

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
  delivery: 'LOCAL_DEV' | 'PROVIDER_PENDING' | 'WHATSAPP';
  code?: string;
  message?: string;
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

@Injectable()
export class AuthService {
  private static readonly otpUnavailableMessage =
    'خدمة التحقق غير مفعلة حاليًا. حاول لاحقًا.';

  // Per-account lockout: the IP throttle alone allows ~86k guesses/day
  // against one account. In-memory is acceptable for the current
  // single-container deployment; move to a shared store when scaling out.
  private static readonly maxFailedLogins = 5;
  private static readonly lockoutWindowMs = 15 * 60_000;
  private readonly failedLogins = new Map<
    string,
    { count: number; lockedUntil: number }
  >();

  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  async register(dto: RegisterDto): Promise<AuthResponse> {
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    const phoneVariants = PhoneNormalizer.lookupVariants(phone);
    const existing = await this.prisma.user.findFirst({
      where: {
        OR: [
          { phone: { in: phoneVariants } },
          ...(dto.email ? [{ email: dto.email }] : []),
        ],
      },
    });

    if (existing) {
      throw new ConflictException('Phone or email already registered');
    }

    const passwordHash = await bcryptjs.hash(dto.password, 10);

    const user = await this.prisma.user.create({
      data: {
        name: dto.name,
        phone,
        email: dto.email ?? null,
        passwordHash,
      },
    });

    return this.createAuthResponse(user);
  }

  async login(dto: LoginDto): Promise<AuthResponse> {
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    this.assertNotLockedOut(phone);

    const user = await this.prisma.user.findFirst({
      where: { phone: { in: PhoneNormalizer.lookupVariants(phone) } },
    });

    if (!user) {
      // Counted too, so attackers cannot distinguish unknown phones.
      this.recordFailedLogin(phone);
      throw new UnauthorizedException('Invalid credentials');
    }

    if (user.status === 'DISABLED') {
      throw new UnauthorizedException('Account is disabled');
    }

    const passwordMatch = await bcryptjs.compare(dto.password, user.passwordHash);
    if (!passwordMatch) {
      this.recordFailedLogin(phone);
      throw new UnauthorizedException('Invalid credentials');
    }

    this.failedLogins.delete(phone);

    const updatedUser = await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    return this.createAuthResponse(updatedUser);
  }

  async refresh(dto: RefreshDto): Promise<AuthResponse> {
    const tokenHash = hashRefreshToken(dto.refreshToken);
    const now = new Date();

    return this.prisma.$transaction(async (tx) => {
      const existing = await tx.refreshToken.findUnique({
        where: { tokenHash },
        include: { user: true },
      });
      if (
        !existing ||
        existing.revokedAt ||
        existing.expiresAt <= now ||
        existing.user.status === 'DISABLED'
      ) {
        throw new UnauthorizedException('Session is invalid or expired');
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
        throw new UnauthorizedException('Session is invalid or expired');
      }
      await tx.refreshToken.update({
        where: { id: existing.id },
        data: { replacedById: replacement.id },
      });

      return {
        user: toSafeUser(existing.user),
        accessToken: this.signToken(existing.user.id, existing.user.phone),
        refreshToken: nextToken,
        refreshTokenExpiresAt: nextExpiresAt,
      };
    });
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

  private assertNotLockedOut(phone: string): void {
    const entry = this.failedLogins.get(phone);
    if (!entry) return;
    if (entry.lockedUntil > Date.now()) {
      throw new HttpException(
        'Too many failed login attempts. Try again later.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }
    if (entry.lockedUntil !== 0) {
      // Lock expired — start a fresh window.
      this.failedLogins.delete(phone);
    }
  }

  private recordFailedLogin(phone: string): void {
    const entry = this.failedLogins.get(phone) ?? { count: 0, lockedUntil: 0 };
    entry.count += 1;
    if (entry.count >= AuthService.maxFailedLogins) {
      entry.lockedUntil = Date.now() + AuthService.lockoutWindowMs;
      entry.count = 0;
    }
    this.failedLogins.set(phone, entry);
  }

  async requestOtp(dto: RequestOtpDto): Promise<OtpRequestResponse> {
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    const purpose = dto.purpose;
    const channel = this.resolveOtpChannel(this.getOtpMode());

    if (!channel) {
      throw new BadRequestException(AuthService.otpUnavailableMessage);
    }

    const code = channel.generateCode();
    const codeHash = await bcryptjs.hash(code, 10);
    const now = new Date();
    const expiresAt = new Date(
      now.getTime() + this.getOtpExpiryMinutes() * 60 * 1000,
    );

    await this.prisma.otpCode.updateMany({
      where: {
        phone,
        purpose,
        consumedAt: null,
        expiresAt: { gt: now },
      },
      data: { consumedAt: now },
    });

    await this.prisma.otpCode.create({
      data: {
        phone,
        purpose,
        codeHash,
        expiresAt,
        maxAttempts: this.getOtpMaxAttempts(),
      },
    });

    const delivered = await channel.deliver(phone, code, purpose);

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
   * dev -> local echo channel; whatsapp -> plugged in at release phase 8;
   * disabled -> null (feature off).
   */
  private resolveOtpChannel(mode: string): OtpChannel | null {
    if (mode === 'dev') {
      return new DevEchoOtpChannel(this.getDevOtpCode());
    }
    return null;
  }

  async verifyOtp(dto: VerifyOtpDto): Promise<OtpVerifyResponse> {
    const phone = PhoneNormalizer.normalizeRequired(dto.phone);
    const code = this.requiredText(dto.code, 'code');
    const purpose = dto.purpose;
    const now = new Date();

    if (this.getOtpMode() !== 'dev' && code === this.getDevOtpCode()) {
      throw new BadRequestException('OTP code is invalid or expired');
    }

    const otp = await this.prisma.otpCode.findFirst({
      where: { phone, purpose, consumedAt: null },
      orderBy: { createdAt: 'desc' },
    });

    if (!otp || otp.expiresAt <= now || otp.attempts >= otp.maxAttempts) {
      if (otp && !otp.consumedAt) {
        await this.prisma.otpCode.update({
          where: { id: otp.id },
          data: { consumedAt: now },
        });
      }
      throw new BadRequestException('OTP code is invalid or expired');
    }

    const matches = await bcryptjs.compare(code, otp.codeHash);
    if (!matches) {
      await this.recordFailedOtpAttempt(otp, now);
      throw new BadRequestException('OTP code is invalid or expired');
    }

    await this.prisma.otpCode.update({
      where: { id: otp.id },
      data: { consumedAt: now },
    });

    const user = await this.handleVerifiedOtp(phone, purpose, now);
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

  private async createAuthResponse(user: User): Promise<AuthResponse> {
    const refreshToken = createRefreshTokenValue();
    const refreshTokenExpiresAt = refreshTokenExpiry();
    await this.prisma.refreshToken.create({
      data: {
        userId: user.id,
        tokenHash: hashRefreshToken(refreshToken),
        expiresAt: refreshTokenExpiresAt,
      },
    });
    return {
      user: toSafeUser(user),
      accessToken: this.signToken(user.id, user.phone),
      refreshToken,
      refreshTokenExpiresAt,
    };
  }

  private signToken(userId: string, phone: string | null): string {
    const payload: JwtPayload = { sub: userId, phone };
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
      if (user?.status === 'DISABLED') {
        throw new BadRequestException('OTP code is invalid or expired');
      }

      if (!user) {
        const invite = await this.prisma.planInvite.findFirst({
          where: { normalizedPhone: phone },
        });
        if (!invite) {
          return null;
        }

        const passwordHash = await bcryptjs.hash(
          randomBytes(24).toString('hex'),
          10,
        );
        return this.prisma.user.create({
          data: {
            name: 'مشارك أعرست',
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
    await this.prisma.otpCode.update({
      where: { id: otp.id },
      data: {
        attempts,
        ...(attempts >= otp.maxAttempts ? { consumedAt: now } : {}),
      },
    });
  }

  private getOtpMode(): 'dev' | 'whatsapp' | 'disabled' {
    const configured = (process.env.AUTH_OTP_MODE ?? '').trim().toLowerCase();
    if (configured === 'dev') {
      return process.env.NODE_ENV === 'production' ? 'disabled' : 'dev';
    }
    if (configured === 'whatsapp' || configured === 'disabled') {
      return configured;
    }
    return process.env.NODE_ENV === 'production' ? 'disabled' : 'dev';
  }

  private getDevOtpCode(): string {
    const configured = (process.env.AUTH_DEV_OTP_CODE ?? '').trim();
    if (/^\d{6}$/.test(configured)) return configured;
    return '123456';
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
