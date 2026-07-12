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

module.exports = { uploadVerifiedImage };
