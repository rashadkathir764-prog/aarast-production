import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthChallengeCleanupScheduler } from './auth/auth-challenge-cleanup.scheduler';
import { AuthService } from './auth/auth.service';
import { getJwtSecret } from './auth/jwt-secret';
import { JwtStrategy } from './auth/jwt.strategy';
import { LoginThrottleCleanupScheduler } from './auth/login-throttle-cleanup.scheduler';
import { LoginThrottleService } from './auth/login-throttle.service';
import { OtpDispatchQuotaCleanupScheduler } from './auth/otp-dispatch-quota-cleanup.scheduler';
import {
  OTP_DISPATCH_NOW,
  OtpDispatchQuotaService,
} from './auth/otp-dispatch-quota.service';
import { PrismaModule } from '../../../platform/database/prisma.module';
import { CollaborationPermissionPublicModule } from '../../collaboration/public/collaboration-permission-public.module';
import { MessagingRealtimePublicModule } from '../../messaging/public/messaging-realtime-public.module';

export const IDENTITY_AUTH_IMPLEMENTATION = Symbol(
  'IDENTITY_AUTH_IMPLEMENTATION',
);
export const OTP_CAPACITY_IMPLEMENTATION = Symbol('OTP_CAPACITY_IMPLEMENTATION');

@Module({
  imports: [
    PrismaModule,
    MessagingRealtimePublicModule,
    CollaborationPermissionPublicModule,
    PassportModule,
    JwtModule.registerAsync({
      useFactory: () => ({
        secret: getJwtSecret(),
        signOptions: {
          expiresIn: (process.env.JWT_ACCESS_EXPIRES_IN || '15m') as '15m',
        },
      }),
    }),
  ],
  providers: [
    AuthService,
    JwtStrategy,
    LoginThrottleService,
    LoginThrottleCleanupScheduler,
    { provide: OTP_DISPATCH_NOW, useValue: () => new Date() },
    OtpDispatchQuotaService,
    OtpDispatchQuotaCleanupScheduler,
    AuthChallengeCleanupScheduler,
    { provide: IDENTITY_AUTH_IMPLEMENTATION, useExisting: AuthService },
    // J1-19, RA-BE-02: the same quota the codes count in, read for /ready.
    { provide: OTP_CAPACITY_IMPLEMENTATION, useExisting: OtpDispatchQuotaService },
  ],
  exports: [
    AuthService,
    IDENTITY_AUTH_IMPLEMENTATION,
    OTP_CAPACITY_IMPLEMENTATION,
    JwtModule,
  ],
})
export class IdentityAuthInternalModule {}
