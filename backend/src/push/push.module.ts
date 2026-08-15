import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { PrismaModule } from "../platform/database/prisma.module";
import { PushController } from "./push.controller";
import { PushInstallationsService } from "./push-installations.service";

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [PushController],
  providers: [PushInstallationsService],
})
export class PushModule {}
