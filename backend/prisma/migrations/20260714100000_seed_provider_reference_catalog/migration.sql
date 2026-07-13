-- Fresh environments need selectable provider references before any account
-- can submit a provider application. These inserts are deliberately additive:
-- an existing catalog managed by admins is never renamed or reactivated.
INSERT INTO "City" (
    "id",
    "nameAr",
    "nameEn",
    "countryCode",
    "isActive",
    "sortOrder",
    "createdAt",
    "updatedAt"
)
VALUES
    ('a1000000-0000-4000-8000-000000000001', 'صنعاء', 'Sanaa', 'YE', true, 10, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('a1000000-0000-4000-8000-000000000002', 'عدن', 'Aden', 'YE', true, 20, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('a1000000-0000-4000-8000-000000000003', 'تعز', 'Taiz', 'YE', true, 30, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('a1000000-0000-4000-8000-000000000004', 'إب', 'Ibb', 'YE', true, 40, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('a1000000-0000-4000-8000-000000000005', 'الحديدة', 'Hodeidah', 'YE', true, 50, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('a1000000-0000-4000-8000-000000000006', 'المكلا', 'Mukalla', 'YE', true, 60, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT ("nameAr", "countryCode") DO NOTHING;

INSERT INTO "ProviderCategory" (
    "id",
    "nameAr",
    "nameEn",
    "slug",
    "icon",
    "isActive",
    "sortOrder",
    "createdAt",
    "updatedAt"
)
VALUES
    ('b2000000-0000-4000-8000-000000000001', 'الصالات', 'Wedding Halls', 'wedding-halls', 'hall', true, 10, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000002', 'التصوير', 'Photography', 'photography', 'camera', true, 20, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000003', 'الضيافة والعشاء', 'Catering', 'catering', 'catering', true, 30, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000004', 'الكوشة والديكور', 'Stage And Decor', 'stage-decor', 'decor', true, 40, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000005', 'الفساتين', 'Dresses', 'dresses', 'dress', true, 50, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000006', 'الصوت والإضاءة', 'Sound And Lighting', 'sound-lighting', 'lighting', true, 60, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT ("slug") DO NOTHING;
