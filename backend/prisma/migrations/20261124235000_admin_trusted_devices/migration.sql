-- RA-AD-26: the admin browsers remembered after a password + code sign-in
-- are kept by the server, so a device can be revoked. Additive. The signed
-- cookies issued before this name no row and are not trusted any more, so
-- each admin enters the WhatsApp code once more on a remembered browser.

-- CreateTable
CREATE TABLE "AdminTrustedDevice" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "tokenHash" CHAR(64) NOT NULL,
    "passwordFingerprint" TEXT NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "revokedAt" TIMESTAMP(3),
    "lastUsedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AdminTrustedDevice_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "AdminTrustedDevice_tokenHash_key" ON "AdminTrustedDevice"("tokenHash");

-- CreateIndex
CREATE INDEX "AdminTrustedDevice_userId_revokedAt_idx" ON "AdminTrustedDevice"("userId", "revokedAt");

-- CreateIndex
CREATE INDEX "AdminTrustedDevice_expiresAt_idx" ON "AdminTrustedDevice"("expiresAt");

-- AddForeignKey
ALTER TABLE "AdminTrustedDevice" ADD CONSTRAINT "AdminTrustedDevice_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
