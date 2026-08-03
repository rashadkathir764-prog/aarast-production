BEGIN;

SET LOCAL lock_timeout = '15s';

CREATE TABLE "AccountDeletionReceipt" (
  "receiptHash" CHAR(64) NOT NULL,
  "deletedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "AccountDeletionReceipt_pkey" PRIMARY KEY ("receiptHash"),
  CONSTRAINT "AccountDeletionReceipt_hash_check"
    CHECK ("receiptHash" ~ '^[0-9a-f]{64}$')
);

CREATE INDEX "AccountDeletionReceipt_deletedAt_idx"
  ON "AccountDeletionReceipt"("deletedAt");

CREATE FUNCTION "aarast_reject_account_deletion_receipt_mutation"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION 'Account deletion receipts are immutable';
END;
$$;

CREATE TRIGGER "AccountDeletionReceipt_immutable_update"
BEFORE UPDATE ON "AccountDeletionReceipt"
FOR EACH ROW EXECUTE FUNCTION "aarast_reject_account_deletion_receipt_mutation"();

CREATE TRIGGER "AccountDeletionReceipt_immutable_delete"
BEFORE DELETE ON "AccountDeletionReceipt"
FOR EACH ROW EXECUTE FUNCTION "aarast_reject_account_deletion_receipt_mutation"();

COMMIT;
