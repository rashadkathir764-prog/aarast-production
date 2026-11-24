-- RA-BE-178: erasing an account erased other people's records. A member's
-- messages went with his account by cascade, out of the owner's
-- conversations; they now stay, with no author.
ALTER TABLE "ChatMessage" DROP CONSTRAINT "ChatMessage_senderUserId_fkey";
ALTER TABLE "ChatMessage" ALTER COLUMN "senderUserId" DROP NOT NULL;
ALTER TABLE "ChatMessage" ADD CONSTRAINT "ChatMessage_senderUserId_fkey" FOREIGN KEY ("senderUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- An erased provider's listing was deleted, and its customers' conversations,
-- offers and bookings with it. The row now stays, emptied of its own data,
-- and this says when its owner was erased.
ALTER TABLE "Provider" ADD COLUMN "erasedAt" TIMESTAMP(3);
