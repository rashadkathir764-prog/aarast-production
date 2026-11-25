-- Q-67 (أ, D127): the owner's history spoke of every participant but the
-- bride partner in the masculine («سجّل» of a mother or a sister), because
-- the server knew no participant's gender. The owner says it when adding a
-- participant: the invite keeps it and the member it becomes carries it.
-- Nullable: rows from before, and invites from an app that does not ask,
-- have none and keep today's default form. Additive.

-- CreateEnum
CREATE TYPE "ParticipantGender" AS ENUM ('MALE', 'FEMALE');

-- AlterTable
ALTER TABLE "PlanInvite" ADD COLUMN "gender" "ParticipantGender";

-- AlterTable
ALTER TABLE "SharedMember" ADD COLUMN "gender" "ParticipantGender";
