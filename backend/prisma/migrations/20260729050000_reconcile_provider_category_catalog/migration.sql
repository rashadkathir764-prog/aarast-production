-- Reconcile production databases where the original reference catalog existed
-- before deterministic IDs were introduced. Slugs, not IDs, are the stable
-- identity because the production bootstrap historically generated UUIDs.
WITH desired (
    "slug",
    "nameAr",
    "nameEn",
    "icon",
    "showForGroom",
    "showForBride",
    "sortOrder"
) AS (
    VALUES
        ('wedding-halls', 'صالة', 'Wedding Hall', 'hall', true, true, 10),
        ('photography', 'تصوير', 'Photography', 'camera', true, true, 20),
        ('catering', 'وجبات', 'Meals', 'catering', true, true, 30),
        ('stage-decor', 'كوشة', 'Wedding Stage', 'stage', false, true, 130),
        ('dresses', 'فستان', 'Wedding Dress', 'dress', false, true, 150),
        ('sound-lighting', 'صوتيات', 'Audio', 'audio', true, true, 40),
        ('clothing', 'ملبوسات', 'Clothing', 'clothing', true, true, 50),
        ('lighting', 'إضاءة', 'Lighting', 'lighting', true, true, 60),
        ('soft-drinks', 'ببس', 'Soft Drinks', 'drinks', true, true, 70),
        ('wedding-giveaways', 'توزيعات', 'Wedding Giveaways', 'gift', true, true, 80),
        ('invitations', 'دعوات', 'Invitations', 'invitation', true, true, 90),
        ('wedding-car', 'سيارة', 'Wedding Car', 'car', true, true, 100),
        ('wedding-coordination', 'تنسيق وتنظيم', 'Wedding Coordination', 'coordination', true, true, 110),
        ('other', 'أخرى', 'Other', 'more', true, true, 120),
        ('decoration', 'زينة', 'Decoration', 'decor', false, true, 140),
        ('makeup', 'مكياج', 'Makeup', 'makeup', false, true, 160),
        ('hair-styling', 'كوافير', 'Hair Styling', 'hair', false, true, 170),
        ('henna', 'نقاشة', 'Henna Artist', 'henna', false, true, 180),
        ('gold', 'ذهب', 'Gold', 'gold', false, true, 190),
        ('accessories', 'إكسسوارات', 'Accessories', 'accessories', false, true, 200),
        ('perfumes', 'عطور', 'Perfumes', 'perfume', false, true, 210),
        ('flowers', 'ورد', 'Flowers', 'flower', false, true, 220),
        ('photo-session', 'جلسة تصوير', 'Photo Session', 'photo-session', false, true, 230),
        ('wedding-procession', 'زفة', 'Wedding Procession', 'procession', false, true, 240),
        ('female-singer', 'فنانة', 'Female Singer', 'singer', false, true, 250),
        ('female-vocalist', 'منشدة', 'Female Vocalist', 'vocalist', false, true, 260),
        ('women-band', 'فرقة نسائية', 'Women Band', 'band', false, true, 270),
        ('dance-troupe', 'فرقة رقص', 'Dance Troupe', 'dance', false, true, 280),
        ('male-singer', 'فنان', 'Male Singer', 'singer', true, false, 290),
        ('male-vocalist', 'منشد', 'Male Vocalist', 'vocalist', true, false, 300),
        ('mizmar-folk-band', 'مزمار', 'Mizmar', 'folk-band', true, false, 310),
        ('mabra', 'مبرع', 'Traditional Dancer', 'dance', true, false, 320),
        ('qarih', 'قريح', 'Qarih', 'traditional', true, false, 330),
        ('water', 'ماء', 'Water', 'water', true, false, 340),
        ('refrigerators', 'ثلاجة', 'Refrigerator', 'refrigerator', true, false, 350),
        ('promotional-bags', 'علاقيات دعاية', 'Promotional Bags', 'bag', true, false, 360),
        ('qat', 'قات', 'Qat', 'leaf', true, false, 370),
        ('barber', 'حلاقة', 'Barber', 'barber', true, false, 380),
        ('security-entry', 'أمن وتنظيم دخول', 'Security And Entry', 'security', true, false, 390)
)
UPDATE "ProviderCategory" AS category
SET
    "nameAr" = desired."nameAr",
    "nameEn" = desired."nameEn",
    "icon" = desired."icon",
    "showForGroom" = desired."showForGroom",
    "showForBride" = desired."showForBride",
    "isActive" = true,
    "sortOrder" = desired."sortOrder",
    "updatedAt" = CURRENT_TIMESTAMP
FROM desired
WHERE category."slug" = desired."slug";

-- Preserve provider and service relationships before hiding duplicate legacy
-- rows created by the older Arabic-slug bootstrap.
WITH category_map ("legacySlug", "canonicalSlug") AS (
    VALUES
        ('مراقصة', 'dance-troupe'),
        ('صالة', 'wedding-halls'),
        ('كوشة', 'stage-decor'),
        ('زينة', 'decoration'),
        ('فنان', 'male-singer'),
        ('منشد', 'male-vocalist'),
        ('مزمار', 'mizmar-folk-band'),
        ('مبرع', 'mabra')
)
UPDATE "Provider" AS provider
SET
    "primaryCategoryId" = canonical.id,
    "updatedAt" = CURRENT_TIMESTAMP
FROM category_map
JOIN "ProviderCategory" AS legacy
  ON legacy.slug = category_map."legacySlug"
JOIN "ProviderCategory" AS canonical
  ON canonical.slug = category_map."canonicalSlug"
WHERE provider."primaryCategoryId" = legacy.id;

WITH category_map ("legacySlug", "canonicalSlug") AS (
    VALUES
        ('مراقصة', 'dance-troupe'),
        ('صالة', 'wedding-halls'),
        ('كوشة', 'stage-decor'),
        ('زينة', 'decoration'),
        ('فنان', 'male-singer'),
        ('منشد', 'male-vocalist'),
        ('مزمار', 'mizmar-folk-band'),
        ('مبرع', 'mabra')
)
UPDATE "ProviderService" AS service
SET
    "categoryId" = canonical.id,
    "updatedAt" = CURRENT_TIMESTAMP
FROM category_map
JOIN "ProviderCategory" AS legacy
  ON legacy.slug = category_map."legacySlug"
JOIN "ProviderCategory" AS canonical
  ON canonical.slug = category_map."canonicalSlug"
WHERE service."categoryId" = legacy.id;

UPDATE "ProviderCategory"
SET
    "isActive" = false,
    "updatedAt" = CURRENT_TIMESTAMP
WHERE "slug" IN ('مراقصة', 'صالة', 'كوشة', 'زينة', 'فنان', 'منشد', 'مزمار', 'مبرع');
