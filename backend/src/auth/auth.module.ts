import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './jwt.strategy';
import { PrismaModule } from '../platform/database/prisma.module';
import { getJwtSecret } from './jwt-secret';
import { LoginThrottleService } from './login-throttle.service';
import { LoginThrottleCleanupScheduler } from './login-throttle-cleanup.scheduler';
import {
  OTP_DISPATCH_NOW,
  OtpDispatchQuotaService,
} from './otp-dispatch-quota.service';
import { OtpDispatchQuotaCleanupScheduler } from './otp-dispatch-quota-cleanup.scheduler';
import { AuthChallengeCleanupScheduler } from './auth-challenge-cleanup.scheduler';
import { ConversationRealtimeModule } from '../conversations/conversation-realtime.module';

@Module({
  imports: [
    PrismaModule,
    ConversationRealtimeModule,
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
  controllers: [AuthController],
  providers: [
    AuthService,
    JwtStrategy,
    LoginThrottleService,
    LoginThrottleCleanupScheduler,
    { provide: OTP_DISPATCH_NOW, useValue: () => new Date() },
    OtpDispatchQuotaService,
    OtpDispatchQuotaCleanupScheduler,
    AuthChallengeCleanupScheduler,
  ],
  exports: [AuthService, JwtModule],
})
export class AuthModule {}
