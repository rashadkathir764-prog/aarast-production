import { Body, Controller, Delete, Get, HttpCode, Param, Post, Put, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { routeLimit } from '../../platform/http/route-throttle';
import { CurrentUser } from '../../modules/identity/public/current-user.decorator';
import type { AuthenticatedUser } from '../../modules/identity/public/identity-session.types';
import { JwtAuthGuard } from '../../modules/identity/public/jwt-auth.guard';
import { SkipIdempotencyStore } from '../../platform/idempotency/skip-idempotency-store.decorator';
import { AssistantService } from './assistant.service';
import { AskAssistantDto } from './dto/ask-assistant.dto';
import { ReportAssistantAnswerDto } from './dto/report-assistant-answer.dto';

@Controller('api/v1/wedding-plans/:weddingPlanId/assistant')
@UseGuards(JwtAuthGuard)
export class WeddingPlanAssistantController {
  constructor(private readonly assistant: AssistantService) {}

  @Get()
  status(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('weddingPlanId') weddingPlanId: string,
  ) {
    return this.assistant.status(currentUser, weddingPlanId);
  }

  // The daily per-account limit is the real bound; this only stops floods.
  // Asking creates nothing that can be fetched again: 200, not 201.
  // RA-BE-159: the answer is generated text kept nowhere, not even as a
  // replay of the phone's request id.
  @Post('questions')
  @HttpCode(200)
  @Throttle(routeLimit(30))
  @SkipIdempotencyStore()
  ask(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('weddingPlanId') weddingPlanId: string,
    @Body() dto: AskAssistantDto,
  ) {
    return this.assistant.ask(currentUser, weddingPlanId, {
      kind: dto.kind,
      question: dto.question ?? null,
    });
  }

  // RA-BE-161: the consent sheet's «شغّل المساعد» records the account's
  // consent with its date; w40 takes it back.
  @Put('consent')
  @Throttle(routeLimit(10))
  recordConsent(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('weddingPlanId') weddingPlanId: string,
  ) {
    return this.assistant.recordConsent(currentUser, weddingPlanId);
  }

  @Delete('consent')
  @Throttle(routeLimit(10))
  withdrawConsent(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('weddingPlanId') weddingPlanId: string,
  ) {
    return this.assistant.withdrawConsent(currentUser, weddingPlanId);
  }

  // RA-ST-04 (D95): «بلّغ عن الإجابة». The account's open reports are
  // bounded in the service; this only stops floods.
  @Post('reports')
  @Throttle(routeLimit(5))
  report(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('weddingPlanId') weddingPlanId: string,
    @Body() dto: ReportAssistantAnswerDto,
  ) {
    return this.assistant.reportAnswer(currentUser, weddingPlanId, {
      answerId: dto.answerId,
      kind: dto.kind,
      question: dto.question ?? null,
      answer: dto.answer,
      reason: dto.reason,
    });
  }
}

/**
 * RA-BE-161: the consent is the account's record, so w40 reads it and takes
 * it back here, with no plan: one the reader no longer reads, or none.
 */
@Controller('api/v1/me/assistant')
@UseGuards(JwtAuthGuard)
export class AccountAssistantConsentController {
  constructor(private readonly assistant: AssistantService) {}

  @Get('consent')
  consent(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.assistant.accountConsent(currentUser);
  }

  @Delete('consent')
  @Throttle(routeLimit(10))
  withdrawConsent(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.assistant.withdrawAccountConsent(currentUser);
  }
}
