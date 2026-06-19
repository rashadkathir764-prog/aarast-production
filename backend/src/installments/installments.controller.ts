import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateInstallmentDto } from './dto/create-installment.dto';
import { UpdateInstallmentDto } from './dto/update-installment.dto';
import { InstallmentsService } from './installments.service';

@Controller('debts/:debtId/installments')
@UseGuards(JwtAuthGuard)
export class DebtInstallmentsController {
  constructor(private readonly installmentsService: InstallmentsService) {}

  @Post()
  create(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('debtId') debtId: string,
    @Body() dto: CreateInstallmentDto,
  ) {
    return this.installmentsService.create(currentUser, debtId, dto);
  }

  @Get()
  findForDebt(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('debtId') debtId: string,
  ) {
    return this.installmentsService.findForDebt(currentUser, debtId);
  }
}

@Controller('wedding-plans/:weddingPlanId/installments')
@UseGuards(JwtAuthGuard)
export class WeddingPlanInstallmentsController {
  constructor(private readonly installmentsService: InstallmentsService) {}

  @Get('due')
  dueForPlan(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('weddingPlanId') weddingPlanId: string,
  ) {
    return this.installmentsService.dueForPlan(currentUser, weddingPlanId);
  }
}

@Controller('installments')
@UseGuards(JwtAuthGuard)
export class InstallmentsController {
  constructor(private readonly installmentsService: InstallmentsService) {}

  @Patch(':id/pay')
  pay(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.installmentsService.pay(currentUser, id);
  }

  @Patch(':id')
  update(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: UpdateInstallmentDto,
  ) {
    return this.installmentsService.update(currentUser, id, dto);
  }

  @Delete(':id')
  remove(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.installmentsService.remove(currentUser, id);
  }
}

@Controller('api/v1/debts/:debtId/installments')
@UseGuards(JwtAuthGuard)
export class ApiV1DebtInstallmentsController {
  constructor(private readonly installmentsService: InstallmentsService) {}

  @Post()
  create(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('debtId') debtId: string,
    @Body() dto: CreateInstallmentDto,
  ) {
    return this.installmentsService.create(currentUser, debtId, dto);
  }

  @Get()
  findForDebt(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('debtId') debtId: string,
  ) {
    return this.installmentsService.findForDebt(currentUser, debtId);
  }
}

@Controller('api/v1/installments')
@UseGuards(JwtAuthGuard)
export class ApiV1InstallmentsController {
  constructor(private readonly installmentsService: InstallmentsService) {}

  @Patch(':id/pay')
  pay(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.installmentsService.pay(currentUser, id);
  }

  @Patch(':id')
  update(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: UpdateInstallmentDto,
  ) {
    return this.installmentsService.update(currentUser, id, dto);
  }

  @Delete(':id')
  remove(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.installmentsService.remove(currentUser, id);
  }
}
