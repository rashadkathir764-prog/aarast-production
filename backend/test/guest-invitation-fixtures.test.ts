import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { test } from "node:test";
import { buildRsvpMessage, type RsvpMessageInput } from "../src/guests/guest-rsvp.service";
import {
  dueSend,
  type InviteAnswer,
  type InvitationSendKind,
  occasionCounts,
  occasionStanding,
  occasionsToName,
  type SentInvitation,
  toldOccasions,
} from "../src/modules/guests/domain/guest-invitations";

// D116: where a guest stands with each occasion, the counts, what a send
// names and the WhatsApp text, for fixed cases, as the server works them
// out. The phone's twin (`guest_invitations.dart`, `guest_invite_text.dart`)
// must give the same answers on the same cases
// (`guest_invitation_parity_test.dart`): the phone counts the guests tab and
// draws the message's preview without the server. This test fails when the
// committed fixtures drift from the server's rules; regenerate them with
// `WRITE_GUEST_INVITATION_FIXTURES=1 node --test -r ts-node/register test/guest-invitation-fixtures.test.ts`.

const FIXTURES = path.resolve(
  __dirname,
  "../../mobile/test/fixtures/guest_invitation_fixtures.json",
);

const at = (minute: number) => new Date(Date.UTC(2026, 10, 16, 9, minute));

interface StandingCase {
  name: string;
  occasions: Array<{ planEventId: string; version: number }>;
  invites: InviteAnswer[];
  sends: SentInvitation[];
  /** The occasions in scope, all of them when absent. */
  scope?: string[];
}

const answer = (
  planEventId: string,
  attendanceStatus: InviteAnswer["attendanceStatus"] = "PENDING",
  over: Partial<InviteAnswer> = {},
): InviteAnswer => ({
  planEventId,
  attendanceStatus,
  companionsCount: 0,
  respondedAt: attendanceStatus === "PENDING" ? null : at(30),
  answeredVersion: attendanceStatus === "PENDING" ? null : 1,
  ...over,
});

const standingCases: StandingCase[] = [
  {
    name: "never told anything",
    occasions: [
      { planEventId: "wedding", version: 1 },
      { planEventId: "lunch", version: 1 },
    ],
    invites: [answer("wedding"), answer("lunch")],
    sends: [],
  },
  {
    name: "told the wedding, the lunch added after",
    occasions: [
      { planEventId: "wedding", version: 1 },
      { planEventId: "lunch", version: 1 },
    ],
    invites: [answer("wedding"), answer("lunch")],
    sends: [{ kind: "INVITATION", sentAt: at(1), events: [{ planEventId: "wedding", version: 1 }] }],
  },
  {
    name: "told everything, silent",
    occasions: [
      { planEventId: "wedding", version: 1 },
      { planEventId: "lunch", version: 1 },
    ],
    invites: [answer("wedding"), answer("lunch")],
    sends: [
      {
        kind: "INVITATION",
        sentAt: at(1),
        events: [
          { planEventId: "wedding", version: 1 },
          { planEventId: "lunch", version: 1 },
        ],
      },
      { kind: "REMINDER", sentAt: at(9), events: [{ planEventId: "lunch", version: 1 }] },
    ],
  },
  {
    name: "the lunch moved after the guest confirmed it; the wedding declined",
    occasions: [
      { planEventId: "wedding", version: 1 },
      { planEventId: "lunch", version: 2 },
    ],
    invites: [
      answer("wedding", "DECLINED"),
      answer("lunch", "CONFIRMED", { companionsCount: 3 }),
    ],
    sends: [
      {
        kind: "INVITATION",
        sentAt: at(1),
        events: [
          { planEventId: "wedding", version: 1 },
          { planEventId: "lunch", version: 1 },
        ],
      },
    ],
  },
  {
    name: "the wedding moved; told of the old day and silent",
    occasions: [{ planEventId: "wedding", version: 3 }],
    invites: [answer("wedding")],
    sends: [{ kind: "INVITATION", sentAt: at(1), events: [{ planEventId: "wedding", version: 2 }] }],
  },
  {
    name: "answered before versions, never sent from the app",
    occasions: [{ planEventId: "wedding", version: 2 }],
    invites: [answer("wedding", "CONFIRMED", { answeredVersion: null, companionsCount: 1 })],
    sends: [],
  },
  {
    name: "a separate invitation for the lunch only",
    occasions: [
      { planEventId: "wedding", version: 1 },
      { planEventId: "lunch", version: 1 },
    ],
    invites: [answer("wedding"), answer("lunch")],
    sends: [{ kind: "INVITATION", sentAt: at(1), events: [{ planEventId: "wedding", version: 1 }] }],
    scope: ["lunch"],
  },
];

