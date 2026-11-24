-- RA-MO-364, RA-BE-191: a provider's logo and cover are kept with two smaller
-- copies (480px for cards and lists, 1080px for a screen-wide view), made
-- when the image is verified. A logo or cover saved before them has none and
-- keeps null; the app draws the original, decoded at the size it is shown.
ALTER TABLE "Provider" ADD COLUMN "logoThumbUrl" TEXT;
ALTER TABLE "Provider" ADD COLUMN "logoMediumUrl" TEXT;
ALTER TABLE "Provider" ADD COLUMN "coverThumbUrl" TEXT;
ALTER TABLE "Provider" ADD COLUMN "coverMediumUrl" TEXT;
