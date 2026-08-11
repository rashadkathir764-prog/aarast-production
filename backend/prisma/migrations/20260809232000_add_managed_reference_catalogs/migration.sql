CREATE TYPE "AdministrativeLocalityType" AS ENUM (
    'AREA',
    'ISOLATION',
    'NEIGHBORHOOD',
    'ZONE'
);

CREATE TABLE "AdministrativeLocality" (
    "id" TEXT NOT NULL,
    "districtId" TEXT NOT NULL,
    "parentId" TEXT,
    "code" TEXT NOT NULL,
    "type" "AdministrativeLocalityType" NOT NULL,
    "nameAr" TEXT NOT NULL,
    "nameEn" TEXT,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "AdministrativeLocality_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ReferenceCatalog" (
    "id" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "nameAr" TEXT NOT NULL,
    "description" TEXT,
    "version" INTEGER NOT NULL DEFAULT 0,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "ReferenceCatalog_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ReferenceCatalogItem" (
    "id" TEXT NOT NULL,
    "catalogId" TEXT NOT NULL,
    "key" TEXT NOT NULL,
    "currentRevision" INTEGER NOT NULL DEFAULT 0,
    "publishedRevision" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "ReferenceCatalogItem_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ReferenceCatalogItemRevision" (
    "id" TEXT NOT NULL,
    "itemId" TEXT NOT NULL,
    "revision" INTEGER NOT NULL,
    "groupKey" TEXT,
    "groupNameAr" TEXT,
    "groupSubtitleAr" TEXT,
    "nameAr" TEXT NOT NULL,
    "nameEn" TEXT,
    "icon" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "showForGroom" BOOLEAN NOT NULL DEFAULT true,
    "showForBride" BOOLEAN NOT NULL DEFAULT true,
    "showForCustomer" BOOLEAN NOT NULL DEFAULT true,
    "showForProvider" BOOLEAN NOT NULL DEFAULT false,
    "isRecommended" BOOLEAN NOT NULL DEFAULT false,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ReferenceCatalogItemRevision_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "AdministrativeLocality_code_key"
ON "AdministrativeLocality"("code");
CREATE UNIQUE INDEX "AdministrativeLocality_districtId_type_nameAr_key"
ON "AdministrativeLocality"("districtId", "type", "nameAr");
CREATE INDEX "AdministrativeLocality_districtId_type_isActive_sortOrder_idx"
ON "AdministrativeLocality"("districtId", "type", "isActive", "sortOrder");
CREATE INDEX "AdministrativeLocality_parentId_isActive_sortOrder_idx"
ON "AdministrativeLocality"("parentId", "isActive", "sortOrder");

CREATE UNIQUE INDEX "ReferenceCatalog_key_key"
ON "ReferenceCatalog"("key");
CREATE INDEX "ReferenceCatalog_isActive_key_idx"
ON "ReferenceCatalog"("isActive", "key");

CREATE UNIQUE INDEX "ReferenceCatalogItem_catalogId_key_key"
ON "ReferenceCatalogItem"("catalogId", "key");
CREATE INDEX "ReferenceCatalogItem_catalogId_publishedRevision_idx"
ON "ReferenceCatalogItem"("catalogId", "publishedRevision");

CREATE UNIQUE INDEX "ReferenceCatalogItemRevision_itemId_revision_key"
ON "ReferenceCatalogItemRevision"("itemId", "revision");
CREATE INDEX "ReferenceCatalogItemRevision_itemId_isActive_idx"
ON "ReferenceCatalogItemRevision"("itemId", "isActive");

ALTER TABLE "AdministrativeLocality"
ADD CONSTRAINT "AdministrativeLocality_districtId_fkey"
FOREIGN KEY ("districtId") REFERENCES "District"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "AdministrativeLocality"
ADD CONSTRAINT "AdministrativeLocality_parentId_fkey"
FOREIGN KEY ("parentId") REFERENCES "AdministrativeLocality"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "ReferenceCatalogItem"
ADD CONSTRAINT "ReferenceCatalogItem_catalogId_fkey"
FOREIGN KEY ("catalogId") REFERENCES "ReferenceCatalog"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "ReferenceCatalogItemRevision"
ADD CONSTRAINT "ReferenceCatalogItemRevision_itemId_fkey"
FOREIGN KEY ("itemId") REFERENCES "ReferenceCatalogItem"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
