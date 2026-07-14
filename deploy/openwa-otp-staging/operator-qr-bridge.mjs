import http from 'node:http';

function required(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`Missing required environment variable: ${name}`);
  return value;
}

function isLoopbackHostname(hostname) {
  return hostname === '127.0.0.1' || hostname === 'localhost' || hostname === '[::1]';
}

const configuredBaseUrl = new URL(process.env.OPENWA_BASE_URL || 'http://127.0.0.1:2786');
if (
  configuredBaseUrl.protocol !== 'http:' ||
  !isLoopbackHostname(configuredBaseUrl.hostname) ||
  configuredBaseUrl.username ||
  configuredBaseUrl.password ||
  configuredBaseUrl.pathname !== '/' ||
  configuredBaseUrl.search ||
  configuredBaseUrl.hash
) {
  throw new Error('OPENWA_BASE_URL must be a credential-free loopback HTTP origin');
}
const baseUrl = configuredBaseUrl.origin;
const masterKey = required('OPENWA_MASTER_KEY');
const sessionId = required('OPENWA_SESSION_ID');
const port = Number(process.env.QR_BRIDGE_PORT || 2787);
const ttlMs = Number(process.env.QR_BRIDGE_TTL_MS || 15 * 60 * 1000);

if (!Number.isInteger(port) || port < 0 || port > 65_535) {
  throw new Error('QR_BRIDGE_PORT must be an integer between 0 and 65535');
}
if (!Number.isFinite(ttlMs) || ttlMs < 10_000 || ttlMs > 60 * 60 * 1000) {
  throw new Error('QR_BRIDGE_TTL_MS must be between 10000 and 3600000');
}

const page = `<!doctype html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>ربط واتساب - أعرست</title>
  <style>
    body{margin:0;background:#0f1115;color:#fff;font-family:system-ui,sans-serif;display:grid;min-height:100vh;place-items:center}
    main{width:min(92vw,520px);text-align:center;background:#191c22;border:1px solid #303640;border-radius:24px;padding:28px;box-sizing:border-box}
    img{width:min(78vw,360px);aspect-ratio:1;background:#fff;border-radius:18px;padding:12px;box-sizing:border-box}
    h1{margin:0 0 10px}p{color:#c9ced8;line-height:1.7}.ok{color:#4ade80}.bad{color:#fca5a5}
  </style>
</head>
<body><main><h1>ربط رقم واتساب التجريبي</h1><p id="status">افتح واتساب ← الأجهزة المرتبطة ← ربط جهاز، ثم امسح الرمز.</p><img id="qr" alt="رمز QR لربط واتساب"></main>
<script>
  const qr=document.getElementById('qr');const status=document.getElementById('status');
  const refresh=()=>{qr.src='/qr.png?t='+Date.now()};
  async function poll(){try{const r=await fetch('/status',{cache:'no-store'});const s=await r.json();
    if(s.linked){status.textContent='تم ربط واتساب بنجاح. يمكنك إغلاق هذه الصفحة.';status.className='ok';qr.hidden=true;return}
    status.textContent='الحالة: '+s.status+' — امسح أحدث رمز ظاهر.';refresh();
  }catch{status.textContent='تعذر تحديث الرمز مؤقتًا. ستتم إعادة المحاولة.';status.className='bad'}}
  poll();setInterval(poll,5000);
</script></body></html>`;

function headers(contentType) {
  return {
    'cache-control': 'no-store, max-age=0',
    'content-security-policy': "default-src 'none'; img-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'",
    'content-type': contentType,
    'cross-origin-resource-policy': 'same-origin',
    pragma: 'no-cache',
    'referrer-policy': 'no-referrer',
    'x-content-type-options': 'nosniff',
    'x-frame-options': 'DENY',
  };
}

async function openwa(path) {
  return fetch(`${baseUrl}/api${path}`, {
    headers: { 'x-api-key': masterKey },
    redirect: 'error',
    signal: AbortSignal.timeout(5_000),
  });
}

function send(response, status, body, contentType) {
  response.writeHead(status, headers(contentType));
  response.end(body);
}

function isLoopbackAuthority(value) {
  try {
    const hostname = new URL(`http://${value}`).hostname;
    return isLoopbackHostname(hostname);
  } catch {
    return false;
  }
}

function hasTrustedOrigin(request) {
  const origin = request.headers.origin;
  if (!origin) return true;
  try {
    const url = new URL(origin);
    return url.protocol === 'http:' && isLoopbackAuthority(url.host);
  } catch {
    return false;
  }
}

const server = http.createServer(async (request, response) => {
  try {
    if (!isLoopbackAuthority(request.headers.host || '') || !hasTrustedOrigin(request)) {
      return send(response, 403, 'Forbidden', 'text/plain; charset=utf-8');
    }
    if (request.method !== 'GET') {
      return send(response, 405, 'Method Not Allowed', 'text/plain; charset=utf-8');
    }
    const { pathname } = new URL(request.url || '/', 'http://127.0.0.1');
    if (pathname === '/') {
      return send(response, 200, page, 'text/html; charset=utf-8');
    }
    if (pathname === '/status') {
      const upstream = await openwa(`/sessions/${encodeURIComponent(sessionId)}`);
      if (!upstream.ok) return send(response, 503, '{"status":"unavailable","linked":false}', 'application/json');
      const session = await upstream.json();
      // OpenWA retains the last known phone after WhatsApp sends LOGOUT. The
      // runtime status is authoritative; using the stale phone would hide the
      // QR exactly when the operator needs to re-pair the session.
      const linked = ['authenticated', 'ready', 'connected'].includes(session.status);
      return send(
        response,
        200,
        JSON.stringify({ status: String(session.status || 'unknown'), linked }),
        'application/json',
      );
    }
    if (pathname === '/qr.png') {
      const upstream = await openwa(`/sessions/${encodeURIComponent(sessionId)}/qr`);
      if (!upstream.ok) return send(response, 503, 'QR is not ready', 'text/plain; charset=utf-8');
      const payload = await upstream.json();
      const match = /^data:image\/png;base64,([A-Za-z0-9+/=]+)$/.exec(payload.qrCode || '');
      if (!match) return send(response, 502, 'Invalid QR payload', 'text/plain; charset=utf-8');
      const png = Buffer.from(match[1], 'base64');
      if (png.length < 8 || png.length > 2 * 1024 * 1024 || png.subarray(0, 8).toString('hex') !== '89504e470d0a1a0a') {
        return send(response, 502, 'Invalid QR image', 'text/plain; charset=utf-8');
      }
      return send(response, 200, png, 'image/png');
    }
    return send(response, 404, 'Not Found', 'text/plain; charset=utf-8');
  } catch {
    return send(response, 503, 'Temporarily Unavailable', 'text/plain; charset=utf-8');
  }
});

server.listen(port, '127.0.0.1', () => {
  const address = server.address();
  console.log(`Aarast QR bridge listening on 127.0.0.1:${address.port}`);
});

let closing = false;
function shutdown() {
  if (closing) return;
  closing = true;
  clearTimeout(shutdownTimer);
  server.close(() => process.exit(0));
  server.closeAllConnections();
  setTimeout(() => process.exit(0), 1_000).unref();
}

const shutdownTimer = setTimeout(shutdown, ttlMs);
for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, shutdown);
}
