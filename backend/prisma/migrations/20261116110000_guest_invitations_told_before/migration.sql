-- D116: the guests told before the send log existed.
--
-- Until D116 a guest's invitation was only a column ("invitationStatus"),
-- and its message named the wedding and the guest's other events. What a
-- guest was told is now read from GuestInvitationSend alone, which starts
-- empty: without this, every guest already invited would read as never
-- invited and be offered the invitation again. One sent invitation is written per
-- such guest, naming the wedding and the events they are invited to at
-- their current version (every version is 1 here), dated when the guest
-- last changed or answered. A guest who already has a send is left alone.

-- The wedding row the sends name: made by the previous migration for the
-- plans then, and here again for any plan made without one since.
INSERT INTO "PlanEvent" ("id", "weddingPlanId", "type", "createdAt", "updatedAt")
SELECT 'wedding_' || plan."id", plan."id", 'WEDDING', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM "WeddingPlan" plan
WHERE NOT EXISTS (
    SELECT 1 FROM "PlanEvent" event
    WHERE event."weddingPlanId" = plan."id" AND event."type" = 'WEDDING'
);

INSERT INTO "GuestInvitationSend" (
    "id", "weddingPlanId", "guestId", "kind", "planEventId", "events",
    "channel", "status", "createdAt", "settledAt"
)
SELECT
    'told_before_' || guest."id",
    guest."weddingPlanId",
    guest."id",
    'INVITATION',
    NULL,
    jsonb_build_array(
        jsonb_build_object('planEventId', wedding."id", 'version', wedding."version")
    ) || COALESCE((
        SELECT jsonb_agg(
            jsonb_build_object('planEventId', event."id", 'version', event."version")
            ORDER BY event."id"
        )
        FROM "GuestEventInvite" invite
        JOIN "PlanEvent" event ON event."id" = invite."planEventId"
        WHERE invite."guestId" = guest."id" AND event."type" <> 'WEDDING'
    ), '[]'::jsonb),
    'WHATSAPP',
    'SENT',
    COALESCE(guest."respondedAt", guest."updatedAt"),
    COALESCE(guest."respondedAt", guest."updatedAt")
FROM "Guest" guest
JOIN "PlanEvent" wedding
    ON wedding."weddingPlanId" = guest."weddingPlanId" AND wedding."type" = 'WEDDING'
WHERE guest."invitationStatus" <> 'NOT_SENT'
  AND NOT EXISTS (
      SELECT 1 FROM "GuestInvitationSend" send WHERE send."guestId" = guest."id"
  );
