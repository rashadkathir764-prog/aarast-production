(() => {
  "use strict";

  const button = document.getElementById("open-invite");
  const status = document.getElementById("invite-status");
  const segments = window.location.pathname.split("/").filter(Boolean);
  const token = segments.length === 2 && segments[0] === "invites"
    ? segments[1]
    : "";
  const isValidToken = /^[A-Za-z0-9_-]{43}$/.test(token);

  if (!isValidToken) {
    button.setAttribute("aria-disabled", "true");
    button.removeAttribute("href");
    button.textContent = "رابط الدعوة غير صالح";
    status.textContent = "اطلب من صاحب الخطة إرسال رابط دعوة جديد.";
    return;
  }

  button.href = `aarast://open/invites/${encodeURIComponent(token)}`;
})();
