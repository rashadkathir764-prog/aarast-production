import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const compose = await readFile(
  new URL("./docker-compose.yml", import.meta.url),
  "utf8",
);
const appCompose = await readFile(
  new URL("../dokploy/docker-compose.yml", import.meta.url),
  "utf8",
);

test("Grafana is localhost-only by default", () => {
  assert.match(
    compose,
    /127\.0\.0\.1:\$\{GRAFANA_PORT:-3200\}:3000/,
    "Grafana must not bind its management UI to every host interface",
  );
});

test("the shared monitoring network is explicit and has no silent default", () => {
  assert.match(compose, /name:\s+\$\{AARAST_MONITORING_NETWORK:\?/);
  assert.doesNotMatch(compose, /MONITORING_APP_NETWORK:-dokploy-network/);
  assert.match(appCompose, /name:\s+\$\{AARAST_MONITORING_NETWORK:\?/);
});

test("the backend joins the private monitoring network", () => {
  const backendBlock = appCompose.match(
    /\n  backend:\n(?<body>[\s\S]*?)\n  admin-web:\n/,
  )?.groups?.body;

  assert.ok(backendBlock, "backend service block was not found");
  assert.match(backendBlock, /\n      - aarast_monitoring\n/);
});

test("Alertmanager requires an operator-supplied receiver config", () => {
  assert.match(
    compose,
    /\$\{ALERTMANAGER_CONFIG_FILE:\?ALERTMANAGER_CONFIG_FILE is required\}:\/etc\/alertmanager\/alertmanager\.yml:ro/,
  );
  assert.doesNotMatch(
    compose,
    /\.\/alertmanager\/alertmanager\.yml:\/etc\/alertmanager\/alertmanager\.yml:ro/,
  );
});