const KINDS: InvitationSendKind[] = ["INVITATION", "ADDITION", "CHANGE", "REMINDER"];

function standingAnswers(entry: StandingCase) {
  const told = toldOccasions(entry.sends);
  const standings = entry.occasions.map((occasion) => {
    const invite = entry.invites.find((candidate) => candidate.planEventId === occasion.planEventId)!;
    return {
      planEventId: occasion.planEventId,
      standing: occasionStanding(invite, occasion, told.get(occasion.planEventId)),
      companionsCount: invite.companionsCount,
    };
  });
  const scope = entry.scope
    ? standings.filter((standing) => entry.scope!.includes(standing.planEventId))
    : standings;
  return {
    told: [...told.entries()].map(([planEventId, value]) => ({
      planEventId,
      version: value.version,
      at: value.at.toISOString(),
      remindedAt: value.remindedAt?.toISOString() ?? null,
    })),
    standings: standings.map(({ planEventId, standing }) => ({ planEventId, standing })),
    counts: Object.fromEntries(
      standings.map((standing) => [standing.planEventId, occasionCounts([standing])]),
    ),
    due: dueSend(scope, told.size > 0),
    names: Object.fromEntries(KINDS.map((kind) => [kind, occasionsToName(kind, scope)])),
  };
}

const wedding = {
  label: "العرس",
  isWedding: true,
  date: new Date(Date.UTC(2026, 10, 30)),
  timeSlot: "AFTER_ISHA" as const,
  exactTime: null,
  placeLabel: "قاعة ذو ريدان، صنعاء",
  address: null,
  mapUrl: "https://maps.app.goo.gl/K1xShZD5d9zSEoZu9",
};
const lunch = {
  label: "الغداء",
  isWedding: false,
  date: new Date(Date.UTC(2026, 10, 30)),
  timeSlot: "DHUHR" as const,
  exactTime: null,
  placeLabel: "بيت العريس",
  address: "حدة، جوار جامع النور",
  mapUrl: null,
};
const samra = {
  label: "السمرة",
  isWedding: false,
  date: new Date(Date.UTC(2026, 10, 27)),
  timeSlot: "EXACT" as const,
  exactTime: "20:30",
  placeLabel: null,
  address: null,
  mapUrl: "https://maps.app.goo.gl/samra",
};
const base = {
  guestName: "ياسر",
  planTitle: "عرس رضوان",
  url: "https://3.121.198.183/rsvp/AAAA",
};

interface MessageCase {
  name: string;
  input: RsvpMessageInput;
}

