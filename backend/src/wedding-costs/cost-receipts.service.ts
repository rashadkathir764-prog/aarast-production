import {
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import {
  MEDIA_STORAGE_PORT,
  type MediaStoragePort,
} from "../modules/media/public/media-storage.port";
import {
  MAX_RECEIPTS_PER_COST,
  countCostReceipts,
  createCostReceipt,
  deleteCostReceipt,
  findCostReceipt,
  isPaymentOfCost,
  listCostReceipts,
} from "../modules/finance/infrastructure/cost-receipts.repository";
import {
  runRetryableTransaction,
  runSerializableTransaction,
} from "../platform/database/serializable-transaction";
import { PrismaService } from "../platform/database/prisma.service";
import { CreateCostReceiptDto } from "./dto/create-cost-receipt.dto";
import { WeddingCostsService } from "./wedding-costs.service";

type ReceiptRow = Awaited<ReturnType<typeof createCostReceipt>>;

/**
 * Receipts kept with a cost or one of its payments (V1 checklist 4.4). The
 * photo is private media: the app uploads it, then names it here; reading
 * returns a signed URL valid for two minutes. Who may see or change a
 * receipt is exactly who may see or change its cost.
 */
@Injectable()
export class CostReceiptsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly costs: WeddingCostsService,
    @Inject(MEDIA_STORAGE_PORT)
    private readonly media: MediaStoragePort,
  ) {}

  async addReceipt(
    currentUser: AuthenticatedUser,
    costId: string,
    dto: CreateCostReceiptDto,
  ) {
    const upload = await this.media.verifyUpload(
      currentUser,
      dto.attachmentRef,
      "cost-receipt",
    );
    const costPaymentId = dto.costPaymentId?.trim() || null;
    const receipt = await runSerializableTransaction(this.prisma, async (tx) => {
      await this.costs.assertCostManageableInTransaction(tx, currentUser, costId);
      if ((await countCostReceipts(tx, costId)) >= MAX_RECEIPTS_PER_COST) {
        throw new ConflictException({
          statusCode: 409,
          code: "COST_RECEIPT_LIMIT",
          message: `A cost keeps at most ${MAX_RECEIPTS_PER_COST} receipts`,
        });
      }
      if (costPaymentId && !(await isPaymentOfCost(tx, costPaymentId, costId))) {
        throw new NotFoundException("Cost payment not found");
      }
      const created = await createCostReceipt(tx, {
        weddingCostId: costId,
        costPaymentId,
        storageKey: upload.key,
        contentType: upload.contentType,
        byteSize: upload.byteSize,
        uploadedByUserId: currentUser.id,
      });
      await this.media.consumeUpload(
        currentUser,
        upload.key,
        "cost-receipt",
        { type: "COST_RECEIPT", id: created.id },
        tx,
      );
      return created;
    });
    return this.present(receipt);
  }

  async listReceipts(currentUser: AuthenticatedUser, costId: string) {
    const rows = await runRetryableTransaction(
      this.prisma,
      async (tx) => {
        await this.costs.assertCostVisibleInTransaction(tx, currentUser, costId);
        return listCostReceipts(tx, costId);
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
    return Promise.all(rows.map((row) => this.present(row)));
  }

  async deleteReceipt(
    currentUser: AuthenticatedUser,
    costId: string,
    receiptId: string,
  ): Promise<{ deleted: true }> {
    await runSerializableTransaction(this.prisma, async (tx) => {
      await this.costs.assertCostManageableInTransaction(tx, currentUser, costId);
      const receipt = await findCostReceipt(tx, receiptId);
      if (!receipt || receipt.weddingCostId !== costId) {
        throw new NotFoundException("Receipt not found");
      }
      await this.media.scheduleCostReceiptDeletion([receipt.id], tx);
      await deleteCostReceipt(tx, receipt.id);
    });
    return { deleted: true };
  }

  private async present(row: ReceiptRow) {
    const download = await this.media.createDownloadUrl(row.storageKey);
    return {
      id: row.id,
      weddingCostId: row.weddingCostId,
      costPaymentId: row.costPaymentId,
      contentType: row.contentType,
      byteSize: row.byteSize,
      uploadedByUserId: row.uploadedByUserId,
      createdAt: row.createdAt,
      downloadUrl: download.downloadUrl,
      downloadExpiresAt: download.expiresAt,
    };
  }
}
