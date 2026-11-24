-- RA-BE-161 (Q-41, D124): the planning assistant's consent is the account's
-- stored record with its date, not a flag the phone sends with each
-- question. No account has a record yet: everyone is asked once more, and
-- a partner's question carries the plan's money only once its owner has
-- agreed.
ALTER TABLE "User" ADD COLUMN "assistantConsentAt" TIMESTAMP(3);
