import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { PrismaModule } from "../platform/database/prisma.module";
import { SharingModule } from "../sharing/sharing.module";
import { ContextsController } from "./contexts.controller";
import { ContextsService } from "./contexts.service";

@Module({
  imports: [AuthModule, PrismaModule, SharingModule],
  controllers: [ContextsController],
  providers: [ContextsService],
})
export class ContextsModule {}
