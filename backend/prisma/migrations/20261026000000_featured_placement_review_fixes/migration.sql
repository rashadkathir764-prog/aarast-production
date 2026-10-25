-- B-43: the independent review's fixes of featured placement (D54).
--
-- 1. The start notice: a placement booked for a later day tells the
--    provider once when it starts (the hourly job). A placement recorded to
--    start at once was told by the grant's own notice. Those start at the
--    moment they were recorded; a booked one starts at a Sana'a midnight
--    (21:00 UTC the day before), so the ones already told are the ones whose
--    start is not a Sana'a midnight.
ALTER TABLE "ProviderFeaturedPeriod" ADD COLUMN "startNoticeAt" TIMESTAMP(3);

UPDATE "ProviderFeaturedPeriod"
SET "startNoticeAt" = "startsAt"
WHERE "startsAt" <> date_trunc('day', "startsAt" + INTERVAL '3 hours') - INTERVAL '3 hours';

-- 2. One provider's periods that nobody ended never overlap, in the
--    database too: the provider's row lock serialises the grants, and this
--    constraint refuses an overlap from any other path. btree_gist is a
--    trusted extension (PostgreSQL 13+), so the database owner that applies
--    migrations may create it, as it created pgcrypto.
CREATE EXTENSION IF NOT EXISTS "btree_gist";

ALTER TABLE "ProviderFeaturedPeriod"
  ADD CONSTRAINT "ProviderFeaturedPeriod_no_overlap"
  EXCLUDE USING gist ("providerId" WITH =, tsrange("startsAt", "endsAt") WITH &&)
  WHERE ("endedAt" IS NULL);

-- 3. One source of "featured": the provider's placement. A service's own
--    isFeatured flag (the admin «تمييز» button) only moved a service up its
--    provider's list and the services search; it goes. Services now read
--    newest first on a provider's page and cheapest first in the search.
ALTER TABLE "ProviderService" DROP COLUMN "isFeatured";
