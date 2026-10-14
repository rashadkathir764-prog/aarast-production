import assert from "node:assert/strict";
import { test } from "node:test";
import {
  ADMIN_TRUSTED_DEVICE_TTL_MS,
  isAdminTrustedDevice,
  issueAdminTrustedDevice,
} from "../src/modules/identity/internal/auth/admin-trusted-device";

const env = { JWT_SECRET: "k3Q9-zv8Lp2X_rT7mW4yN6bH1cJ5dF0g", NODE_ENV: "test" };
const admin = { id: "admin-1", passwordHash: "$2a$12$abcdefghijklmnopqrstuv" };
const now = new Date("2026-10-14T08:00:00.000Z");

test("a remembered device signs the same admin in for 30 days", () => {
  const { token, expiresAt } = issueAdminTrustedDevice(admin, now, env);
  assert.equal(expiresAt.getTime() - now.getTime(), ADMIN_TRUSTED_DEVICE_TTL_MS);
  assert.equal(isAdminTrustedDevice(token, admin, now, env), true);
  const almost = new Date(expiresAt.getTime() - 1);
  assert.equal(isAdminTrustedDevice(token, admin, almost, env), true);
  assert.equal(isAdminTrustedDevice(token, admin, expiresAt, env), false);
});

test("changing the password forgets every remembered device", () => {
  const { token } = issueAdminTrustedDevice(admin, now, env);
  const afterReset = { ...admin, passwordHash: "$2a$12$zyxwvutsrqponmlkjihgfe" };
  assert.equal(isAdminTrustedDevice(token, afterReset, now, env), false);
});

test("a device remembered for one admin does not open another", () => {
  const { token } = issueAdminTrustedDevice(admin, now, env);
  assert.equal(
    isAdminTrustedDevice(token, { ...admin, id: "admin-2" }, now, env),
    false,
  );
});

test("a forged, altered or foreign-key token is refused", () => {
  const { token } = issueAdminTrustedDevice(admin, now, env);
  const [encoded, signature] = token.split(".");
  const longer = Buffer.from(
    Buffer.from(encoded, "base64url").toString("utf8").replace(/\.(\d+)\./, (_, ms) => `.${Number(ms) + 1e12}.`),
  ).toString("base64url");
  assert.equal(isAdminTrustedDevice(`${longer}.${signature}`, admin, now, env), false);
  assert.equal(isAdminTrustedDevice(`${encoded}.AAAA`, admin, now, env), false);
  assert.equal(isAdminTrustedDevice("", admin, now, env), false);
  assert.equal(isAdminTrustedDevice(null, admin, now, env), false);
  assert.equal(isAdminTrustedDevice(`${token}.extra`, admin, now, env), false);
  const otherServer = { ...env, JWT_SECRET: "Zq7-Wm2Lp9X_cV4nB8yR1tH6kJ3dF5gS" };
  assert.equal(isAdminTrustedDevice(token, admin, now, otherServer), false);
});
