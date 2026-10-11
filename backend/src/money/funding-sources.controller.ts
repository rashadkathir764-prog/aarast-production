import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from "@nestjs/common";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../modules/identity/public/current-user.decorator";
import { JwtAuthGuard } from "../modules/identity/public/jwt-auth.guard";
import {
  CreateFundingSourceDto,
  CreateLoanRepaymentDto,
  UpdateFundingSourceDto,
  UpdateLoanRepaymentDto,
} from "./dto/funding-source.dto";
import { FundingSourcesService } from "./funding-sources.service";

@Controller("api/v1/wedding-plans/:planId/funding-sources")
@UseGuards(JwtAuthGuard)
export class WeddingPlanFundingSourcesController {
  constructor(private readonly fundingSources: FundingSourcesService) {}

  @Get()
  findForPlan(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("planId") planId: string,
  ) {
    return this.fundingSources.findForPlan(currentUser, planId);
  }

  @Post()
  create(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("planId") planId: string,
    @Body() dto: CreateFundingSourceDto,
  ) {
    return this.fundingSources.create(currentUser, planId, dto);
  }
}

@Controller("api/v1/funding-sources")
@UseGuards(JwtAuthGuard)
export class FundingSourcesController {
  constructor(private readonly fundingSources: FundingSourcesService) {}

  @Patch(":id")
  update(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: UpdateFundingSourceDto,
  ) {
    return this.fundingSources.update(currentUser, id, dto);
  }

  @Delete(":id")
  remove(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.fundingSources.remove(currentUser, id);
  }

  @Post(":id/repayments")
  addRepayment(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: CreateLoanRepaymentDto,
  ) {
    return this.fundingSources.addRepayment(currentUser, id, dto);
  }
}

@Controller("api/v1/loan-repayments")
@UseGuards(JwtAuthGuard)
export class LoanRepaymentsController {
  constructor(private readonly fundingSources: FundingSourcesService) {}

  @Patch(":id")
  update(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: UpdateLoanRepaymentDto,
  ) {
    return this.fundingSources.updateRepayment(currentUser, id, dto);
  }

  @Delete(":id")
  remove(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.fundingSources.removeRepayment(currentUser, id);
  }
}
