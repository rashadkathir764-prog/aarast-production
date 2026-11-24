-- RA-BE-181: three searches read the whole table.
--
-- 1. The marketplace search (providers, and services with their provider's
--    name) matched `strpos(translate(lower(...)))` on every row of the table,
--    which no index can serve. The same folding now lives in one IMMUTABLE
--    function and the searched text in two more, each indexed with a trigram
--    GIN index, and the queries match the folded text with LIKE, which the
--    trigram index answers. The characters folded are the ones
--    src/shared-kernel/text/arabic-search.ts folds (a test keeps them equal);
--    a change to that list is a new migration that rebuilds these indexes.
--    pg_trgm is a trusted extension of the stock PostgreSQL image, created the
--    way btree_gist was (20261026000000).
--
-- 2. A person's invitations by phone (sharing.repository, the invites tied to
--    no account): `normalizedPhone` had only the plan-first index. An index
--    over the open invites alone serves it.

CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- translate() maps FROM[i] to TO[i] and drops every character of FROM past
-- the length of TO, the same as arabicSearchKey() does on the server.
CREATE FUNCTION "aarast_search_fold"(text) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT
AS $$ SELECT translate(lower($1),
  E'\u0622\u0623\u0625\u0671\u0649\u0624\u0626\u0629\u064b\u064c\u064d\u064e\u064f\u0650\u0651\u0652\u0653\u0654\u0655\u0656\u0657\u0658\u0659\u065a\u065b\u065c\u065d\u065e\u065f\u0640\u0670\u0020\u0009\u000a\u000d\u00a0',
  E'\u0627\u0627\u0627\u0627\u064a\u0648\u064a\u0647') $$;

-- Provider: name, owner, description and address, a field apart from the next
-- (chr(1) keeps a key from matching across two fields).
CREATE FUNCTION "aarast_provider_search_text"(text, text, text, text) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$ SELECT "aarast_search_fold"(
  coalesce($1, '') || chr(1) || coalesce($2, '') || chr(1) || coalesce($3, '') || chr(1) || coalesce($4, '')) $$;

-- ProviderService: title and description.
CREATE FUNCTION "aarast_service_search_text"(text, text) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$ SELECT "aarast_search_fold"(coalesce($1, '') || chr(1) || coalesce($2, '')) $$;

CREATE INDEX "Provider_search_text_trgm_idx" ON "Provider" USING gin (
  "aarast_provider_search_text"("businessName", "ownerName", "description", "address") gin_trgm_ops);
CREATE INDEX "Provider_name_trgm_idx" ON "Provider" USING gin (
  "aarast_search_fold"("businessName") gin_trgm_ops);
CREATE INDEX "ProviderService_search_text_trgm_idx" ON "ProviderService" USING gin (
  "aarast_service_search_text"("title", "description") gin_trgm_ops);

-- The invites tied to no account, found by the number alone.
CREATE INDEX "PlanInvite_open_normalizedPhone_idx"
  ON "PlanInvite"("normalizedPhone") WHERE "inviteeUserId" IS NULL;
