import { Body, Controller, Get, HttpCode, Param, Post, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { CurrentUser } from '../../modules/identity/public/current-user.decorator';
import type { AuthenticatedUser } from '../../modules/identity/public/identity-session.types';
import { JwtAuthGuard } from '../../modules/identity/public/jwt-auth.guard';
import { AssistantService } from './assistant.service';
import { AskAssistantDto } from './dto/ask-assistant.dto';

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
  @Post('questions')
  @HttpCode(200)
  @Throttle({ default: { limit: 30, ttl: 60_000 } })
  ask(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('weddingPlanId') weddingPlanId: string,
    @Body() dto: AskAssistantDto,
  ) {
    return this.assistant.ask(currentUser, weddingPlanId, {
      kind: dto.kind,
      question: dto.question ?? null,
      consent: dto.consent,
    });
  }
}
