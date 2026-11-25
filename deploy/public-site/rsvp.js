(() => {
  "use strict";

  // e05, a guest's personal RSVP link (V1 checklist 4.7): /rsvp/<token>. The
  // page reads the invitation and sends the answer to the same origin, which
  // the edge proxy forwards to the API; no account, no cookies, no form post.
  // D83: the card (photo, host line, free text) and the events beyond the
  // wedding, each answered on its own.
  // D116: every occasion says its own place, address and map; an answer
  // given before a change asks to be confirmed again; a bride's guests are
  // spoken to as women; `?e=<id>` points at the occasion a message was about;
  // the page tells the server once that the guest saw it.

  const $ = (id) => document.getElementById(id);
  const cardSection = $("rsvp-card");
  const title = $("rsvp-title");
  const greeting = $("rsvp-greeting");
  const inviteLine = $("rsvp-invite-line");
  const photo = $("rsvp-photo");
  const freeText = $("rsvp-free-text");
  const retry = $("rsvp-retry");
  const details = $("rsvp-details");
  const map = $("rsvp-map");
  const addressLine = $("rsvp-address");
  const answer = $("rsvp-answer");
  const answerTitle = $("rsvp-answer-title");
  const reconfirm = $("rsvp-reconfirm");
  const status = $("rsvp-status");
  const chips = $("rsvp-companions");
  const yes = $("rsvp-yes");
  const no = $("rsvp-no");
  const eventsSection = $("rsvp-events");
  const eventsList = $("rsvp-events-list");
  const eventsBefore = $("rsvp-events-before");
  const eventsBeforeList = $("rsvp-events-before-list");
  const notice = $("rsvp-notice");

  // RA-BE-74: the hosts took an event out of this invitation after the page
  // opened. The link still works; the page shows the invitation as it is now.
  const INVITATION_CHANGED = "تغيّرت دعوتك قبل ما يوصل ردك، وهذي هي الحين.";

  // RA-BE-173 (Q-43): «لحالي» up to the number the hosts gave this guest.
  let companions = 0;
  let maxCompanions = 0;

  // D116: the plan's side, unknown (undefined) until the invitation is read;
  // null when the plan names none, which reads as the masculine form, as the
  // server's own lines do.
  let persona;
  let photoKind = "PHOTO";
  // The first successful draw of this page load: the opened beacon and the
  // scroll to the occasion the message was about happen once, after it.
  let drawn = false;
  // What the failed load was going to say, so a retry still says it.
  let retryMessage;

  /**
   * A line addressed to the guest: the feminine form for a bride's plan;
   * [neutral], when given, before the plan's side is known.
   */
  function say(masculine, feminine, neutral) {
    if (persona === undefined && neutral !== undefined) return neutral;
    return persona === "BRIDE" ? feminine : masculine;
  }

  const segments = window.location.pathname.split("/").filter(Boolean);
  const token = segments.length === 2 && segments[0] === "rsvp" ? segments[1] : "";
  if (!/^[A-Za-z0-9_-]{43}$/.test(token)) {
    showInvalid();
    return;
  }
  const endpoint = `/api/v1/public/rsvp/${encodeURIComponent(token)}`;
  const focusId = focusedOccasion(window.location.search);

  /** D116: `?e=<planEventId>`, the occasion a separate message was about. */
  function focusedOccasion(search) {
    const match = /(?:^|[?&])e=([^&#]*)/.exec(typeof search === "string" ? search : "");
    if (!match) return "";
    try {
      return decodeURIComponent(match[1]);
    } catch {
      return "";
    }
  }

  /** Takes the invitation's own parts off the page (a dead or failed load). */
  function clearInvitation() {
    greeting.textContent = "";
    title.hidden = false;
    inviteLine.hidden = false;
    photo.hidden = true;
    photo.removeAttribute("src");
    freeText.hidden = true;
    details.hidden = true;
    answer.hidden = true;
    eventsSection.hidden = true;
    eventsBefore.hidden = true;
  }

  function showInvalid() {
    clearInvitation();
    retry.hidden = true;
    title.textContent = "الرابط ما يشتغل";
    inviteLine.textContent = say(
      "اطلب من صاحب الدعوة يرسل لك رابط جديد.",
      "اطلبي من صاحبة الدعوة ترسل لك رابط جديد.",
      "أهل الدعوة يقدرون يرسلون لك رابط جديد.",
    );
  }

  /**
   * RA-BE-174: the link closed a week after the wedding. It is not broken,
   * and a new one would not open either, so the page asks for nothing.
   */
  function showEnded() {
    clearInvitation();
    retry.hidden = true;
    title.textContent = "العرس فات";
    inviteLine.textContent = "هذي الدعوة انتهت، وما عاد الرابط يفتح.";
  }

  /** A load that did not reach the invitation (no network, a 5xx). */
  function showLoadFailure() {
    clearInvitation();
    title.textContent = "ما قدرنا نفتح الدعوة";
    inviteLine.textContent = say(
      "تأكد من النت وحاول مرة ثانية.",
      "تأكدي من النت وحاولي مرة ثانية.",
      "يمكن النت ضعيف أو مقطوع.",
    );
    // «إعادة المحاولة» was the form's word, not the guest's.
    retry.textContent = say("جرّب مرة ثانية", "جرّبي مرة ثانية", "نحاول مرة ثانية");
    retry.hidden = false;
  }

  function calendarDay(value) {
    const [year, month, day] = value.split("-").map(Number);
    return new Date(Date.UTC(year, month - 1, day));
  }

  // The app's own words and digits for a day (formatArabicDate): one way on
  // the card and on every occasion. The browser's «ar» wrote its own digits
  // and order, beside a Hijri line in Latin digits.
  const WEEKDAYS = ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"];
  const MONTHS = [
    "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
    "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر",
  ];

  /** «الخميس، 21 يناير 2026». */
  function formatDay(date) {
    return `${WEEKDAYS[date.getUTCDay()]}، ${date.getUTCDate()} ${MONTHS[date.getUTCMonth()]} ${date.getUTCFullYear()}`;
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

  /**
   * 6a: the bucket keeps the card photo private. The server names this
   * link's own photo route (on whichever host of the site it writes); the
   * page reads that route on its own origin and loads nothing else.
   */
  function photoSource(value) {
    const route = `${endpoint}/card-photo`;
    const path = typeof value === "string" ? /^https:\/\/[^/?#]+(\/.*)$/.exec(value) : null;
    return path && path[1] === route ? route : "";
  }

  /**
   * D116: a ready-made card (CARD) has the names and the date written on
   * it, so the host line and the title are not said again under it; without
   * the picture they are the invitation's only words, and come back.
   */
  function showCardText() {
    const writtenOnCard = photoKind === "CARD" && !photo.hidden;
    inviteLine.hidden = writtenOnCard;
    // RA-OP-31: the only <h1> stays on the page for a screen reader.
    title.className = writtenOnCard ? "rsvp-visually-hidden" : "";
  }

  // A photo that does not load (its signed link refused, the connection
  // dropped) leaves the page: the invitation reads whole without it, and a
  // broken picture stood over it.
  photo.addEventListener("error", () => {
    photo.hidden = true;
    photo.removeAttribute("src");
    showCardText();
  });

  function mapLabel() {
    return say("افتح الموقع على الخريطة", "افتحي الموقع على الخريطة");
  }

  /** D116: «تغيّر موعد أو مكان العرس. أكّد حضورك من جديد.» */
  function reconfirmText(what) {
    return `تغيّر موعد أو مكان ${what}. ${say("أكّد حضورك من جديد.", "أكّدي حضورك من جديد.")}`;
  }

  /** A confirmed answer reads as done, unless it asks to be confirmed again. */
  function statusClass(attendanceStatus, needsReconfirm) {
    return attendanceStatus === "CONFIRMED" && !needsReconfirm
      ? "rsvp-status rsvp-done"
      : "rsvp-status";
  }

  function chipLabel(count) {
    return count === 0 ? "لحالي" : `+${count}`;
  }

  /** Fills [container] with the companion chips; [onPick] gets the choice. */
  function renderChips(container, max, current, onPick) {
    const counts = [];
    for (let count = 0; count <= max; count += 1) counts.push(count);
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
    const change = say("تقدر تغيّر ردك متى ما تشتي.", "تقدرين تغيّرين ردك متى ما تشتين.");
    if (attendanceStatus === "CONFIRMED") {
      // «حضورك مع 2» left out who the two come with.
      const withWhom = picked > 0 ? ` ${say("أنت", "أنتِ")} و${picked} معك` : "";
      return `سجّلنا حضورك${what}${withWhom}. ${change}`;
    }
    if (attendanceStatus === "DECLINED") {
      return `سجّلنا اعتذارك${what}. ${change}`;
    }
    return "";
  }

  function renderCard(invitation) {
    const cardFields = invitation.card || {};
    greeting.textContent = `أهلًا ${invitation.guestName}`;
    inviteLine.textContent = invitation.hostPhrase || "يسعدنا حضورك";
    title.textContent = invitation.planTitle;

    photoKind = cardFields.photoKind === "CARD" ? "CARD" : "PHOTO";
    photo.className = photoKind === "CARD" ? "rsvp-photo rsvp-photo-card" : "rsvp-photo";
    photo.alt = photoKind === "CARD" ? `بطاقة دعوة ${invitation.planTitle}` : "";
    const photoUrl = photoSource(cardFields.photoUrl);
    photo.hidden = !photoUrl;
    if (photoUrl) photo.src = photoUrl;
    else photo.removeAttribute("src");
    showCardText();

    freeText.hidden = !cardFields.freeText;
    freeText.textContent = cardFields.freeText || "";

    // D116: the wedding's own time, place, address and map.
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

    const mapUrl = secureLink(wedding.mapUrl);
    const address = wedding.address || "";
    map.hidden = !mapUrl;
    map.textContent = mapLabel();
    if (mapUrl) map.href = mapUrl;
    else map.removeAttribute("href");
    addressLine.hidden = !address;
    addressLine.textContent = address;
    $("rsvp-where-row").hidden = !mapUrl && !address;

    details.hidden = !day && !place && !mapUrl && !address;
  }

  function renderWeddingAnswer(invitation) {
    const wedding = invitation.wedding || {};
    const again = Boolean(wedding.needsReconfirm);
    maxCompanions = invitation.maxCompanions || 0;
    // An answer given before the hosts lowered the number goes down with it.
    companions = Math.min(invitation.companionsCount || 0, maxCompanions);
    renderChips(chips, maxCompanions, companions, (count) => {
      companions = count;
    });
    // Nobody may come with this guest: nothing to ask.
    chips.hidden = maxCompanions === 0;
    $("rsvp-companions-label").hidden = maxCompanions === 0;
    answer.hidden = false;
    answer.className =
      focusId && focusId === wedding.id ? "rsvp-answer rsvp-focus" : "rsvp-answer";
    answerTitle.hidden = !(invitation.events && invitation.events.length);
    yes.textContent = say("إن شاء الله حاضر", "إن شاء الله حاضرة");
    no.textContent = "أعتذر";
    reconfirm.hidden = !again;
    reconfirm.textContent = again ? reconfirmText("العرس") : "";
    status.className = statusClass(invitation.attendanceStatus, again);
    status.textContent = statusText(invitation.attendanceStatus, companions, "");
  }

  function paragraph(className, text) {
    const line = document.createElement("p");
    line.className = className;
    line.textContent = text;
    return line;
  }

  /** D116: an event's own place, address and map link. */
  function placeNodes(event) {
    const nodes = [];
    if (event.placeLabel) nodes.push(paragraph("rsvp-event-place", event.placeLabel));
    if (event.address) nodes.push(paragraph("rsvp-event-address", event.address));
    const mapUrl = secureLink(event.mapUrl);
    if (mapUrl) {
      const link = document.createElement("a");
      link.className = "rsvp-map";
      link.href = mapUrl;
      link.target = "_blank";
      link.rel = "noopener noreferrer";
      link.textContent = mapLabel();
      nodes.push(link);
    }
    return nodes;
  }

  /**
   * The events in the order of their days: those before the wedding's day
   * above its reply, the others under it («الزفاف» came first whatever its
   * day, and a lunch the day before read as an afterthought). Same day keeps
   * the server's order. An event with no day goes last.
   */
  function orderedEvents(invitation) {
    const events = Array.isArray(invitation.events) ? invitation.events : [];
    const dayOf = (event) => (typeof event.date === "string" ? event.date : "9999-12-31");
    const sorted = events
      .map((event, position) => ({ event, position }))
      .sort((a, b) => dayOf(a.event).localeCompare(dayOf(b.event)) || a.position - b.position)
      .map(({ event }) => event);
    const weddingDay = typeof invitation.weddingDate === "string" ? invitation.weddingDate : "";
    const before = weddingDay
      ? sorted.filter((event) => typeof event.date === "string" && event.date < weddingDay)
      : [];
    return { before, after: sorted.filter((event) => !before.includes(event)) };
  }

  /** Draws the events; returns the block of each, by id. */
  function renderEvents(invitation) {
    const { before, after } = orderedEvents(invitation);
    const blocks = new Map();
    eventsBefore.hidden = before.length === 0;
    eventsSection.hidden = after.length === 0;
    let index = 0;
    eventsBeforeList.replaceChildren(
      ...before.map((event) => eventBlock(event, index++, blocks)),
    );
    eventsList.replaceChildren(...after.map((event) => eventBlock(event, index++, blocks)));
    return blocks;
  }

  /** One occasion's block, its reply and its status line. */
  function eventBlock(event, index, blocks) {
    const again = Boolean(event.needsReconfirm);
    const block = document.createElement("article");
    block.className = event.id === focusId ? "rsvp-event rsvp-focus" : "rsvp-event";
    blocks.set(event.id, block);

    // RA-OP-31: each occasion is a named region, its chips a named group.
    const heading = document.createElement("h3");
    heading.id = `rsvp-event-${index}-title`;
    heading.textContent = event.label;
    block.setAttribute("aria-labelledby", heading.id);
    block.append(heading);

    const whenParts = [];
    if (event.date) whenParts.push(formatDay(calendarDay(event.date)));
    if (event.timeLabel) whenParts.push(event.timeLabel);
    if (whenParts.length) block.append(paragraph("rsvp-event-when", whenParts.join(" · ")));
    block.append(...placeNodes(event));

    if (again) block.append(paragraph("rsvp-reconfirm", reconfirmText("هذي المناسبة")));

    let picked = Math.min(event.companionsCount || 0, maxCompanions);
    if (maxCompanions > 0) {
      const question = paragraph("rsvp-question", "كم معك؟");
      question.id = `rsvp-event-${index}-companions`;
      block.append(question);
      const eventChips = document.createElement("div");
      eventChips.className = "rsvp-chips";
      eventChips.setAttribute("role", "group");
      eventChips.setAttribute("aria-labelledby", question.id);
      renderChips(eventChips, maxCompanions, picked, (count) => {
        picked = count;
      });
      block.append(eventChips);
    }

    const actions = document.createElement("div");
    actions.className = "rsvp-event-actions";
    const eventYes = document.createElement("button");
    eventYes.type = "button";
    eventYes.className = "rsvp-yes";
    eventYes.textContent = say("حاضر", "حاضرة");
    const eventNo = document.createElement("button");
    eventNo.type = "button";
    eventNo.className = "rsvp-no";
    eventNo.textContent = "أعتذر";
    actions.append(eventYes, eventNo);
    block.append(actions);

    const eventStatus = paragraph(
      statusClass(event.attendanceStatus, again),
      statusText(event.attendanceStatus, picked, ` في ${event.label}`),
    );
    eventStatus.setAttribute("role", "status");
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
  }

  /**
   * [message]: a line about why the page was drawn again; none clears it.
   * Returns the block of the occasion `?e=` names, or null.
   */
  function render(invitation, message) {
    persona =
      invitation.persona === "BRIDE" ? "BRIDE" : invitation.persona === "GROOM" ? "GROOM" : null;
    retry.hidden = true;
    renderCard(invitation);
    renderWeddingAnswer(invitation);
    const blocks = renderEvents(invitation);
    notice.textContent = message || "";
    notice.hidden = !message;
    if (!focusId) return null;
    if (invitation.wedding && invitation.wedding.id === focusId) return cardSection;
    return blocks.get(focusId) || null;
  }

  /** D116: the guest saw the invitation. Nothing on the page waits on it. */
  function markOpened() {
    try {
      const sent = fetch(`${endpoint}/opened`, {
        method: "POST",
        headers: { Accept: "application/json" },
      });
      if (sent && typeof sent.catch === "function") sent.catch(() => {});
    } catch {
      // The invitation is drawn either way.
    }
  }

  async function load(message) {
    retry.hidden = true;
    let focused;
    try {
      const response = await fetch(endpoint, { headers: { Accept: "application/json" } });
      if (response.status === 404) return showInvalid();
      if (response.status === 410) return showEnded();
      if (!response.ok) throw new Error(String(response.status));
      focused = render(await response.json(), message);
    } catch {
      retryMessage = message;
      showLoadFailure();
      return;
    }
    if (drawn) return;
    drawn = true;
    markOpened();
    if (focused && typeof focused.scrollIntoView === "function") {
      focused.scrollIntoView({ block: "start" });
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
      if (response.status === 410) return showEnded();
      if (response.status === 409 && (await refusalCode(response)) === "RSVP_EVENT_NOT_INVITED") {
        return load(INVITATION_CHANGED);
      }
      if (response.status === 429) throw new Error("rate");
      if (!response.ok) throw new Error(String(response.status));
      render(await response.json());
    } catch (error) {
      statusLine.textContent = error && error.message === "rate"
        ? say("محاولات كثيرة. انتظر دقيقة وجرّب ثاني.", "محاولات كثيرة. انتظري دقيقة وجرّبي ثاني.")
        : say("ما وصل ردك. جرّب مرة ثانية.", "ما وصل ردك. جرّبي مرة ثانية.");
    } finally {
      for (const button of buttons) button.disabled = false;
    }
  }

  const weddingReply = (attendance) =>
    send(attendance, { companions, buttons: [yes, no], statusLine: status });
  yes.addEventListener("click", () => weddingReply("CONFIRMED"));
  no.addEventListener("click", () => weddingReply("DECLINED"));
  retry.addEventListener("click", () => {
    retry.hidden = true;
    title.textContent = "نفتح الدعوة…";
    inviteLine.textContent = "";
    load(retryMessage);
  });
  load();
})();
