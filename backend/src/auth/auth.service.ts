import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { OtpCode, OtpPurpose, User } from '@prisma/client';
import * as bcryptjs from 'bcryptjs';
import { randomInt } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { RequestOtpDto } from './dto/request-otp.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { JwtPayload } from './jwt-payload.interface';
import { SafeUser, toSafeUser } from './safe-user';

export interface AuthResponse {
  user: SafeUser;
  accessToken: string;
}

export interface OtpRequestResponse {
  phone: string;
  purpose: OtpPurpose;
  expiresAt: Date;
  delivery: 'LOCAL_DEV' | 'PROVIDER_PENDING';
  code?: string;
}

export interface OtpVerifyResponse {
  verified: true;
  phone: string;
  purpose: OtpPurpose;
  user?: SafeUser;
  accessToken?: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  async register(dto: RegisterDto): Promise<AuthResponse> {
    const existing = await this.prisma.user.findFirst({
      where: {
        OR: [
          { phone: dto.phone },
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
        phone: dto.phone,
        email: dto.email ?? null,
        passwordHash,
      },
    });

    const accessToken = this.signToken(user.id, user.phone);
    return { user: toSafeUser(user), accessToken };
  }

  async login(dto: LoginDto): Promise<AuthResponse> {
    const user = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
    });

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (user.status === 'DISABLED') {
      throw new UnauthorizedException('Account is disabled');
    }

    const passwordMatch = await bcryptjs.compare(dto.password, user.passwordHash);
    if (!passwordMatch) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const updatedUser = await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    const accessToken = this.signToken(updatedUser.id, updatedUser.phone);
    return { user: toSafeUser(updatedUser), accessToken };
  }

  async requestOtp(dto: RequestOtpDto): Promise<OtpRequestResponse> {
    const phone = this.requiredText(dto.phone, 'phone');
    const purpose = dto.purpose;
    const code = this.generateOtpCode();
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

    const exposeCode =
      process.env.NODE_ENV !== 'production' ||
      process.env.AARAST_EXPOSE_OTP_IN_SMOKE === 'true';

    return {
      phone,
      purpose,
      expiresAt,
      delivery: exposeCode ? 'LOCAL_DEV' : 'PROVIDER_PENDING',
      ...(exposeCode ? { code } : {}),
    };
  }

  async verifyOtp(dto: VerifyOtpDto): Promise<OtpVerifyResponse> {
    const phone = this.requiredText(dto.phone, 'phone');
    const code = this.requiredText(dto.code, 'code');
    const purpose = dto.purpose;
    const now = new Date();

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
    const accessToken =
      purpose === OtpPurpose.LOGIN && user
        ? this.signToken(user.id, user.phone)
        : undefined;

    return {
      verified: true,
      phone,
      purpose,
      ...(user ? { user: toSafeUser(user) } : {}),
      ...(accessToken ? { accessToken } : {}),
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
    const user = await this.prisma.user.findUnique({ where: { phone } });

    if (purpose === OtpPurpose.LOGIN) {
      if (!user || user.status === 'DISABLED') {
        throw new BadRequestException('OTP code is invalid or expired');
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

  private generateOtpCode(): string {
    return randomInt(0, 1_000_000).toString().padStart(6, '0');
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
