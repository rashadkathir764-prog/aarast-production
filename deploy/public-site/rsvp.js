(() => {
  "use strict";

  // e05, a guest's personal RSVP link (V1 checklist 4.7): /rsvp/<token>. The
  // page reads the invitation and sends the answer to the same origin, which
  // the edge proxy forwards to the API; no account, no cookies, no form post.

  const $ = (id) => document.getElementById(id);
  const title = $("rsvp-title");
  const greeting = $("rsvp-greeting");
  const inviteLine = $("rsvp-invite-line");
  const details = $("rsvp-details");
  const answer = $("rsvp-answer");
  const status = $("rsvp-status");
  const chips = $("rsvp-companions");
  const yes = $("rsvp-yes");
  const no = $("rsvp-no");

  // «لحالي / +1 / +2 / +3»; a larger number the hosts set stays offered.
  const CHIP_LIMIT = 3;
  let companions = 0;

  const segments = window.location.pathname.split("/").filter(Boolean);
  const token = segments.length === 2 && segments[0] === "rsvp" ? segments[1] : "";
  if (!/^[A-Za-z0-9_-]{43}$/.test(token)) {
    showInvalid();
    return;
  }
  const endpoint = `/api/v1/public/rsvp/${encodeURIComponent(token)}`;

  function showInvalid() {
    greeting.textContent = "";
    title.textContent = "الرابط ما يشتغل";
    inviteLine.textContent = "اطلب من صاحب الدعوة يرسل لك رابط جديد.";
    details.hidden = true;
    answer.hidden = true;
  }

  function weddingDay(value) {
    const [year, month, day] = value.split("-").map(Number);
    return new Date(Date.UTC(year, month - 1, day));
  }

  function formatDay(date) {
    return new Intl.DateTimeFormat("ar", {
      weekday: "long",
      day: "numeric",
      month: "long",
      year: "numeric",
      timeZone: "UTC",
    }).format(date);
  }

  function formatHijri(date) {
    try {
      return new Intl.DateTimeFormat("ar-SA-u-ca-islamic-umalqura-nu-latn", {
        day: "numeric",
        month: "long",
        year: "numeric",
        timeZone: "UTC",
      }).format(date);
    } catch {
      return "";
    }
  }

  function chipLabel(count) {
    return count === 0 ? "لحالي" : `+${count}`;
  }

  function renderChips(max, current) {
    const counts = [];
    for (let count = 0; count <= Math.min(CHIP_LIMIT, max); count += 1) counts.push(count);
    if (current > CHIP_LIMIT && current <= max) counts.push(current);
    chips.replaceChildren(
      ...counts.map((count) => {
        const chip = document.createElement("button");
        chip.type = "button";
        chip.textContent = chipLabel(count);
        // «+2» reads left to right inside the Arabic line.
        if (count > 0) chip.dir = "ltr";
        chip.setAttribute("aria-pressed", String(count === companions));
        chip.addEventListener("click", () => {
          companions = count;
          for (const other of chips.children) {
            other.setAttribute("aria-pressed", String(other === chip));
          }
        });
        return chip;
      }),
    );
  }

  function render(invitation) {
    greeting.textContent = `أهلًا ${invitation.guestName}`;
    title.textContent = invitation.planTitle;
    inviteLine.textContent = "يسعدنا حضورك";
    const day = invitation.weddingDate ? weddingDay(invitation.weddingDate) : null;
    $("rsvp-date-row").hidden = !day;
    if (day) {
      $("rsvp-date").textContent = formatDay(day);
      $("rsvp-hijri").textContent = formatHijri(day);
    }
    $("rsvp-place-row").hidden = !invitation.locationLabel;
    if (invitation.locationLabel) $("rsvp-place").textContent = invitation.locationLabel;
    details.hidden = !day && !invitation.locationLabel;

    companions = invitation.companionsCount || 0;
    renderChips(invitation.maxCompanions, companions);
    answer.hidden = false;
    status.className = "rsvp-status";
    if (invitation.attendanceStatus === "CONFIRMED") {
      status.className = "rsvp-status rsvp-done";
      const withWhom = companions > 0 ? ` مع ${companions}` : "";
      status.textContent = `سجّلنا حضورك${withWhom}. تقدر تغيّر ردك متى ما تشتي.`;
    } else if (invitation.attendanceStatus === "DECLINED") {
      status.textContent = "سجّلنا اعتذارك. تقدر تغيّر ردك متى ما تشتي.";
    } else {
      status.textContent = "";
    }
  }

  async function load() {
    try {
      const response = await fetch(endpoint, { headers: { Accept: "application/json" } });
      if (response.status === 404) return showInvalid();
      if (!response.ok) throw new Error(String(response.status));
      render(await response.json());
    } catch {
      greeting.textContent = "";
      title.textContent = "ما قدرنا نفتح الدعوة";
      inviteLine.textContent = "تأكد من النت وافتح الرابط مرة ثانية.";
    }
  }

  async function send(attendance) {
    yes.disabled = true;
    no.disabled = true;
    status.className = "rsvp-status";
    status.textContent = "نرسل ردك…";
    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify(
          attendance === "CONFIRMED"
            ? { attendance, companionsCount: companions }
            : { attendance },
        ),
      });
      if (response.status === 404) return showInvalid();
      if (response.status === 429) throw new Error("rate");
      if (!response.ok) throw new Error(String(response.status));
      render(await response.json());
    } catch (error) {
      status.textContent = error && error.message === "rate"
        ? "محاولات كثيرة. انتظر دقيقة وجرّب ثاني."
        : "ما وصل ردك. جرّب مرة ثانية.";
    } finally {
      yes.disabled = false;
      no.disabled = false;
    }
  }

  yes.addEventListener("click", () => send("CONFIRMED"));
  no.addEventListener("click", () => send("DECLINED"));
  load();
})();
