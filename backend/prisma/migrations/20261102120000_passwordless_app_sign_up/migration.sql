-- Sign-up for the app is phone + WhatsApp code only (owner decision). The
-- password is optional and can be set later through the reset-by-code flow,
-- so an application account may have no password hash.
-- "appPasswordConfiguredAt" keeps its column name; Prisma reads it as
-- appAccountActivatedAt (set on every app sign-up, with or without password).
ALTER TABLE "User" ALTER COLUMN "passwordHash" DROP NOT NULL;
