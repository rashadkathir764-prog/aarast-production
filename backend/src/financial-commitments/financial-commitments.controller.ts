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
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { CreateFinancialCommitmentDto } from "./dto/create-financial-commitment.dto";
import { CreateFinancialInstallmentDto } from "./dto/create-financial-installment.dto";
import { CreateFinancialPaymentRecordDto } from "./dto/create-financial-payment-record.dto";
import { UpdateFinancialCommitmentDto } from "./dto/update-financial-commitment.dto";
import { UpdateFinancialInstallmentDto } from "./dto/update-financial-installment.dto";
import { FinancialCommitmentsService } from "./financial-commitments.service";

@Controller("wedding-plans/:weddingPlanId/financial-commitments")
@UseGuards(JwtAuthGuard)
export class WeddingPlanFinancialCommitmentsController {
  constructor(
    private readonly financialCommitmentsService: FinancialCommitmentsService,
  ) {}

  @Post()
  create(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Body() dto: CreateFinancialCommitmentDto,
  ) {
    return this.financialCommitmentsService.create(
      currentUser,
      weddingPlanId,
      dto,
    );
  }

  @Get()
  findForPlan(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
  ) {
    return this.financialCommitmentsService.findForPlan(
      currentUser,
      weddingPlanId,
    );
  }
}

@Controller("financial-commitments")
@UseGuards(JwtAuthGuard)
export class FinancialCommitmentsController {
  constructor(
    private readonly financialCommitmentsService: FinancialCommitmentsService,
  ) {}

  @Get(":id")
  findOne(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.financialCommitmentsService.findOne(currentUser, id);
  }

  @Patch(":id")
  update(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: UpdateFinancialCommitmentDto,
  ) {
    return this.financialCommitmentsService.update(currentUser, id, dto);
  }

  @Delete(":id")
  remove(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.financialCommitmentsService.remove(currentUser, id);
  }

  @Post(":id/payment-records")
  createPaymentRecord(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: CreateFinancialPaymentRecordDto,
  ) {
    return this.financialCommitmentsService.createPaymentRecord(
      currentUser,
      id,
      dto,
    );
  }

  @Get(":id/payment-records")
  listPaymentRecords(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.financialCommitmentsService.listPaymentRecordsForCommitment(
      currentUser,
      id,
    );
  }

  @Post(":id/installments")
  createInstallment(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: CreateFinancialInstallmentDto,
  ) {
    return this.financialCommitmentsService.createInstallment(
      currentUser,
      id,
      dto,
    );
  }

  @Get(":id/installments")
  listInstallments(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.financialCommitmentsService.listInstallmentsForCommitment(
      currentUser,
      id,
    );
  }
}

@Controller("wedding-plans/:weddingPlanId/financial-payment-records")
@UseGuards(JwtAuthGuard)
export class WeddingPlanFinancialPaymentRecordsController {
  constructor(
    private readonly financialCommitmentsService: FinancialCommitmentsService,
  ) {}

  @Get()
  findForPlan(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
  ) {
    return this.financialCommitmentsService.listPaymentRecordsForPlan(
      currentUser,
      weddingPlanId,
    );
  }
}

@Controller("financial-payment-records")
@UseGuards(JwtAuthGuard)
export class FinancialPaymentRecordsController {
  constructor(
    private readonly financialCommitmentsService: FinancialCommitmentsService,
  ) {}

  @Delete(":id")
  remove(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.financialCommitmentsService.removePaymentRecord(
      currentUser,
      id,
    );
  }
}

@Controller("wedding-plans/:weddingPlanId/financial-installments")
@UseGuards(JwtAuthGuard)
export class WeddingPlanFinancialInstallmentsController {
  constructor(
    private readonly financialCommitmentsService: FinancialCommitmentsService,
  ) {}

  @Get("due")
  dueForPlan(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
  ) {
    return this.financialCommitmentsService.listDueInstallmentsForPlan(
      currentUser,
      weddingPlanId,
    );
  }
}

@Controller("financial-installments")
@UseGuards(JwtAuthGuard)
export class FinancialInstallmentsController {
  constructor(
    private readonly financialCommitmentsService: FinancialCommitmentsService,
  ) {}

  @Patch(":id/pay")
  pay(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: { paidAt?: string | null },
  ) {
    return this.financialCommitmentsService.payInstallment(
      currentUser,
      id,
      dto?.paidAt,
    );
  }

  @Patch(":id")
  update(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
    @Body() dto: UpdateFinancialInstallmentDto,
  ) {
    return this.financialCommitmentsService.updateInstallment(
      currentUser,
      id,
      dto,
    );
  }

  @Delete(":id")
  remove(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id") id: string,
  ) {
    return this.financialCommitmentsService.removeInstallment(currentUser, id);
  }
}

@Controller("api/v1/wedding-plans/:weddingPlanId/financial-commitments")
@UseGuards(JwtAuthGuard)
export class ApiV1WeddingPlanFinancialCommitmentsController extends WeddingPlanFinancialCommitmentsController {}

@Controller("api/v1/financial-commitments")
@UseGuards(JwtAuthGuard)
export class ApiV1FinancialCommitmentsController extends FinancialCommitmentsController {}

@Controller("api/v1/wedding-plans/:weddingPlanId/financial-payment-records")
@UseGuards(JwtAuthGuard)
export class ApiV1WeddingPlanFinancialPaymentRecordsController extends WeddingPlanFinancialPaymentRecordsController {}

@Controller("api/v1/financial-payment-records")
@UseGuards(JwtAuthGuard)
export class ApiV1FinancialPaymentRecordsController extends FinancialPaymentRecordsController {}

@Controller("api/v1/wedding-plans/:weddingPlanId/financial-installments")
@UseGuards(JwtAuthGuard)
export class ApiV1WeddingPlanFinancialInstallmentsController extends WeddingPlanFinancialInstallmentsController {}

@Controller("api/v1/financial-installments")
@UseGuards(JwtAuthGuard)
export class ApiV1FinancialInstallmentsController extends FinancialInstallmentsController {}
