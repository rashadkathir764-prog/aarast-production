-- RefreshToken.userAgent and RefreshToken.ip were provisioned for a "my
-- connected devices" feature that was never built and were never written by
-- any code path. Dropping them keeps the schema honest ("store only what we
-- use") and avoids retaining request IP as dormant personal data.

-- AlterTable
ALTER TABLE "RefreshToken" DROP COLUMN "ip",
DROP COLUMN "userAgent";
