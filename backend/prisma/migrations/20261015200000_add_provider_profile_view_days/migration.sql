-- CreateTable
CREATE TABLE "ProviderProfileViewDay" (
    "providerId" TEXT NOT NULL,
    "day" DATE NOT NULL,
    "views" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "ProviderProfileViewDay_pkey" PRIMARY KEY ("providerId","day")
);

-- AddForeignKey
ALTER TABLE "ProviderProfileViewDay" ADD CONSTRAINT "ProviderProfileViewDay_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "Provider"("id") ON DELETE CASCADE ON UPDATE CASCADE;
