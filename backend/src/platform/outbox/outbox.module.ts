import { Module } from "@nestjs/common";
import { ConversationRealtimeModule } from "../../conversations/conversation-realtime.module";
import { PrismaModule } from "../database/prisma.module";
import { PushModule } from "../../push/push.module";
import { OutboxDispatcher } from "./outbox.dispatcher";
import { OutboxCleanupScheduler } from "./outbox-cleanup.scheduler";
import { OutboxService } from "./outbox.service";
import { OutboxWorker } from "./outbox.worker";

@Module({
  imports: [PrismaModule, ConversationRealtimeModule, PushModule],
  providers: [
    OutboxService,
    OutboxDispatcher,
    OutboxWorker,
    OutboxCleanupScheduler,
  ],
  exports: [OutboxService],
})
export class OutboxModule {}
