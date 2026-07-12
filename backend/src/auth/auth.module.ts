import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './jwt.strategy';
import { OwnershipContextService } from './ownership-context.service';
import { PrismaModule } from '../prisma/prisma.module';
import { getJwtSecret } from './jwt-secret';
import { LoginThrottleService } from './login-throttle.service';
import { LoginThrottleCleanupScheduler } from './login-throttle-cleanup.scheduler';

@Module({
  imports: [
    PrismaModule,
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
    OwnershipContextService,
    LoginThrottleService,
    LoginThrottleCleanupScheduler,
  ],
  exports: [OwnershipContextService, JwtModule],
})
export class AuthModule {}
