import { Module } from "@nestjs/common";
import { PrismaModule } from "../prisma/prisma.module";
import { SharingModule } from "../sharing/sharing.module";
import { UsersController } from "./users.controller";
import { UsersService } from "./users.service";

@Module({
  imports: [PrismaModule, SharingModule],
  controllers: [UsersController],
  providers: [UsersService],
})
export class UsersModule {}