const messageCases: MessageCase[] = [
  {
    name: "the wedding alone, no card",
    input: { ...base, occasions: [wedding] },
  },
  {
    name: "three occasions, the host and the words",
    input: {
      ...base,
      persona: "GROOM",
      card: { hostLine: "صالح ناصر", freeText: "ارحبوا وحيّاكم الله" },
      occasions: [wedding, samra, lunch],
    },
  },
  {
    name: "a bride's card",
    input: {
      ...base,
      guestName: "أم سلمى",
      persona: "BRIDE",
      card: { hostLine: "أم رضوان", freeText: null },
      occasions: [wedding],
    },
  },
  {
    name: "an invitation of its own for the lunch",
    input: { ...base, card: { hostLine: "صالح ناصر", freeText: null }, occasions: [lunch] },
  },
  { name: "one more occasion", input: { ...base, kind: "ADDITION", occasions: [lunch, samra] } },
  { name: "a change", input: { ...base, kind: "CHANGE", occasions: [lunch] } },
  { name: "a reminder, no answer yet", input: { ...base, kind: "REMINDER", occasions: [wedding] } },
  {
    name: "a reminder to a guest coming",
    input: { ...base, kind: "REMINDER", confirmed: true, occasions: [wedding, lunch] },
  },
  {
    name: "too long: the map links stay behind the link",
    input: {
      ...base,
      occasions: Array.from({ length: 12 }, (_, index) => ({
        ...samra,
        label: `مناسبة ${index + 1}`,
        placeLabel: `مكان طويل الاسم رقم ${index + 1} في صنعاء القديمة`,
        address: `شارع رقم ${index + 1}، جوار الجامع الكبير، بعد الدوار الثاني`,
        mapUrl: `https://maps.app.goo.gl/${"x".repeat(40)}${index + 1}`,
      })),
    },
  },
];

function serialisedInput(input: RsvpMessageInput) {
  return {
    ...input,
    occasions: input.occasions.map((occasion) => ({
      ...occasion,
      date: occasion.date ? occasion.date.toISOString().slice(0, 10) : null,
    })),
  };
}

function fixtures() {
  return {
    standings: standingCases.map((entry) => ({
      name: entry.name,
      input: {
        occasions: entry.occasions,
        invites: entry.invites.map((invite) => ({
          ...invite,
          respondedAt: invite.respondedAt?.toISOString() ?? null,
        })),
        sends: entry.sends.map((send) => ({ ...send, sentAt: send.sentAt.toISOString() })),
        scope: entry.scope ?? null,
      },
      answer: standingAnswers(entry),
    })),
    messages: messageCases.map((entry) => ({
      name: entry.name,
      input: serialisedInput(entry.input),
      text: buildRsvpMessage(entry.input),
    })),
  };
}

test("the phone's guest invitation fixtures are the server's answers", () => {
  const expected = `${JSON.stringify(fixtures(), null, 2)}\n`;
  if (process.env.WRITE_GUEST_INVITATION_FIXTURES === "1") {
    writeFileSync(FIXTURES, expected);
  }
  assert.equal(
    readFileSync(FIXTURES, "utf8").replace(/\r\n/g, "\n"),
    expected,
    "mobile/test/fixtures/guest_invitation_fixtures.json is stale (see the comment at the top)",
  );
});

test("the cases mean what they are named for", () => {
  const answers = fixtures().standings.map((entry) => entry.answer);
  assert.equal(answers[0].due, "INVITATION");
  assert.deepEqual(answers[1].names.ADDITION, ["lunch"]);
  assert.equal(answers[1].due, "ADDITION");
  assert.equal(answers[2].due, "REMINDER");
  assert.equal(answers[2].told.find((entry) => entry.planEventId === "lunch")?.remindedAt, at(9).toISOString());
  assert.deepEqual(
    answers[3].standings.map((entry) => entry.standing),
    ["DECLINED", "CONFIRMED_OLD"],
  );
  assert.equal(answers[3].due, "CHANGE");
  assert.equal(answers[3].counts.lunch.companions, 3);
  assert.equal(answers[4].standings[0].standing, "TOLD_OLD");
  assert.equal(answers[5].standings[0].standing, "CONFIRMED");
  assert.equal(answers[6].due, "ADDITION");
  assert.deepEqual(answers[6].names.INVITATION, ["lunch"]);

  const texts = fixtures().messages.map((entry) => entry.text);
  assert.ok(texts[1].indexOf(base.url) < texts[1].indexOf("maps.app"));
  assert.match(texts[2], /تتشرف أم رضوان بدعوتكن لحضور/);
  assert.match(texts[3], /لحضور الغداء في عرس رضوان\./);
  assert.doesNotMatch(texts[8], /maps\.app/);
});
