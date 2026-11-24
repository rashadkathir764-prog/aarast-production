-- RA-BE-141: a code to the account's current number, the proof that its
-- holder asks a sensitive change from a signed-in session: moving the account
-- to another number (or the password instead), and adding the first
-- password. Issued only to the signed-in account. Additive.

-- AlterEnum
ALTER TYPE "OtpPurpose" ADD VALUE 'CURRENT_PHONE_PROOF';
