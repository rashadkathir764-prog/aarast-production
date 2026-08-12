import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { MediaStorageService } from './media-storage.service';
import { MediaUploadTicketService } from './media-upload-ticket.service';
import { mediaUploadCleanupBacklog } from '../platform/observability/metrics';

const CLEANUP_INTERVAL_MS = 5 * 60 * 1_000;
const MAX_BATCHES_PER_RUN = 5;

@Injectable()
export class MediaUploadCleanupScheduler {
  private readonly logger = new Logger(MediaUploadCleanupScheduler.name);

  constructor(
    private readonly tickets: MediaUploadTicketService,
    private readonly storage: MediaStorageService,
  ) {}

  @Interval(CLEANUP_INTERVAL_MS)
  async removeAbandonedUploads(): Promise<{
    claimed: number;
    deleted: number;
    failed: number;
  } | null> {
    let claimed = 0;
    let deleted = 0;
    let failed = 0;
    for (let batch = 0; batch < MAX_BATCHES_PER_RUN; batch += 1) {
      const keys = await this.tickets.claimCleanupBatch();
      if (keys === null) {
        if (batch === 0) return null;
        break;
      }
      claimed += keys.length;
      if (keys.length === 0) break;
      const result = await this.storage.deleteScheduledObjects(keys);
      deleted += result.deleted;
      failed += result.failed;
      if (keys.length < MediaUploadTicketService.cleanupBatchSize) break;
    }
    const backlog = await this.tickets.countCleanupBacklog();
    mediaUploadCleanupBacklog.set(backlog);
    if (claimed > 0 || failed > 0 || backlog > 0) {
      this.logger.log(
        `Media cleanup claimed=${claimed} deleted=${deleted} failed=${failed} backlog=${backlog}`,
      );
    }
    return { claimed, deleted, failed };
  }
}
