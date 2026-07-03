# Deployment Troubleshooting

## 502 Bad Gateway In Nginx Proxy Manager

A 502 usually means the public domain exists, but NPM cannot reach the upstream app/port.

Check the public URL:

```powershell
Invoke-WebRequest https://aarast-admin.shadowgardn.com/ -UseBasicParsing
Invoke-WebRequest https://aarast-api.shadowgardn.com/health -UseBasicParsing
```

On the server/Dokploy side, verify:

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
docker logs --tail=100 aarast-backend-prod
docker logs --tail=100 aarast-admin-web-prod
```

Then confirm NPM forwards to the correct host and port:

- API: service/upstream on host port `8093`, container port `3000`.
- Current admin Compose: host port `8095`, container port `80`.
- Target admin split: host port `8094`, container port `80`, only after Compose/Dokploy is updated.
- Target Flutter web/mobile: host port `8095`, only after a Flutter web service exists.

## SSL Wrong Domain

If SSL is issued for the wrong name, delete/request the certificate for the exact domain:

- `aarast-api.shadowgardn.com`
- `aarast-admin.shadowgardn.com`
- `aarast.shadowgardn.com`

Watch for typos such as `dokplay` vs `dokploy`, or a certificate attached to the wrong NPM proxy host.

## Invalid Origin Or CORS Failure

Symptoms include blocked browser API calls while direct `Invoke-WebRequest`/curl works.

Check backend env:

```bash
printenv | grep CORS_ORIGINS
```

Expected when both admin and mobile web are live:

```env
CORS_ORIGINS=https://aarast.shadowgardn.com,https://aarast-admin.shadowgardn.com
```

Rebuild/redeploy if the Vite admin image was built with the wrong API URL:

```env
VITE_API_BASE_URL=https://aarast-api.shadowgardn.com
```

## Flutter "تعذر الاتصال بالخادم"

Likely causes:

- Wrong `AARAST_API_BASE_URL` at build/run time.
- API service is down.
- NPM points to the wrong upstream host/port.
- CORS does not include the Flutter web/admin origin.
- Mixed HTTP/HTTPS requests from a secure browser page.

Local check:

```powershell
cd D:\projects\aarast\mobile
flutter run -d chrome --dart-define=AARAST_API_BASE_URL=http://127.0.0.1:3115
```

Production web builds must point to:

```text
https://aarast-api.shadowgardn.com
```

## Meta WhatsApp OTP

Current backend OTP is provider-agnostic/local. Meta WhatsApp production OTP is not wired.

Before using Meta WhatsApp:

- Complete business verification.
- Use an official business/site/domain; do not use a personal WhatsApp number for API delivery.
- Store Meta tokens only in Dokploy/server secrets.
- Do not paste tokens, phone-number IDs, verify tokens, or access tokens into chat or Markdown.
- Add delivery-specific smoke tests only after the provider is approved.
