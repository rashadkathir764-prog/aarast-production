-- Q-52 (أ, D124), RA-OP-21: the public site's page asks an account's deletion
-- without the app. The registered number is proven with a WhatsApp code of
-- its own purpose, which asks the deletion (the same 30 days, taken back by
-- signing in) and nothing else. Additive.

-- AlterEnum
ALTER TYPE "OtpPurpose" ADD VALUE 'ACCOUNT_DELETION_WEB';
