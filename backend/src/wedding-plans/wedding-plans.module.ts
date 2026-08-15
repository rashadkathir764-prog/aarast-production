import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { CollaborationHistoryPublicModule } from "../modules/collaboration/public/collaboration-history-public.module";
import { CollaborationPermissionPublicModule } from "../modules/collaboration/public/collaboration-permission-public.module";
import { PrismaModule } from "../platform/database/prisma.module";
import { WeddingPlansController } from "./wedding-plans.controller";
import { WeddingPlansService } from "./wedding-plans.service";

@Module({
  imports: [
    AuthModule,
    PrismaModule,
    CollaborationPermissionPublicModule,
    CollaborationHistoryPublicModule,
  ],
  controllers: [WeddingPlansController],
  providers: [WeddingPlansService],
  exports: [WeddingPlansService],
})
export class WeddingPlansModule {}
