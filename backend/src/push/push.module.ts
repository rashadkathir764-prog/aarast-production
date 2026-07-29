import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { PrismaModule } from "../prisma/prisma.module";
import { FirebasePushClient } from "./firebase-push.client";
import { PushController } from "./push.controller";
import { PushDeliveryService } from "./push-delivery.service";
import { PushInstallationsService } from "./push-installations.service";

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [PushController],
  providers: [
    FirebasePushClient,
    PushDeliveryService,
    PushInstallationsService,
  ],
  exports: [PushDeliveryService],
})
export class PushModule {}
