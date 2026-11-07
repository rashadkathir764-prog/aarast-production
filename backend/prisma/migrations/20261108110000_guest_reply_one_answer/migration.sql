-- A guest's reply is one fact kept in two columns: the owner's form wrote
-- "status", the guest's reply page "attendanceStatus". A form save that wrote
-- only "status", and a plan saved from the phone, left the reply pending, so
-- the guest list and the home read different answers. Every write now keeps
-- both (guest-reply.ts); the rows written before are brought in line here,
-- where the owner's answer is the only one there is.
UPDATE "Guest"
SET "attendanceStatus" = 'CONFIRMED'
WHERE "status" = 'CONFIRMED' AND "attendanceStatus" = 'PENDING';

UPDATE "Guest"
SET "attendanceStatus" = 'DECLINED'
WHERE "status" = 'DECLINED' AND "attendanceStatus" = 'PENDING';
