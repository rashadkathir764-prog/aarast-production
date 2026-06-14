-- CreateEnum
CREATE TYPE "OtpPurpose" AS ENUM ('REGISTER', 'LOGIN', 'VERIFY_PHONE', 'RESET_PASSWORD');

-- CreateEnum
CREATE TYPE "ProviderStatus" AS ENUM ('PENDING', 'ACTIVE', 'SUSPENDED', 'REJECTED');

-- CreateEnum
CREATE TYPE "ReviewStatus" AS ENUM ('PUBLISHED', 'HIDDEN', 'PENDING');

-- CreateEnum
CREATE TYPE "QuoteRequestStatus" AS ENUM ('SENT', 'VIEWED', 'RESPONDED', 'ACCEPTED', 'REJECTED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "BookingLeadStatus" AS ENUM ('NEW', 'IN_PROGRESS', 'CONFIRMED', 'CANCELLED', 'COMPLETED');

-- AlterTable
ALTER TABLE "User" ADD COLUMN     "avatarUrl" TEXT,
ADD COLUMN     "lastLoginAt" TIMESTAMP(3),
ADD COLUMN     "locale" TEXT NOT NULL DEFAULT 'ar',
ADD COLUMN     "phoneVerifiedAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "WeddingTask" ADD COLUMN     "reminderAt" TIMESTAMP(3),
ADD COLUMN     "taskCategory" TEXT;

-- CreateTable
CREATE TABLE "OtpCode" (
    "id" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "codeHash" TEXT NOT NULL,
    "purpose" "OtpPurpose" NOT NULL,
    "expiresAt" TIMESTAMP(3) NOT NULL,
    "consumedAt" TIMESTAMP(3),
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "maxAttempts" INTEGER NOT NULL DEFAULT 5,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "OtpCode_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "NotificationPreference" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "pushEnabled" BOOLEAN NOT NULL DEFAULT true,
    "smsEnabled" BOOLEAN NOT NULL DEFAULT false,
    "whatsappEnabled" BOOLEAN NOT NULL DEFAULT false,
    "emailEnabled" BOOLEAN NOT NULL DEFAULT false,
    "taskRemindersEnabled" BOOLEAN NOT NULL DEFAULT true,
    "paymentRemindersEnabled" BOOLEAN NOT NULL DEFAULT true,
    "providerMessagesEnabled" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NotificationPreference_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "City" (
    "id" TEXT NOT NULL,
    "nameAr" TEXT NOT NULL,
    "nameEn" TEXT,
    "countryCode" TEXT NOT NULL DEFAULT 'YE',
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "City_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProviderCategory" (
    "id" TEXT NOT NULL,
    "nameAr" TEXT NOT NULL,
    "nameEn" TEXT,
    "slug" TEXT NOT NULL,
    "icon" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ProviderCategory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Provider" (
    "id" TEXT NOT NULL,
    "userId" TEXT,
    "cityId" TEXT NOT NULL,
    "businessName" TEXT NOT NULL,
    "ownerName" TEXT,
    "phone" TEXT NOT NULL,
    "whatsapp" TEXT,
    "email" TEXT,
    "description" TEXT,
    "address" TEXT,
    "latitude" DECIMAL(10,7),
    "longitude" DECIMAL(10,7),
    "logoUrl" TEXT,
    "coverUrl" TEXT,
    "status" "ProviderStatus" NOT NULL DEFAULT 'PENDING',
    "isFeatured" BOOLEAN NOT NULL DEFAULT false,
    "ratingAverage" DECIMAL(3,2) NOT NULL DEFAULT 0,
    "ratingCount" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Provider_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProviderService" (
    "id" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "categoryId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "basePrice" DECIMAL(14,2),
    "priceUnit" TEXT,
    "currency" TEXT NOT NULL DEFAULT 'YER',
    "cityId" TEXT,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "isFeatured" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ProviderService_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProviderServiceImage" (
    "id" TEXT NOT NULL,
    "serviceId" TEXT NOT NULL,
    "imageUrl" TEXT NOT NULL,
    "altText" TEXT,
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ProviderServiceImage_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProviderPackage" (
    "id" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "serviceId" TEXT,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "price" DECIMAL(14,2),
    "currency" TEXT NOT NULL DEFAULT 'YER',
    "items" JSONB,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ProviderPackage_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FavoriteProvider" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FavoriteProvider_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ProviderReview" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "providerId" TEXT NOT NULL,
    "rating" INTEGER NOT NULL,
    "comment" TEXT,
    "status" "ReviewStatus" NOT NULL DEFAULT 'PUBLISHED',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ProviderReview_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "QuoteRequest" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "weddingPlanId" TEXT,
    "providerId" TEXT NOT NULL,
    "serviceId" TEXT,
    "eventDate" TIMESTAMP(3),
    "cityId" TEXT,
    "guestCount" INTEGER,
    "message" TEXT,
    "budgetMin" DECIMAL(14,2),
    "budgetMax" DECIMAL(14,2),
    "status" "QuoteRequestStatus" NOT NULL DEFAULT 'SENT',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "QuoteRequest_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "BookingLead" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "weddingPlanId" TEXT,
    "providerId" TEXT NOT NULL,
    "quoteRequestId" TEXT,
    "title" TEXT NOT NULL,
    "eventDate" TIMESTAMP(3),
    "status" "BookingLeadStatus" NOT NULL DEFAULT 'NEW',
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "BookingLead_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "OtpCode_phone_purpose_consumedAt_idx" ON "OtpCode"("phone", "purpose", "consumedAt");

-- CreateIndex
CREATE INDEX "OtpCode_phone_purpose_expiresAt_idx" ON "OtpCode"("phone", "purpose", "expiresAt");

-- CreateIndex
CREATE UNIQUE INDEX "NotificationPreference_userId_key" ON "NotificationPreference"("userId");

-- CreateIndex
CREATE INDEX "City_isActive_sortOrder_idx" ON "City"("isActive", "sortOrder");

-- CreateIndex
CREATE UNIQUE INDEX "City_nameAr_countryCode_key" ON "City"("nameAr", "countryCode");

-- CreateIndex
CREATE UNIQUE INDEX "ProviderCategory_slug_key" ON "ProviderCategory"("slug");

-- CreateIndex
CREATE INDEX "ProviderCategory_isActive_sortOrder_idx" ON "ProviderCategory"("isActive", "sortOrder");

-- CreateIndex
CREATE UNIQUE INDEX "Provider_userId_key" ON "Provider"("userId");

-- CreateIndex
CREATE INDEX "Provider_status_isFeatured_idx" ON "Provider"("status", "isFeatured");

-- CreateIndex
CREATE INDEX "Provider_cityId_status_idx" ON "Provider"("cityId", "status");

-- CreateIndex
CREATE INDEX "ProviderService_providerId_isActive_idx" ON "ProviderService"("providerId", "isActive");

-- CreateIndex
CREATE INDEX "ProviderService_categoryId_isActive_idx" ON "ProviderService"("categoryId", "isActive");

-- CreateIndex
CREATE INDEX "ProviderService_cityId_isActive_idx" ON "ProviderService"("cityId", "isActive");

-- CreateIndex
CREATE INDEX "ProviderServiceImage_serviceId_sortOrder_idx" ON "ProviderServiceImage"("serviceId", "sortOrder");

-- CreateIndex
CREATE INDEX "ProviderPackage_providerId_isActive_idx" ON "ProviderPackage"("providerId", "isActive");

-- CreateIndex
CREATE INDEX "ProviderPackage_serviceId_isActive_idx" ON "ProviderPackage"("serviceId", "isActive");

-- CreateIndex
CREATE INDEX "FavoriteProvider_providerId_idx" ON "FavoriteProvider"("providerId");

-- CreateIndex
CREATE UNIQUE INDEX "FavoriteProvider_userId_providerId_key" ON "FavoriteProvider"("userId", "providerId");

-- CreateIndex
CREATE INDEX "ProviderReview_providerId_status_idx" ON "ProviderReview"("providerId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "ProviderReview_userId_providerId_key" ON "ProviderReview"("userId", "providerId");

-- CreateIndex
CREATE INDEX "QuoteRequest_userId_status_idx" ON "QuoteRequest"("userId", "status");

-- CreateIndex
CREATE INDEX "QuoteRequest_providerId_status_idx" ON "QuoteRequest"("providerId", "status");

-- CreateIndex
CREATE INDEX "QuoteRequest_weddingPlanId_idx" ON "QuoteRequest"("weddingPlanId");

-- CreateIndex
CREATE INDEX "BookingLead_userId_status_idx" ON "BookingLead"("userId", "status");

-- CreateIndex
CREATE INDEX "BookingLead_providerId_status_idx" ON "BookingLead"("providerId", "status");

-- AddForeignKey
ALTER TABLE "NotificationPreference" ADD CONSTRAINT "NotificationPreference_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Provider" ADD CONSTRAINT "Provider_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Provider" ADD CONSTRAINT "Provider_cityId_fkey" FOREIGN KEY ("cityId") REFERENCES "City"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProviderService" ADD CONSTRAINT "ProviderService_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "Provider"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProviderService" ADD CONSTRAINT "ProviderService_categoryId_fkey" FOREIGN KEY ("categoryId") REFERENCES "ProviderCategory"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProviderService" ADD CONSTRAINT "ProviderService_cityId_fkey" FOREIGN KEY ("cityId") REFERENCES "City"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProviderServiceImage" ADD CONSTRAINT "ProviderServiceImage_serviceId_fkey" FOREIGN KEY ("serviceId") REFERENCES "ProviderService"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProviderPackage" ADD CONSTRAINT "ProviderPackage_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "Provider"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProviderPackage" ADD CONSTRAINT "ProviderPackage_serviceId_fkey" FOREIGN KEY ("serviceId") REFERENCES "ProviderService"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FavoriteProvider" ADD CONSTRAINT "FavoriteProvider_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FavoriteProvider" ADD CONSTRAINT "FavoriteProvider_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "Provider"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProviderReview" ADD CONSTRAINT "ProviderReview_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ProviderReview" ADD CONSTRAINT "ProviderReview_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "Provider"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QuoteRequest" ADD CONSTRAINT "QuoteRequest_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QuoteRequest" ADD CONSTRAINT "QuoteRequest_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QuoteRequest" ADD CONSTRAINT "QuoteRequest_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "Provider"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QuoteRequest" ADD CONSTRAINT "QuoteRequest_serviceId_fkey" FOREIGN KEY ("serviceId") REFERENCES "ProviderService"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "QuoteRequest" ADD CONSTRAINT "QuoteRequest_cityId_fkey" FOREIGN KEY ("cityId") REFERENCES "City"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookingLead" ADD CONSTRAINT "BookingLead_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookingLead" ADD CONSTRAINT "BookingLead_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookingLead" ADD CONSTRAINT "BookingLead_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "Provider"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "BookingLead" ADD CONSTRAINT "BookingLead_quoteRequestId_fkey" FOREIGN KEY ("quoteRequestId") REFERENCES "QuoteRequest"("id") ON DELETE SET NULL ON UPDATE CASCADE;
