import { Injectable } from '@nestjs/common';
import { type AssistantConfig, readAssistantConfig } from './assistant-config';
import { type AssistantModel, ClaudeAssistantModel } from './assistant-model.client';

/**
 * The assistant's model and limits, read once from the environment (V1
 * checklist 4.12). Without ANTHROPIC_API_KEY, or with a model whose price is
 * unknown, the assistant is off and says so.
 */
@Injectable()
export class AssistantRuntime {
  readonly config: AssistantConfig | null;
  readonly model: AssistantModel | null;

  constructor() {
    const apiKey = process.env.ANTHROPIC_API_KEY?.trim();
    this.config = readAssistantConfig(process.env);
    this.model = apiKey && this.config ? new ClaudeAssistantModel(apiKey) : null;
  }
}
