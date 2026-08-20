import { Body, Controller, HttpCode, HttpStatus, Post } from "@nestjs/common";
import { Throttle } from "@nestjs/throttler";
import { AccountDeletionStatusDto } from "./user-dto/account-deletion-status.dto";
import { UsersService } from "../internal/profile/users.service";

@Controller("api/v1/account-deletions")
export class AccountDeletionStatusController {
  constructor(private readonly usersService: UsersService) {}

  @Post("status")
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  status(@Body() dto: AccountDeletionStatusDto) {
    return this.usersService.accountDeletionStatus(
      dto.userId,
      dto.clientRequestId,
    );
  }
}
