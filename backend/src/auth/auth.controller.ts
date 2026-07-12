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
import { isProductionEnvironment } from "../common/config/runtime-environment";
import { AuthService } from "./auth.service";
import { RegisterDto } from "./dto/register.dto";
import { CompleteRegistrationDto } from "./dto/complete-registration.dto";
import { LoginDto } from "./dto/login.dto";
import { RequestOtpDto } from "./dto/request-otp.dto";
import { VerifyOtpDto } from "./dto/verify-otp.dto";
import { JwtAuthGuard } from "./jwt-auth.guard";
import { CurrentUser } from "./current-user.decorator";
import { AuthenticatedUser } from "./authenticated-user.interface";
import { toSafeUser } from "./safe-user";
import { LogoutDto } from "./dto/logout.dto";
import { RefreshDto } from "./dto/refresh.dto";
import { PasswordResetRequestDto } from "./dto/password-reset-request.dto";
import { PasswordResetConfirmDto } from "./dto/password-reset-confirm.dto";
import { CompleteAdminLoginDto } from "./dto/complete-admin-login.dto";

const ADMIN_REFRESH_COOKIE = "aarast_admin_refresh";

@Controller("api/v1/auth")
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post("register")
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  register(@Body() dto: RegisterDto, @Req() request: Request) {
    return this.authService.startRegistration(dto, { ip: request.ip });
  }

  @Post("register/complete")
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  completeRegistration(@Body() dto: CompleteRegistrationDto) {
    return this.authService.completeRegistration(dto);
  }

  @Post("login")
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
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
      ? await this.authService.logoutRefreshToken(refreshToken)
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
