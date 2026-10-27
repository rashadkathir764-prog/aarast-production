-- G10 (owner-vision audit 2026-10-27): the apartment, its furniture and the
-- honeymoon had no provider category, and gold was hidden from the groom
-- who buys the شبكة. Slugs are the stable identity; an administrator's
-- later edit of these rows is kept (ON CONFLICT DO NOTHING).
INSERT INTO "ProviderCategory" (
    "id",
    "nameAr",
    "nameEn",
    "slug",
    "icon",
    "showForGroom",
    "showForBride",
    "isActive",
    "sortOrder",
    "createdAt",
    "updatedAt"
)
VALUES
    ('b2000000-0000-4000-8000-000000000040', 'أثاث وتجهيز منزل', 'Furniture And Home', 'furniture-home', 'home', true, true, true, 400, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000041', 'شقق وعقارات', 'Apartments', 'apartments', 'key-round', true, true, true, 410, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000042', 'سفر وشهر عسل', 'Travel And Honeymoon', 'honeymoon-travel', 'plane', true, true, true, 420, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT ("slug") DO NOTHING;

UPDATE "ProviderCategory"
SET
    "showForGroom" = true,
    "updatedAt" = CURRENT_TIMESTAMP
WHERE "slug" = 'gold';
