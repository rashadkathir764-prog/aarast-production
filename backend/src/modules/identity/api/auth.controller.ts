import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Post,
  Req,
  Res,
  UnauthorizedException,
  UseGuards,
} from "@nestjs/common";
import { Throttle } from "@nestjs/throttler";
import type { Request, Response } from "express";
import { isProductionEnvironment } from "../../../platform/config/runtime-environment";
import { AuthService } from "../internal/auth/auth.service";
import { RegisterDto } from "./auth-dto/register.dto";
import { CompleteRegistrationDto } from "./auth-dto/complete-registration.dto";
import { LoginDto } from "./auth-dto/login.dto";
import { RequestOtpDto } from "./auth-dto/request-otp.dto";
import { VerifyOtpDto } from "./auth-dto/verify-otp.dto";
import { JwtAuthGuard } from "../public/jwt-auth.guard";
import { CurrentUser } from "../public/current-user.decorator";
import { AuthenticatedUser } from "../public/identity-session.types";
import { toSafeUser } from "../public/safe-user";
import { LogoutDto } from "./auth-dto/logout.dto";
import { RefreshDto } from "./auth-dto/refresh.dto";
import { PasswordResetRequestDto } from "./auth-dto/password-reset-request.dto";
import { PasswordResetConfirmDto } from "./auth-dto/password-reset-confirm.dto";
import { CompleteAdminLoginDto } from "./auth-dto/complete-admin-login.dto";
import { AdminPasswordResetRequestDto } from "./auth-dto/admin-password-reset-request.dto";
import { AdminPasswordResetConfirmDto } from "./auth-dto/admin-password-reset-confirm.dto";

const ADMIN_REFRESH_COOKIE = "aarast_admin_refresh";

@Controller("api/v1/auth")
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post("register")
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  register(@Body() dto: RegisterDto, @Req() request: Request) {
    return this.authService.startRegistration(dto, { ip: request.ip });
  }

  @Post("register/complete")
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  completeRegistration(@Body() dto: CompleteRegistrationDto) {
    return this.authService.completeRegistration(dto);
  }

  @Post("login")
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post("admin/login")
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  startAdminLogin(@Body() dto: LoginDto, @Req() request: Request) {
    return this.authService.startAdminLogin(dto, { ip: request.ip });
  }

  @Post("admin/login/complete")
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  async completeAdminLogin(
    @Body() dto: CompleteAdminLoginDto,
    @Res({ passthrough: true }) response: Response,
  ) {
    const auth = await this.authService.completeAdminLogin(
      dto.challengeToken,
      dto.code,
    );
    this.setAdminRefreshCookie(
      response,
      auth.refreshToken,
      auth.refreshTokenExpiresAt,
    );
    return {
      user: auth.user,
      accessToken: auth.accessToken,
      accessTokenExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || "15m",
    };
  }

  @Post("admin/password-reset/request")
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  requestAdminPasswordReset(
    @Body() dto: AdminPasswordResetRequestDto,
    @Req() request: Request,
  ) {
    return this.authService.requestAdminPasswordReset(dto, { ip: request.ip });
  }

  @Post("admin/password-reset/confirm")
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  confirmAdminPasswordReset(@Body() dto: AdminPasswordResetConfirmDto) {
    return this.authService.confirmAdminPasswordReset(dto);
  }

  @Post("admin/refresh")
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  async refreshAdmin(
    @Headers("cookie") cookieHeader: string | undefined,
    @Res({ passthrough: true }) response: Response,
  ) {
    const refreshToken = this.readCookie(cookieHeader, ADMIN_REFRESH_COOKIE);
    if (!refreshToken) {
      throw new UnauthorizedException("Admin session is invalid or expired");
    }
    const auth = await this.authService.refreshAdmin(refreshToken);
    this.setAdminRefreshCookie(
      response,
      auth.refreshToken,
      auth.refreshTokenExpiresAt,
    );
    return {
      user: auth.user,
      accessToken: auth.accessToken,
      accessTokenExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || "15m",
    };
  }

  @Post("admin/logout")
  @HttpCode(HttpStatus.OK)
  async logoutAdmin(
    @Headers("cookie") cookieHeader: string | undefined,
    @Res({ passthrough: true }) response: Response,
  ) {
    const refreshToken = this.readCookie(cookieHeader, ADMIN_REFRESH_COOKIE);
    const result = refreshToken
      ? await this.authService.logoutAdminRefreshToken(refreshToken)
      : { revoked: 0 };
    response.clearCookie(ADMIN_REFRESH_COOKIE, {
      httpOnly: true,
      secure: isProductionEnvironment(),
      sameSite: "strict",
      path: "/api/v1/auth/admin",
    });
    return result;
  }

  @Post("refresh")
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  refresh(@Body() dto: RefreshDto) {
    return this.authService.refresh(dto);
  }

  @Post("logout")
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  logout(@CurrentUser() user: AuthenticatedUser, @Body() dto: LogoutDto) {
    return this.authService.logout(user.id, dto);
  }

  @Post("logout-all")
  @HttpCode(HttpStatus.OK)
  @UseGuards(JwtAuthGuard)
  logoutAll(@CurrentUser() user: AuthenticatedUser) {
    return this.authService.logoutAll(user.id);
  }

  @Post("otp/request")
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  requestOtp(@Body() dto: RequestOtpDto, @Req() request: Request) {
    return this.authService.requestOtp(dto, { ip: request.ip });
  }

  @Post("otp/verify")
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.authService.verifyOtp(dto);
  }

  @Post("password-reset/request")
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  requestPasswordReset(
    @Body() dto: PasswordResetRequestDto,
    @Req() request: Request,
  ) {
    return this.authService.requestPasswordReset(dto, { ip: request.ip });
  }

  @Post("password-reset/confirm")
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  confirmPasswordReset(@Body() dto: PasswordResetConfirmDto) {
    return this.authService.confirmPasswordReset(dto);
  }

  @Get("me")
  @UseGuards(JwtAuthGuard)
  me(@CurrentUser() user: AuthenticatedUser) {
    return toSafeUser(user);
  }

  private setAdminRefreshCookie(
    response: Response,
    token: string,
    expiresAt: Date,
  ): void {
    response.cookie(ADMIN_REFRESH_COOKIE, token, {
      httpOnly: true,
      secure: isProductionEnvironment(),
      sameSite: "strict",
      path: "/api/v1/auth/admin",
      expires: expiresAt,
    });
  }

  private readCookie(header: string | undefined, name: string): string | null {
    if (!header) return null;
    for (const part of header.split(";")) {
      const separator = part.indexOf("=");
      if (separator < 0 || part.slice(0, separator).trim() !== name) continue;
      const value = part.slice(separator + 1).trim();
      try {
        return decodeURIComponent(value);
      } catch {
        return null;
      }
    }
    return null;
  }
}
