import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  UseGuards,
} from "@nestjs/common";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../modules/identity/public/current-user.decorator";
import { JwtAuthGuard } from "../modules/identity/public/jwt-auth.guard";
import { CostReceiptsService } from "./cost-receipts.service";
import { CreateCostReceiptDto } from "./dto/create-cost-receipt.dto";

// V1 checklist 4.4: receipt photos kept with a cost or one of its payments.
@Controller("api/v1/costs/:costId/receipts")
@UseGuards(JwtAuthGuard)
export class CostReceiptsController {
  constructor(private readonly receipts: CostReceiptsService) {}

  @Get()
  list(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("costId") costId: string,
  ) {
    return this.receipts.listReceipts(currentUser, costId);
  }

  @Post()
  add(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("costId") costId: string,
    @Body() dto: CreateCostReceiptDto,
  ) {
    return this.receipts.addReceipt(currentUser, costId, dto);
  }

  @Delete(":receiptId")
  remove(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("costId") costId: string,
    @Param("receiptId") receiptId: string,
  ) {
    return this.receipts.deleteReceipt(currentUser, costId, receiptId);
  }
}
