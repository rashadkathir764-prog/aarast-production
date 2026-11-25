// Q-52 (أ, D124), RA-OP-21: the account's deletion without the app. The page
// asks the server, on its own origin, for a WhatsApp code to the registered
// number, then sends the number and the code; the account then waits the
// same 30 days as a request from the app, and signing in takes it back. The
// page keeps nothing on the device and writes no markup (the CSP allows no
// inline script or style).
(function () {
  "use strict";

  var CODE_URL = "/api/v1/public/account-deletion/code";
  var CONFIRM_URL = "/api/v1/public/account-deletion/confirm";

  var phoneStep = document.getElementById("deletion-phone-step");
  var codeStep = document.getElementById("deletion-code-step");
  var done = document.getElementById("deletion-done");
  var phoneInput = document.getElementById("deletion-phone");
  var codeInput = document.getElementById("deletion-code");
  var sendButton = document.getElementById("deletion-send");
  var confirmButton = document.getElementById("deletion-confirm");
  var againButton = document.getElementById("deletion-again");
  var phoneEcho = document.getElementById("deletion-phone-echo");
  var day = document.getElementById("deletion-day");
  var statusLine = document.getElementById("deletion-status");
  var phone = "";

  var WORDS = {
    network: "ما قدرنا نوصل لاعّرست الآن. يُجرَّب مرة ثانية بعد لحظات.",
    phone: "الرقم مو صحيح. يُكتب رقم الجوال كما هو مسجّل بالحساب، مثل +967 7XX XXX XXX.",
    codeShape: "الرمز 6 أرقام كما وصل على واتساب.",
    codeWrong: "الرمز غلط أو انتهى. يُطلب رمز جديد من «تغيير الرقم أو طلب رمز جديد».",
    noAccount: "ما في حساب في اعّرست بهذا الرقم.",
    disabled: "هذا الحساب موقوف، فما يُطلب حذفه من هنا. للمساعدة: صفحة الدعم.",
    provider: "عند هذا الحساب حجوزات قادمة كمزوّد. تُسلَّم أو تُلغى من التطبيق أولًا، وبعدها يُطلب الحذف.",
    tooMany: "طلبات كثيرة في وقت قصير. يُجرَّب بعد دقيقة.",
    other: "صار خطأ عندنا وما انحفظ الطلب. يُجرَّب مرة ثانية بعد لحظات.",
  };

  function say(text) {
    statusLine.textContent = text || "";
    statusLine.hidden = !text;
  }

  function show(step) {
    [phoneStep, codeStep, done].forEach(function (section) {
      section.hidden = section !== step;
    });
  }

  function busy(button, value) {
    button.disabled = value;
    button.setAttribute("aria-busy", value ? "true" : "false");
  }

  function latinDigits(value) {
    return value.replace(/[٠-٩]/g, function (digit) {
      return String(digit.charCodeAt(0) - 0x0660);
    }).replace(/[۰-۹]/g, function (digit) {
      return String(digit.charCodeAt(0) - 0x06f0);
    });
  }

  function formatDay(value) {
    var date = new Date(value);
    if (isNaN(date.getTime())) return "";
    return date.getUTCDate() + "/" + (date.getUTCMonth() + 1) + "/" + date.getUTCFullYear();
  }

  async function post(url, body) {
    var response = await fetch(url, {
      method: "POST",
      credentials: "omit",
      headers: { Accept: "application/json", "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    var answer = {};
    try {
      answer = await response.json();
    } catch (error) {
      answer = {};
    }
    return { status: response.status, body: answer || {} };
  }

  // A code limit names itself and its wait in words the server writes.
  function limitWords(answer) {
    var code = answer.body.code;
    if (typeof code === "string" && code.indexOf("OTP_LIMIT_") === 0 &&
        typeof answer.body.message === "string") {
      return answer.body.message;
    }
    return WORDS.tooMany;
  }

  async function sendCode() {
    var typed = latinDigits(phoneInput.value).trim();
    if (!/^\+?[0-9\s-]{7,20}$/.test(typed)) {
      say(WORDS.phone);
      phoneInput.focus();
      return;
    }
    busy(sendButton, true);
    say("");
    try {
      var answer = await post(CODE_URL, { phone: typed });
      if (answer.status === 200) {
        phone = typed;
        phoneEcho.textContent = typed;
        codeInput.value = "";
        show(codeStep);
        if (typeof answer.body.message === "string" && answer.body.deliveryStatus === "UNCERTAIN") {
          say(answer.body.message);
        }
        codeInput.focus();
      } else if (answer.status === 429) {
        say(limitWords(answer));
      } else if (answer.status === 400) {
        say(WORDS.phone);
      } else {
        say(WORDS.other);
      }
    } catch (error) {
      say(WORDS.network);
    } finally {
      busy(sendButton, false);
    }
  }

  async function confirmDeletion() {
    var code = latinDigits(codeInput.value).trim();
    if (!/^[0-9]{6}$/.test(code)) {
      say(WORDS.codeShape);
      codeInput.focus();
      return;
    }
    busy(confirmButton, true);
    say("");
    try {
      var answer = await post(CONFIRM_URL, { phone: phone, code: code });
      if (answer.status === 200 && answer.body.status === "PENDING") {
        day.textContent = formatDay(answer.body.scheduledFor);
        show(done);
      } else if (answer.status === 400) {
        say(WORDS.codeWrong);
      } else if (answer.status === 404) {
        say(WORDS.noAccount);
      } else if (answer.status === 403) {
        say(WORDS.disabled);
      } else if (answer.status === 409) {
        say(WORDS.provider);
      } else if (answer.status === 429) {
        say(limitWords(answer));
      } else {
        say(WORDS.other);
      }
    } catch (error) {
      say(WORDS.network);
    } finally {
      busy(confirmButton, false);
    }
  }

  sendButton.addEventListener("click", sendCode);
  confirmButton.addEventListener("click", confirmDeletion);
  againButton.addEventListener("click", function () {
    say("");
    show(phoneStep);
    phoneInput.focus();
  });
  phoneInput.addEventListener("keydown", function (event) {
    if (event.key === "Enter") sendCode();
  });
  codeInput.addEventListener("keydown", function (event) {
    if (event.key === "Enter") confirmDeletion();
  });
})();
