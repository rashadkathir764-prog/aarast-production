# Aarast Monitoring Stack

Prometheus + Alertmanager + Grafana, pre-wired for the Aarast backend.

## What you get

- **Prometheus** scrapes the backend `/metrics` endpoint every 15s
  (authenticated with the same `METRICS_TOKEN` the backend requires)
  and keeps 30 days of history.
- **Alert rules**: backend down, >5% 5xx errors, p95 latency >1s,
  event-loop saturation, OTP failure spikes (brute-force signal).
- **Grafana** auto-provisions a dashboard: requests/s, latency
  percentiles, error ratio, memory, event-loop lag, plus business
  signals (OTP requested/verified/failed, payments recorded).

## Deploy

1. Copy `.env.example` to `.env` and set `GRAFANA_ADMIN_PASSWORD`.
2. Write the backend's `METRICS_TOKEN` value into `secrets/metrics_token`
   (single line, no quotes). Both files are git-ignored.
3. Make sure `MONITORING_APP_NETWORK` in `.env` names the docker network
   the backend container is attached to (Dokploy: `dokploy-network`),
   and that the backend service is reachable there as `backend:3000` —
   adjust `prometheus/prometheus.yml` if the service name differs.
4. `docker compose up -d`
5. Grafana: `http://<host>:3200` → dashboard **Aarast → Aarast API**.

## Alert delivery

Alerts fire in Prometheus/Alertmanager immediately, but nobody is
notified until you configure a receiver in
`alertmanager/alertmanager.yml` (Telegram and webhook examples are
included in the file).

## Verifying locally

```bash
# From deploy/monitoring, with the dev backend running on the host:
docker compose config          # validates the compose file
curl -H "Authorization: Bearer $METRICS_TOKEN" http://localhost:3000/metrics
```
