(() => {
  "use strict";

  const button = document.getElementById("open-invite");
  const status = document.getElementById("invite-status");
  const getApp = document.getElementById("get-app");
  const afterDownload = document.getElementById("after-download");
  const iphoneNote = document.getElementById("iphone-note");
  const segments = window.location.pathname.split("/").filter(Boolean);
  const token = segments.length === 2 && segments[0] === "invites"
    ? segments[1]
    : "";
  const isValidToken = /^[A-Za-z0-9_-]{43}$/.test(token);

  // Q-69: the app is on Android only for now. An iPhone or an iPad (which
  // asks as a Mac with a touch screen) gets no Google store button and no
  // «open in the app» that opens nothing; it is told plainly instead.
  const agent = navigator.userAgent || "";
  const isApplePhone = /iPhone|iPad|iPod/.test(agent) ||
    (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);

  if (isApplePhone) {
    getApp.hidden = true;
    afterDownload.hidden = true;
  }

  if (!isValidToken) {
    button.setAttribute("aria-disabled", "true");
    button.removeAttribute("href");
    button.textContent = "رابط الدعوة هذا ما يشتغل";
    status.textContent = "صاحب الخطة يقدر يبعث لك رابط دعوة جديد.";
    return;
  }

  if (isApplePhone) {
    button.hidden = true;
    status.hidden = true;
    iphoneNote.hidden = false;
    return;
  }

  button.href = `aarast://open/invites/${encodeURIComponent(token)}`;
})();
