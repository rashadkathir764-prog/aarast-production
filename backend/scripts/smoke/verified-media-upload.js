'use strict';

const sharp = require('sharp');

async function createImage(contentType) {
  let pipeline = sharp({
    create: {
      width: 8,
      height: 8,
      channels: 3,
      background: { r: 132, g: 16, b: 56 },
    },
  });
  if (contentType === 'image/jpeg') pipeline = pipeline.jpeg();
  else if (contentType === 'image/webp') pipeline = pipeline.webp();
  else pipeline = pipeline.png();
  return pipeline.toBuffer();
}

async function uploadVerifiedImage({
  request,
  token,
  purpose,
  fileName = 'smoke.png',
  contentType = 'image/png',
}) {
  const bytes = await createImage(contentType);
  const presign = await request(
    'POST',
    '/api/v1/media/uploads/presign',
    { purpose, fileName, contentType, byteSize: bytes.length },
    token,
  );
  if (presign.status !== 201) return { presign, upload: null, verify: null };

  const upload = await fetch(presign.body.uploadUrl, {
    method: 'PUT',
    headers: {
      'Content-Type': contentType,
      'Content-Length': String(bytes.length),
      'If-None-Match': '*',
    },
    body: bytes,
  });
  if (!upload.ok) return { presign, upload, verify: null };

  const verify = await request(
    'POST',
    '/api/v1/media/uploads/verify',
    { key: presign.body.key, purpose },
    token,
  );
  return { presign, upload, verify };
}

/**
 * Q-59 (D127): the work photos a provider application goes to review with.
 * Uploads and verifies [count] `provider-portfolio` images of the account and
 * returns them as the application's `portfolio` items. A step that fails
 * throws: the smoke stops at the cause, not at the 422 that would follow.
 */
async function uploadApplicationPhotos({ request, token, count = 3 }) {
  const portfolio = [];
  for (let index = 0; index < count; index += 1) {
    const { presign, upload, verify } = await uploadVerifiedImage({
      request,
      token,
      purpose: 'provider-portfolio',
      fileName: `work-${index + 1}.png`,
    });
    if (presign.status !== 201 || !upload?.ok || verify?.status !== 201) {
      throw new Error(
        `Provider work photo ${index + 1} upload failed: presign ${presign.status}, ` +
          `upload ${upload?.status ?? 'not sent'}, verify ${verify?.status ?? 'not sent'}`,
      );
    }
    portfolio.push({ key: verify.body.key });
  }
  return portfolio;
}

module.exports = { createImage, uploadVerifiedImage, uploadApplicationPhotos };
