// Q-59 (D127): the work photos a provider application goes to review with,
// for the managed smokes that call the services in process. The smokes that
// go over HTTP use `uploadApplicationPhotos` in `verified-media-upload.js`;
// both draw the same image.
import { MediaStorageService } from '../../../src/media/media-storage.service';
import { MediaUploadTicketService } from '../../../src/modules/media/infrastructure/media-upload-ticket.service';
import type { AuthenticatedUser } from '../../../src/modules/identity/public/identity-session.types';

const { createImage } = require('../verified-media-upload.js') as {
  createImage: (contentType: string) => Promise<Buffer>;
};

/** The media service the smokes' provider dashboard verifies uploads with. */
export function smokeMediaStorage(prisma: unknown): MediaStorageService {
  return new MediaStorageService(new MediaUploadTicketService(prisma as any));
}

/**
 * [count] `provider-portfolio` uploads of [user]: signed, put in the run's
 * bucket and verified, returned as the application's `portfolio` items.
 */
export async function applicationPhotos(
  media: MediaStorageService,
  user: AuthenticatedUser,
  count = 3,
): Promise<Array<{ key: string }>> {
  const portfolio: Array<{ key: string }> = [];
  for (let index = 0; index < count; index += 1) {
    const bytes = await createImage('image/png');
    const signed = await media.createUpload(user, {
      purpose: 'provider-portfolio',
      fileName: `work-${index + 1}.png`,
      contentType: 'image/png',
      byteSize: bytes.length,
    });
    const put = await fetch(signed.uploadUrl, {
      method: 'PUT',
      headers: {
        'Content-Type': 'image/png',
        'Content-Length': String(bytes.length),
        'If-None-Match': '*',
      },
      body: new Uint8Array(bytes),
    });
    if (!put.ok) throw new Error(`Provider work photo ${index + 1} upload failed: ${put.status}`);
    const verified = await media.verifyUpload(user, signed.key, 'provider-portfolio');
    portfolio.push({ key: verified.key });
  }
  return portfolio;
}
