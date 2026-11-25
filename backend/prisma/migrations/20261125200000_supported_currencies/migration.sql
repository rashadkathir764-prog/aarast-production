-- RA-BE-149 (D124): the server takes only the product's three currencies
-- (YER, SAR, USD). A plan, price or offer already saved in another one would
-- be stuck: every later save repeats its currency and gets a 400, and a phone's
-- queued change waits for the user to delete it (D85). The phone has only ever
-- offered these three, so no row is expected to hold another; this makes it
-- certain. An amount cannot be moved to another currency without a rate, so no
-- row is changed here: a row in another currency stops the migration, named,
-- for a person to settle, and the CHECKs then keep the database to the list.

DO $$
DECLARE
  rule record;
  bad bigint;
  sample text;
BEGIN
  FOR rule IN
    SELECT * FROM (VALUES
      ('WeddingPlan'),
      ('ProviderService'),
      ('ProviderPackage'),
      ('QuoteOffer'),
      ('QuoteOfferVersion')
    ) AS checked(tbl)
  LOOP
    EXECUTE format(
      'SELECT count(*) FROM %I WHERE "currency" NOT IN (''YER'', ''SAR'', ''USD'')',
      rule.tbl
    ) INTO bad;
    IF bad > 0 THEN
      EXECUTE format(
        'SELECT string_agg("id"::text || '' ('' || "currency" || '')'', '', '') FROM (SELECT "id", "currency" FROM %I WHERE "currency" NOT IN (''YER'', ''SAR'', ''USD'') ORDER BY "id" LIMIT 5) AS first_rows',
        rule.tbl
      ) INTO sample;
      RAISE EXCEPTION
        'RA-BE-149: % row(s) of "%" hold a currency outside YER, SAR and USD. No row is changed by this migration; settle them by hand and run it again. First ids: %',
        bad, rule.tbl, sample;
    END IF;
  END LOOP;
END
$$;

ALTER TABLE "WeddingPlan"
  ADD CONSTRAINT "WeddingPlan_currency_supported" CHECK ("currency" IN ('YER', 'SAR', 'USD'));

ALTER TABLE "ProviderService"
  ADD CONSTRAINT "ProviderService_currency_supported" CHECK ("currency" IN ('YER', 'SAR', 'USD'));

ALTER TABLE "ProviderPackage"
  ADD CONSTRAINT "ProviderPackage_currency_supported" CHECK ("currency" IN ('YER', 'SAR', 'USD'));

ALTER TABLE "QuoteOffer"
  ADD CONSTRAINT "QuoteOffer_currency_supported" CHECK ("currency" IN ('YER', 'SAR', 'USD'));

ALTER TABLE "QuoteOfferVersion"
  ADD CONSTRAINT "QuoteOfferVersion_currency_supported" CHECK ("currency" IN ('YER', 'SAR', 'USD'));
