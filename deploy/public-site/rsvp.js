(() => {
  "use strict";

  // e05, a guest's personal RSVP link (V1 checklist 4.7): /rsvp/<token>. The
  // page reads the invitation and sends the answer to the same origin, which
  // the edge proxy forwards to the API; no account, no cookies, no form post.
  // D83: the card (photo, host line, free text, map or address) and the
  // events beyond the wedding, each answered on its own.

  const $ = (id) => document.getElementById(id);
  const title = $("rsvp-title");
  const greeting = $("rsvp-greeting");
  const inviteLine = $("rsvp-invite-line");
  const photo = $("rsvp-photo");
  const freeText = $("rsvp-free-text");
  const details = $("rsvp-details");
  const answer = $("rsvp-answer");
  const answerTitle = $("rsvp-answer-title");
  const status = $("rsvp-status");
  const chips = $("rsvp-companions");
  const yes = $("rsvp-yes");
  const no = $("rsvp-no");
  const eventsSection = $("rsvp-events");
  const eventsList = $("rsvp-events-list");
  const notice = $("rsvp-notice");

  // RA-BE-74: the hosts took an event out of this invitation after the page
  // opened. The link still works; the page shows the invitation as it is now.
  const INVITATION_CHANGED = "تغيّرت دعوتك قبل ما يوصل ردك، وهذي هي الحين.";

  // «لحالي / +1 / +2 / +3»; a larger number the hosts set stays offered.
  const CHIP_LIMIT = 3;
  let companions = 0;
  let maxCompanions = CHIP_LIMIT;

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
    photo.hidden = true;
    freeText.hidden = true;
    details.hidden = true;
    answer.hidden = true;
    eventsSection.hidden = true;
  }

  function calendarDay(value) {
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

  /** Only a link the server accepted (HTTPS) is opened or shown. */
  function secureLink(value) {
    return typeof value === "string" && /^https:/.test(value) ? value : "";
  }

  function chipLabel(count) {
    return count === 0 ? "لحالي" : `+${count}`;
  }

  /** Fills [container] with the companion chips; [onPick] gets the choice. */
  function renderChips(container, max, current, onPick) {
    const counts = [];
    for (let count = 0; count <= Math.min(CHIP_LIMIT, max); count += 1) counts.push(count);
    if (current > CHIP_LIMIT && current <= max) counts.push(current);
    container.replaceChildren(
      ...counts.map((count) => {
        const chip = document.createElement("button");
        chip.type = "button";
        chip.textContent = chipLabel(count);
        // «+2» reads left to right inside the Arabic line.
        if (count > 0) chip.dir = "ltr";
        chip.setAttribute("aria-pressed", String(count === current));
        chip.addEventListener("click", () => {
          onPick(count);
          for (const other of container.children) {
            other.setAttribute("aria-pressed", String(other === chip));
          }
        });
        return chip;
      }),
    );
  }

  function statusText(attendanceStatus, picked, what) {
    if (attendanceStatus === "CONFIRMED") {
      const withWhom = picked > 0 ? ` مع ${picked}` : "";
      return `سجّلنا حضورك${what}${withWhom}. تقدر تغيّر ردك متى ما تشتي.`;
    }
    if (attendanceStatus === "DECLINED") {
      return `سجّلنا اعتذارك${what}. تقدر تغيّر ردك متى ما تشتي.`;
    }
    return "";
  }

  function renderCard(invitation) {
    const card = invitation.card || {};
    greeting.textContent = `أهلًا ${invitation.guestName}`;
    inviteLine.textContent = invitation.hostPhrase || "يسعدنا حضورك";
    title.textContent = invitation.planTitle;

    const photoUrl = secureLink(card.photoUrl);
    photo.hidden = !photoUrl;
    if (photoUrl) photo.src = photoUrl;
    else photo.removeAttribute("src");

    freeText.hidden = !card.freeText;
    freeText.textContent = card.freeText || "";

    const wedding = invitation.wedding || {};
    const day = invitation.weddingDate ? calendarDay(invitation.weddingDate) : null;
    $("rsvp-date-row").hidden = !day;
    if (day) {
      $("rsvp-date").textContent = wedding.timeLabel
        ? `${formatDay(day)} · ${wedding.timeLabel}`
        : formatDay(day);
      $("rsvp-hijri").textContent = formatHijri(day);
    }
    const place = wedding.placeLabel || invitation.locationLabel || "";
    $("rsvp-place-row").hidden = !place;
    $("rsvp-place").textContent = place;

    const mapUrl = secureLink(card.mapUrl);
    const address = card.address || "";
    const map = $("rsvp-map");
    const addressLine = $("rsvp-address");
    map.hidden = !mapUrl;
    if (mapUrl) map.href = mapUrl;
    else map.removeAttribute("href");
    addressLine.hidden = !address || Boolean(mapUrl);
    addressLine.textContent = address;
    $("rsvp-where-row").hidden = !mapUrl && !address;

    details.hidden = !day && !place && !mapUrl && !address;
  }

  function renderWeddingAnswer(invitation) {
    maxCompanions = invitation.maxCompanions;
    companions = invitation.companionsCount || 0;
    renderChips(chips, maxCompanions, companions, (count) => {
      companions = count;
    });
    answer.hidden = false;
    answerTitle.hidden = !(invitation.events && invitation.events.length);
    status.className =
      invitation.attendanceStatus === "CONFIRMED" ? "rsvp-status rsvp-done" : "rsvp-status";
    status.textContent = statusText(invitation.attendanceStatus, companions, "");
  }

  function renderEvents(invitation) {
    const events = Array.isArray(invitation.events) ? invitation.events : [];
    eventsSection.hidden = events.length === 0;
    eventsList.replaceChildren(
      ...events.map((event) => {
        const block = document.createElement("article");
        block.className = "rsvp-event";

        const heading = document.createElement("h3");
        heading.textContent = event.label;
        block.append(heading);

        const whenParts = [];
        if (event.date) whenParts.push(formatDay(calendarDay(event.date)));
        if (event.timeLabel) whenParts.push(event.timeLabel);
        if (event.placeLabel) whenParts.push(event.placeLabel);
        if (whenParts.length) {
          const when = document.createElement("p");
          when.className = "rsvp-event-when";
          when.textContent = whenParts.join(" · ");
          block.append(when);
        }

        const question = document.createElement("p");
        question.className = "rsvp-question";
        question.textContent = "كم معك؟";
        block.append(question);

        let picked = event.companionsCount || 0;
        const eventChips = document.createElement("div");
        eventChips.className = "rsvp-chips";
        eventChips.setAttribute("role", "group");
        renderChips(eventChips, maxCompanions, picked, (count) => {
          picked = count;
        });
        block.append(eventChips);

        const actions = document.createElement("div");
        actions.className = "rsvp-event-actions";
        const eventYes = document.createElement("button");
        eventYes.type = "button";
        eventYes.className = "rsvp-yes";
        eventYes.textContent = "حاضر";
        const eventNo = document.createElement("button");
        eventNo.type = "button";
        eventNo.className = "rsvp-no";
        eventNo.textContent = "أعتذر";
        actions.append(eventYes, eventNo);
        block.append(actions);

        const eventStatus = document.createElement("p");
        eventStatus.className =
          event.attendanceStatus === "CONFIRMED" ? "rsvp-status rsvp-done" : "rsvp-status";
        eventStatus.setAttribute("role", "status");
        eventStatus.textContent = statusText(event.attendanceStatus, picked, ` في ${event.label}`);
        block.append(eventStatus);

        const sendEvent = (attendance) =>
          send(attendance, {
            planEventId: event.id,
            companions: picked,
            buttons: [eventYes, eventNo],
            statusLine: eventStatus,
          });
        eventYes.addEventListener("click", () => sendEvent("CONFIRMED"));
        eventNo.addEventListener("click", () => sendEvent("DECLINED"));
        return block;
      }),
    );
  }

  /** [message]: a line about why the page was drawn again; none clears it. */
  function render(invitation, message) {
    renderCard(invitation);
    renderWeddingAnswer(invitation);
    renderEvents(invitation);
    notice.textContent = message || "";
    notice.hidden = !message;
  }

  async function load(message) {
    try {
      const response = await fetch(endpoint, { headers: { Accept: "application/json" } });
      if (response.status === 404) return showInvalid();
      if (!response.ok) throw new Error(String(response.status));
      render(await response.json(), message);
    } catch {
      greeting.textContent = "";
      title.textContent = "ما قدرنا نفتح الدعوة";
      inviteLine.textContent = "تأكد من النت وافتح الرابط مرة ثانية.";
    }
  }

  /** The code of a refusal (`{ code }`), or "" when the body has none. */
  async function refusalCode(response) {
    try {
      const body = await response.json();
      return body && typeof body.code === "string" ? body.code : "";
    } catch {
      return "";
    }
  }

  /**
   * Sends one reply: to the wedding (no planEventId) or to one event. The
   * whole page re-renders from the server's answer, so every reply shown is
   * the stored one.
   */
  async function send(attendance, options) {
    const buttons = options.buttons;
    const statusLine = options.statusLine;
    for (const button of buttons) button.disabled = true;
    statusLine.className = "rsvp-status";
    statusLine.textContent = "نرسل ردك…";
    const body = { attendance };
    if (attendance === "CONFIRMED") body.companionsCount = options.companions;
    if (options.planEventId) body.planEventId = options.planEventId;
    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify(body),
      });
      if (response.status === 404) return showInvalid();
      if (response.status === 409 && (await refusalCode(response)) === "RSVP_EVENT_NOT_INVITED") {
        return load(INVITATION_CHANGED);
      }
      if (response.status === 429) throw new Error("rate");
      if (!response.ok) throw new Error(String(response.status));
      render(await response.json());
    } catch (error) {
      statusLine.textContent = error && error.message === "rate"
        ? "محاولات كثيرة. انتظر دقيقة وجرّب ثاني."
        : "ما وصل ردك. جرّب مرة ثانية.";
    } finally {
      for (const button of buttons) button.disabled = false;
    }
  }

  const weddingReply = (attendance) =>
    send(attendance, { companions, buttons: [yes, no], statusLine: status });
  yes.addEventListener("click", () => weddingReply("CONFIRMED"));
  no.addEventListener("click", () => weddingReply("DECLINED"));
  load();
})();
