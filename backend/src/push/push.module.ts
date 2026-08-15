import { Module } from "@nestjs/common";
import { IdentityAuthPublicModule } from "../modules/identity/public/identity-auth-public.module";
import { PrismaModule } from "../platform/database/prisma.module";
import { PushController } from "./push.controller";
import { PushInstallationsService } from "./push-installations.service";

@Module({
  imports: [IdentityAuthPublicModule, PrismaModule],
  controllers: [PushController],
  providers: [PushInstallationsService],
})
export class PushModule {}
