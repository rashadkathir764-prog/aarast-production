-- RA-BE-181: the admin's searches read whole tables with
-- `strpos(translate(lower(...)))`, which no index serves. They match the
-- folded text with LIKE now (`aarast_search_fold`, migration
-- 20261125130000), and each column the admin searches whole has a trigram
-- GIN index on its folded text: an account's name, a listing's owner (its
-- name already has `Provider_name_trgm_idx`) and a review's words. The plan's
-- agreement search reads one plan's rows, which its own index narrows, so it
-- needs none. A key of one or two letters has no trigram and is still
-- answered, by a scan. No row is changed.

CREATE INDEX "User_name_trgm_idx" ON "User" USING gin (
  "aarast_search_fold"("name") gin_trgm_ops);
CREATE INDEX "Provider_ownerName_trgm_idx" ON "Provider" USING gin (
  "aarast_search_fold"("ownerName") gin_trgm_ops);
CREATE INDEX "ProviderReview_comment_trgm_idx" ON "ProviderReview" USING gin (
  "aarast_search_fold"("comment") gin_trgm_ops);
