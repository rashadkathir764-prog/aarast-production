import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from "@nestjs/common";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../modules/identity/public/current-user.decorator";
import { JwtAuthGuard } from "../modules/identity/public/jwt-auth.guard";
import { CreateCostPaymentDto } from "./dto/create-cost-payment.dto";
import { CreatePaymentScheduleDto } from "./dto/create-payment-schedule.dto";
import { CreateWeddingCostDto } from "./dto/create-wedding-cost.dto";
import { ListCostPaymentsQueryDto } from "./dto/list-cost-payments-query.dto";
import { ListCostsQueryDto } from "./dto/list-costs-query.dto";
import { PayPaymentScheduleDto } from "./dto/pay-payment-schedule.dto";
import { ReverseCostPaymentDto } from "./dto/reverse-cost-payment.dto";
import { UpdatePaymentScheduleDto } from "./dto/update-payment-schedule.dto";
import { UpdateWeddingCostDto } from "./dto/update-wedding-cost.dto";
import { WeddingCostsService } from "./wedding-costs.service";

@Controller("api/v1/wedding-plans/:weddingPlanId/costs")
@UseGuards(JwtAuthGuard)
export class WeddingPlanCostsController {
  constructor(private readonly service: WeddingCostsService) {}

  @Post()
  create(
    @CurrentUser() user: AuthenticatedUser,
    @Param("weddingPlanId") planId: string,
    @Body() dto: CreateWeddingCostDto,
  ) {
    return this.service.createCost(user, planId, dto);
  }

  @Get()
  list(
    @CurrentUser() user: AuthenticatedUser,
    @Param("weddingPlanId") planId: string,
    @Query() query: ListCostsQueryDto,
  ) {
    return this.service.listCosts(user, planId, query);
  }
}

@Controller("api/v1/costs")
@UseGuards(JwtAuthGuard)
export class CostsController {
  constructor(private readonly service: WeddingCostsService) {}

  @Get(":id")
  get(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string) {
    return this.service.getCost(user, id);
  }

  @Patch(":id")
  update(
    @CurrentUser() user: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: UpdateWeddingCostDto,
  ) {
    return this.service.updateCost(user, id, dto);
  }

  @Delete(":id")
  remove(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string) {
    return this.service.deleteCost(user, id);
  }

  @Post(":id/cancel")
  cancel(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string) {
    return this.service.cancelCost(user, id);
  }

  @Post(":id/payments")
  createPayment(
    @CurrentUser() user: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: CreateCostPaymentDto,
  ) {
    return this.service.createPayment(user, id, dto);
  }

  @Get(":id/payments")
  listPayments(
    @CurrentUser() user: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.service.listPaymentsForCost(user, id);
  }

  @Post(":id/payment-schedules")
  createSchedule(
    @CurrentUser() user: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: CreatePaymentScheduleDto,
  ) {
    return this.service.createSchedule(user, id, dto);
  }

  @Get(":id/payment-schedules")
  listSchedules(
    @CurrentUser() user: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.service.listSchedulesForCost(user, id);
  }
}

@Controller("api/v1/wedding-plans/:weddingPlanId/cost-payments")
@UseGuards(JwtAuthGuard)
export class WeddingPlanCostPaymentsController {
  constructor(private readonly service: WeddingCostsService) {}

  @Get()
  list(
    @CurrentUser() user: AuthenticatedUser,
    @Param("weddingPlanId") planId: string,
    @Query() query: ListCostPaymentsQueryDto,
  ) {
    return this.service.listPaymentsForPlan(user, planId, query);
  }
}

@Controller("api/v1/cost-payments")
@UseGuards(JwtAuthGuard)
export class CostPaymentsController {
  constructor(private readonly service: WeddingCostsService) {}

  @Get(":id")
  get(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string) {
    return this.service.getPayment(user, id);
  }

  @Post(":id/reverse")
  reverse(
    @CurrentUser() user: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: ReverseCostPaymentDto,
  ) {
    return this.service.reversePayment(user, id, dto);
  }
}

@Controller("api/v1/wedding-plans/:weddingPlanId/payment-schedules")
@UseGuards(JwtAuthGuard)
export class WeddingPlanPaymentSchedulesController {
  constructor(private readonly service: WeddingCostsService) {}

  @Get("due")
  due(
    @CurrentUser() user: AuthenticatedUser,
    @Param("weddingPlanId") planId: string,
  ) {
    return this.service.listDueSchedulesForPlan(user, planId);
  }
}

@Controller("api/v1/payment-schedules")
@UseGuards(JwtAuthGuard)
export class PaymentSchedulesController {
  constructor(private readonly service: WeddingCostsService) {}

  @Patch(":id")
  update(
    @CurrentUser() user: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: UpdatePaymentScheduleDto,
  ) {
    return this.service.updateSchedule(user, id, dto);
  }

  @Delete(":id")
  remove(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string) {
    return this.service.deleteSchedule(user, id);
  }

  @Post(":id/cancel")
  cancel(@CurrentUser() user: AuthenticatedUser, @Param("id") id: string) {
    return this.service.cancelSchedule(user, id);
  }

  @Post(":id/pay")
  pay(
    @CurrentUser() user: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: PayPaymentScheduleDto,
  ) {
    return this.service.paySchedule(user, id, dto);
  }
}
