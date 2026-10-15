(() => {
  "use strict";

  // A guest's personal RSVP link (V1 checklist 4.7): /rsvp/<token>. The page
  // reads the invitation and sends the answer to the same origin, which the
  // edge proxy forwards to the API; no account, no cookies, no form post.

  const $ = (id) => document.getElementById(id);
  const title = $("rsvp-title");
  const greeting = $("rsvp-greeting");
  const details = $("rsvp-details");
  const answer = $("rsvp-answer");
  const status = $("rsvp-status");
  const companions = $("rsvp-companions");
  const yes = $("rsvp-yes");
  const no = $("rsvp-no");

  const segments = window.location.pathname.split("/").filter(Boolean);
  const token = segments.length === 2 && segments[0] === "rsvp" ? segments[1] : "";
  if (!/^[A-Za-z0-9_-]{43}$/.test(token)) {
    showInvalid();
    return;
  }
  const endpoint = `/api/v1/public/rsvp/${encodeURIComponent(token)}`;

  function showInvalid() {
    title.textContent = "رابط الدعوة غير صالح";
    greeting.textContent = "اطلب من صاحب الدعوة إرسال رابط جديد.";
    details.hidden = true;
    answer.hidden = true;
  }

  function formatDay(value) {
    const [year, month, day] = value.split("-").map(Number);
    return new Intl.DateTimeFormat("ar", {
      weekday: "long",
      day: "numeric",
      month: "long",
      year: "numeric",
      timeZone: "UTC",
    }).format(new Date(Date.UTC(year, month - 1, day)));
  }

  function render(invitation) {
    title.textContent = invitation.planTitle;
    greeting.textContent = `أهلًا ${invitation.guestName}، يسعدنا حضورك.`;
    $("rsvp-date-row").hidden = !invitation.weddingDate;
    if (invitation.weddingDate) $("rsvp-date").textContent = formatDay(invitation.weddingDate);
    $("rsvp-place-row").hidden = !invitation.locationLabel;
    if (invitation.locationLabel) $("rsvp-place").textContent = invitation.locationLabel;
    details.hidden = !invitation.weddingDate && !invitation.locationLabel;
    companions.max = String(invitation.maxCompanions);
    companions.value = String(invitation.companionsCount || 0);
    answer.hidden = false;
    status.className = "status";
    if (invitation.attendanceStatus === "CONFIRMED") {
      status.className = "status rsvp-done";
      status.textContent = "سجّلنا حضورك. يمكنك تغيير ردّك في أي وقت.";
    } else if (invitation.attendanceStatus === "DECLINED") {
      status.textContent = "سجّلنا اعتذارك. يمكنك تغيير ردّك في أي وقت.";
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
      title.textContent = "تعذر فتح الدعوة";
      greeting.textContent = "تحقق من الاتصال ثم أعد فتح الرابط.";
    }
  }

  async function send(attendance) {
    const count = Number.parseInt(companions.value, 10);
    const max = Number.parseInt(companions.max, 10) || 20;
    if (attendance === "CONFIRMED" && (!Number.isInteger(count) || count < 0 || count > max)) {
      status.textContent = `عدد المرافقين من 0 إلى ${max}.`;
      return;
    }
    yes.disabled = true;
    no.disabled = true;
    status.className = "status";
    status.textContent = "جارٍ الإرسال…";
    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json" },
        body: JSON.stringify(
          attendance === "CONFIRMED" ? { attendance, companionsCount: count } : { attendance },
        ),
      });
      if (response.status === 404) return showInvalid();
      if (response.status === 429) throw new Error("rate");
      if (!response.ok) throw new Error(String(response.status));
      render(await response.json());
    } catch (error) {
      status.textContent = error && error.message === "rate"
        ? "محاولات كثيرة. انتظر دقيقة ثم حاول مرة أخرى."
        : "تعذر إرسال ردّك. حاول مرة أخرى.";
    } finally {
      yes.disabled = false;
      no.disabled = false;
    }
  }

  yes.addEventListener("click", () => send("CONFIRMED"));
  no.addEventListener("click", () => send("DECLINED"));
  load();
})();
