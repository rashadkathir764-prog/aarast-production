-- Provider categories remain one shared catalog. These flags only control
-- whether a category is discoverable inside groom and bride plan contexts.
ALTER TABLE "ProviderCategory"
ADD COLUMN "showForGroom" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN "showForBride" BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX "ProviderCategory_showForGroom_isActive_sortOrder_idx"
ON "ProviderCategory"("showForGroom", "isActive", "sortOrder");

CREATE INDEX "ProviderCategory_showForBride_isActive_sortOrder_idx"
ON "ProviderCategory"("showForBride", "isActive", "sortOrder");

-- Normalize the six immutable bootstrap rows without touching custom rows that
-- may have been created by administrators.
UPDATE "ProviderCategory"
SET
    "nameAr" = 'صالة',
    "nameEn" = 'Wedding Hall',
    "icon" = 'hall',
    "showForGroom" = true,
    "showForBride" = true,
    "sortOrder" = 10,
    "updatedAt" = CURRENT_TIMESTAMP
WHERE "id" = 'b2000000-0000-4000-8000-000000000001'
  AND "slug" = 'wedding-halls';

UPDATE "ProviderCategory"
SET
    "nameAr" = 'تصوير',
    "nameEn" = 'Photography',
    "icon" = 'camera',
    "showForGroom" = true,
    "showForBride" = true,
    "sortOrder" = 20,
    "updatedAt" = CURRENT_TIMESTAMP
WHERE "id" = 'b2000000-0000-4000-8000-000000000002'
  AND "slug" = 'photography';

UPDATE "ProviderCategory"
SET
    "nameAr" = 'وجبات',
    "nameEn" = 'Meals',
    "icon" = 'catering',
    "showForGroom" = true,
    "showForBride" = true,
    "sortOrder" = 30,
    "updatedAt" = CURRENT_TIMESTAMP
WHERE "id" = 'b2000000-0000-4000-8000-000000000003'
  AND "slug" = 'catering';

UPDATE "ProviderCategory"
SET
    "nameAr" = 'كوشة',
    "nameEn" = 'Wedding Stage',
    "icon" = 'stage',
    "showForGroom" = false,
    "showForBride" = true,
    "sortOrder" = 130,
    "updatedAt" = CURRENT_TIMESTAMP
WHERE "id" = 'b2000000-0000-4000-8000-000000000004'
  AND "slug" = 'stage-decor';

UPDATE "ProviderCategory"
SET
    "nameAr" = 'فستان',
    "nameEn" = 'Wedding Dress',
    "icon" = 'dress',
    "showForGroom" = false,
    "showForBride" = true,
    "sortOrder" = 150,
    "updatedAt" = CURRENT_TIMESTAMP
WHERE "id" = 'b2000000-0000-4000-8000-000000000005'
  AND "slug" = 'dresses';

UPDATE "ProviderCategory"
SET
    "nameAr" = 'صوتيات',
    "nameEn" = 'Audio',
    "icon" = 'audio',
    "showForGroom" = true,
    "showForBride" = true,
    "sortOrder" = 40,
    "updatedAt" = CURRENT_TIMESTAMP
WHERE "id" = 'b2000000-0000-4000-8000-000000000006'
  AND "slug" = 'sound-lighting';

-- Additive market catalog. Each row describes what the customer requests;
-- provider service titles and tags keep the flexible specialization details.
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
    ('b2000000-0000-4000-8000-000000000007', 'ملبوسات', 'Clothing', 'clothing', 'clothing', true, true, true, 50, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000008', 'إضاءة', 'Lighting', 'lighting', 'lighting', true, true, true, 60, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000009', 'ببس', 'Soft Drinks', 'soft-drinks', 'drinks', true, true, true, 70, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000010', 'توزيعات', 'Wedding Giveaways', 'wedding-giveaways', 'gift', true, true, true, 80, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000011', 'دعوات', 'Invitations', 'invitations', 'invitation', true, true, true, 90, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000012', 'سيارة', 'Wedding Car', 'wedding-car', 'car', true, true, true, 100, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000013', 'تنسيق وتنظيم', 'Wedding Coordination', 'wedding-coordination', 'coordination', true, true, true, 110, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000014', 'أخرى', 'Other', 'other', 'more', true, true, true, 120, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),

    ('b2000000-0000-4000-8000-000000000015', 'زينة', 'Decoration', 'decoration', 'decor', false, true, true, 140, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000016', 'مكياج', 'Makeup', 'makeup', 'makeup', false, true, true, 160, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000017', 'كوافير', 'Hair Styling', 'hair-styling', 'hair', false, true, true, 170, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000018', 'نقاشة', 'Henna Artist', 'henna', 'henna', false, true, true, 180, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000019', 'ذهب', 'Gold', 'gold', 'gold', false, true, true, 190, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000020', 'إكسسوارات', 'Accessories', 'accessories', 'accessories', false, true, true, 200, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000021', 'عطور', 'Perfumes', 'perfumes', 'perfume', false, true, true, 210, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000022', 'ورد', 'Flowers', 'flowers', 'flower', false, true, true, 220, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000023', 'جلسة تصوير', 'Photo Session', 'photo-session', 'photo-session', false, true, true, 230, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000024', 'زفة', 'Wedding Procession', 'wedding-procession', 'procession', false, true, true, 240, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000025', 'فنانة', 'Female Singer', 'female-singer', 'singer', false, true, true, 250, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000026', 'منشدة', 'Female Vocalist', 'female-vocalist', 'vocalist', false, true, true, 260, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000027', 'فرقة نسائية', 'Women Band', 'women-band', 'band', false, true, true, 270, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000028', 'فرقة رقص', 'Dance Troupe', 'dance-troupe', 'dance', false, true, true, 280, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),

    ('b2000000-0000-4000-8000-000000000029', 'فنان', 'Male Singer', 'male-singer', 'singer', true, false, true, 290, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000030', 'منشد', 'Male Vocalist', 'male-vocalist', 'vocalist', true, false, true, 300, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000031', 'مزمار وفرقة شعبية', 'Mizmar And Folk Band', 'mizmar-folk-band', 'folk-band', true, false, true, 310, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000032', 'مبرع', 'Traditional Dancer', 'mabra', 'dance', true, false, true, 320, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000033', 'قريح', 'Qarih', 'qarih', 'traditional', true, false, true, 330, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000034', 'ماء', 'Water', 'water', 'water', true, false, true, 340, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000035', 'ثلاجات', 'Refrigerators', 'refrigerators', 'refrigerator', true, false, true, 350, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000036', 'علاقيات دعاية', 'Promotional Bags', 'promotional-bags', 'bag', true, false, true, 360, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000037', 'قات', 'Qat', 'qat', 'leaf', true, false, true, 370, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000038', 'حلاقة', 'Barber', 'barber', 'barber', true, false, true, 380, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
    ('b2000000-0000-4000-8000-000000000039', 'أمن وتنظيم دخول', 'Security And Entry', 'security-entry', 'security', true, false, true, 390, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
ON CONFLICT ("slug") DO NOTHING;
