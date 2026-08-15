import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { PrismaModule } from "../platform/database/prisma.module";
import { CollaborationPermissionPublicModule } from "../modules/collaboration/public/collaboration-permission-public.module";
import { ContextsController } from "./contexts.controller";
import { ContextsService } from "./contexts.service";

@Module({
  imports: [AuthModule, PrismaModule, CollaborationPermissionPublicModule],
  controllers: [ContextsController],
  providers: [ContextsService],
})
export class ContextsModule {}
