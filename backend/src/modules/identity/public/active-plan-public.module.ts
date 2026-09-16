import { Module } from "@nestjs/common";
import {
  ACTIVE_PLAN_IMPLEMENTATION,
  IdentityUserInternalModule,
} from "../internal/identity-user.internal.module";
import { ACTIVE_PLAN_PORT } from "./active-plan.port";

@Module({
  imports: [IdentityUserInternalModule],
  providers: [
    {
      provide: ACTIVE_PLAN_PORT,
      useExisting: ACTIVE_PLAN_IMPLEMENTATION,
    },
  ],
  exports: [ACTIVE_PLAN_PORT],
})
export class ActivePlanPublicModule {}
