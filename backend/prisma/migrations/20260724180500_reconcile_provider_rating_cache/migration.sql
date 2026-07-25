UPDATE "Provider" AS provider
SET
  "ratingAverage" = aggregate."ratingAverage",
  "ratingCount" = aggregate."ratingCount"
FROM (
  SELECT
    candidate."id" AS "providerId",
    COALESCE(ROUND(AVG(review."rating")::numeric, 2), 0.00) AS "ratingAverage",
    COUNT(review."id")::integer AS "ratingCount"
  FROM "Provider" AS candidate
  LEFT JOIN "ProviderReview" AS review
    ON review."providerId" = candidate."id"
   AND review."status" = 'PUBLISHED'
  GROUP BY candidate."id"
) AS aggregate
WHERE provider."id" = aggregate."providerId"
  AND (
    provider."ratingAverage" IS DISTINCT FROM aggregate."ratingAverage"
    OR provider."ratingCount" IS DISTINCT FROM aggregate."ratingCount"
  );
